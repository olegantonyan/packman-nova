# Build journal

## 2026-09-28: milestone 1, tier 0/1 in a container

### Setup
- Host: Tumbleweed 20260924, rootless podman (overlay). No sudo used.
- Image `packman-nova-builder` (`container/Containerfile`): `registry.opensuse.org/opensuse/tumbleweed` + `build build-mkbaselibs rpm-build createrepo_c gpg2 hostname perl-libwww-perl perl-LWP-Protocol-https perl-XML-Parser perl-YAML-LibYAML zstd xz gzip bzip2 cpio tar`. The perl and compression packages are undeclared runtime needs of obs-build's `queryrepo` (LWP for http repos, zstd for Tumbleweed's `primary.xml.zst`).
- Entry point runs `build "$@"` then copies `RPMS/**` and `SRPMS/**` from the build root to `/out/rpms` and `/out/srpms`.
- Invocation (`tools/build-in-container.sh`):
  ```
  podman run --rm --privileged -v packages/<pkg>:/src:ro -v prjconf:/prjconf:ro -v out:/out \
     -v .cache/build-root:/build-root -v .cache/rpms:/var/cache/build packman-nova-builder \
     --root /build-root --dist /prjconf/tumbleweed.conf \
     --repo https://download.opensuse.org/tumbleweed/repo/oss/ --rpms /out/rpms \
     --arch x86_64 --jobs N --nosignature --release 1699.<CI_CNT>.nova.<B_CNT> /src/<pkg>.spec
  ```
- `--dist <file>` takes a full prjconf file. We use Factory's `_config` (4205 lines, fetched from api.opensuse.org) with our block appended. Verified applied: built rpms carry `Vendor: packman-nova`.
- `--privileged` rootless is enough for obs-build's chroot, bind mounts and `/proc`. `--vm-type` is not needed.

### Pitfalls
- obs-build does not evaluate the prjconf `Release:` line locally; that is done by the OBS scheduler. Without `--release` the spec's `Release: 0` is used verbatim. We pass `--release` with the Packman-style string ourselves. CI_CNT/B_CNT bookkeeping is ours to implement.
- A build root left half-initialised makes obs-build ask an interactive question and fail; `rm -rf .cache/build-root` fixes it. In CI use a fresh root per job.
- Build-root files are owned by subuid-mapped ids; inspect with `podman unshare`.
- Debuginfo packages need `--debug` (PMBS has debuginfo enabled per project). `-32bit` baselibs need `--baselibs` and an i586 build; we dropped i586.

### Results (x86_64, all OK)
| package | time | output |
|---|---|---|
| fdk-aac 2.0.3 | 4 min incl. root init, 40 s warm | libfdk-aac2, fdk-aac-devel |
| libde265 1.1.3 | 1.3 min | libde265-0, libde265-devel |
| kvazaar 2.3.2 | 30 s | kvazaar, libkvazaar7, libkvazaar-devel |
| libx264 20250608.b35605ac | 45 s | libx264-165, libx264-devel (x264 CLI flavor deferred to tier 3) |
| x265 4.1 | 5 min | libx265-215 (10/12-bit linked in), libx265-devel, x265, libhdr10plus-4_1 |

Subpackage names and versions match the Packman repo exactly (`docs/03`), release `1699.1.nova.1`.

### Next: milestone 2
Build Factory `ffmpeg-8` (expanded link from PMBS or fetched from api.opensuse.org) with `--rpms out/rpms`; expect `--enable-libx264 --enable-libx265 --enable-libfdk-aac-dlopen` in the configure line and `Provides: libavcodec62(unrestricted)`. Needs amrnb/amrwb/vo-aacenc/rtmpdump/l-smash from tier 0 first, and Factory's xvidcore, opencore-amr etc. from oss.

## 2026-09-28: milestone 2, ffmpeg-8 from Factory sources

- Source: `packages/ffmpeg-8` = PMBS `Essentials/A_tw-ffmpeg-8?expand=1`, i.e. openSUSE:Factory/ffmpeg-8 at srcmd5 `fac92e8502a9b282a0616cfba699d9d2` with `_multibuild` and `.changes` removed (`provenance.yaml`). Spec untouched.
- Command: `tools/build-in-container.sh ffmpeg-8` (11 min on 16 cores, ~200 build deps from oss, our tier 0/1 rpms via `--rpms out/rpms`).
- Verified with `tools/verify-ffmpeg.sh 8`:
  - configure: `--enable-gpl --enable-nonfree --enable-version3 --enable-libx264 --enable-libx265 --enable-libxvid --enable-libfdk-aac-dlopen --enable-libopencore-amrnb --enable-libvo-amrwbenc --enable-libvidstab --enable-libsmbclient`; no `--disable-decoder=...` line, so the full decoder set is built.
  - `libavcodec62` provides `libavcodec-full` and `libavcodec62(unrestricted)` and requires `libx264.so.165`, `libx265.so.215`, `libxvidcore.so.4`.
  - Build root used our `libx264-165`, `libx265-215`, `fdk-aac-devel` (release `1699.1.nova.1`).
  - Subpackage set equals Packman's ffmpeg-8 minus `-32bit` and debuginfo: ffmpeg-8, 7 `*-devel`, libavcodec62, libavdevice62, libavfilter11, libavformat62, libavutil60, libswresample6, libswscale9.
- Also built (tier 0, all OK, <1 min each): l-smash, rtmpdump, vo-aacenc, amrnb, amrwb. 45 rpms in `out/rpms`.

### Observation to resolve
The build root took `libfdk-aac2-2.0.3-1.2` from Factory (openSUSE now ships an fdk-aac library) but `fdk-aac-devel` from ours. Packman's prjconf has `Prefer: -libfdk-aac-devel` for the same "have choice" situation. At runtime ffmpeg dlopens `libfdk-aac.so.2`, so users get whichever `libfdk-aac2` wins by version/vendor. Check what Factory's fdk-aac build disables (likely the patent-relevant profiles) and either bump ours so it outranks Factory or drop our fdk-aac if Factory's is complete.

### Next: milestone 3
vlc (Factory link, expect `vlc-codecs` with x264/x265 plugins) and libheif (Factory link, expect `libheif-x265.so`, `libheif-libde265.so`), then gstreamer-plugins-bad-codecs / ugly-codecs and the x264 CLI flavor (`BUILD_FLAVOR=x264 tools/build-in-container.sh libx264`, needs l-smash and ffmpeg).

## 2026-09-28: milestone 3, vlc, libheif, gstreamer codecs, x264 CLI

All built with `tools/build-in-container.sh`, verified with `tools/verify-tier3.sh`. 80 rpms from 18 source packages in `out/rpms`, all release `1699.1.nova.1`.

| package | source | time | Packman-only result verified |
|---|---|---|---|
| faac 1.50 | native, obs_scm cpio + buildtime `tar`/`set_version` services | 30 s | libfaac0, faac, faac-devel |
| libopenaptx 0.2.0 | native | 20 s | |
| libheif 1.23.5 | Factory link (`provenance.yaml`) | 1.5 min | `libheif-HEIF` = `libheif-libde265.so` + `libheif-x265.so` (HEIC decode/encode) |
| gstreamer-plugins-ugly-codecs 1.28.7 | native, `_service:download_files:` tarball | 1.5 min | `libgstx264.so` |
| gstreamer-plugins-bad-codecs 1.28.7 | native + `build_what_we_need_only.patch` | 2 min | `libgstx265.so libgstde265.so libgstfaac.so libgstopenaptx.so` |
| libx264 flavor `x264` | `BUILD_FLAVOR=x264` (multibuild) | 1 min | `/usr/bin/x264` linked with l-smash + our ffmpeg-8 |
| vlc 3.0.23 | Factory link, obs_scm cpio (134 MB) | 12 min | `vlc-codecs` with `libx264_plugin.so libx26410b_plugin.so libx265_plugin.so`, `Requires: libavcodec62(unrestricted)` |

Subpackage sets of all 18 source packages equal Packman's published Essentials set minus `-32bit` and debuginfo (checked against `docs/03`).

### Learned
- obs-build handles Factory's `obs_scm` sources (`*.obscpio` + `*.obsinfo`) and `_service:download_files:` prefixed tarballs without any help; the buildtime services pull `obs-service-tar`/`set_version`/`recompress` from oss automatically.
- Multibuild flavors work with `--buildflavor`; the wrapper exposes it as `BUILD_FLAVOR`.
- Factory sources move fast: the vlc link's srcmd5 changed between our fetch and the build the same evening. Provenance must record the srcmd5 actually fetched, and the sync job (docs/06) is not optional.
- The `libfdk-aac2` observation from milestone 2 repeats for vlc and gstreamer-bad: build roots take Factory's `libfdk-aac2-2.0.3-1.2`, ours only supplies `-devel`. Still open.

### Milestones 1-3 conclusion
The whole Packman Essentials stack for Tumbleweed can be rebuilt from public sources with obs-build in a rootless container and one prjconf. Nothing needed patching. Remaining Essentials packages (SVT-AV1 copy, libaacs, libbdplus, libdvdcss2, dcadec, gpac, pipewire-aptx, kvazaar done, firmware/blob packages, r8168/broadcom-wl KMPs, ffmpeg-7/9, libquicktime, xine-lib, shairplay) are the same mechanics.

### Next: milestone 4
Wire into GitHub Actions and publish a signed repo to R2 (see docs/07 and docs/10). Prerequisites: generate the signing key, decide the repo path and name, decide the fdk-aac question, implement CI_CNT/B_CNT bookkeeping.

## 2026-09-29: WP1b package data

`package.yml` in all 40 dirs under `packages/`. Tarballs, obscpio and `provenance.yaml` removed from the tree; `ffmpeg-8`, `vlc`, `libheif` now hold only `package.yml`. Native dirs vendor every non-blob file from `reference/pmbs/essentials-src-snapshot/`; file names and md5s re-checked against the live PMBS `?expand=1` listings.

- obs-link, enabled (9): ffmpeg-4/7/8/9, vlc, libquicktime, libheif (Factory); xine-lib (`multimedia:xine`, itself a plain link to Factory); shairplay (`multimedia:libs`).
- native, enabled (29): 27 vendored plus authored `ffmpeg-mini` (adds `ffmpeg-9-mini-*`) and `packman-nova-keyring` (key via `path: keys/packman-nova.key`, file not generated yet). Tagged `proprietary`: b43legacy-firmware, rtl8761b-firmware, libfprint-tod-broadcom/goodix (`spec:` override, specs are `libfprint-2-tod1-*.spec`), chromium-plugin-widevinecdm.
- native, disabled (2): broadcom-wl (phase 2), SVT-AV1.
- Sources: 34 remote, all with sha256/size from the PMBS copy; none left blank. 24 have a verified upstream URL first (every upstream download hashed identical to PMBS, GitHub archive tarballs included). 10 are PMBS/mirror only: tar_scm/obs_scm products (faac cpio, x264, x265, rtmpdump, ffmpeg-6 tarball and dlopen headers) and dead upstreams (amrnb/amrwb `ftp.penguin.cz` no DNS, widevine `dl.google.com` 404, rtl8761b amazonaws 403).
- `mirror-src:` takes the src.rpm name, not the PMBS package name (`ffmpeg-6`, `SVT-AV1`, `libfprint-2-tod1-*`). Omitted for libdvdcss2 and broadcom-wl, which have no src.rpm on the mirror.
- SVT-AV1: Factory has 4.2.0 (`libSvtAv1Enc4`), so it stays disabled. Conflict: ffmpeg-6 x86_64 `BuildRequires: (pkgconfig(SvtAv1Enc) >= 0.9.0 with pkgconfig(SvtAv1Enc) < 4)` and needs `libSvtAv1Enc3` at runtime. ffmpeg-6 will be unresolvable until we either enable SVT-AV1 3.0.1 (it then shadows Factory's `SVT-AV1-devel` for every ffmpeg build) or drop libsvtav1 from ffmpeg-6.
- Odd in specs:
  - r8168 is a KMP against TW `kernel-syms`, rebuilt per kernel (PMBS release pm.518); its `.tar.gz.asc` is a source entry, checked with the vendored `r8168.keyring`.
  - broadcom-wl passes `-c %_sourcedir/_projectcert.crt`, an OBS-injected file that pbuild lacks; on TW it needs `kernel-syms-longterm`.
  - libfprint-tod-* fetch via `_service` `download_url` + `verify_file` over plain http from dell.archive.canonical.com. Those services run server-side only, so `_service:download_url:` files are listed as sources.
  - chromium-plugin-widevinecdm pins Chrome 134.0.6998.165; Google no longer serves it.
  - 3gpp.org returns 403 to curl's default User-Agent.
  - libbdplus spec uses `ftp://`; we use the https mirror.
  - ffmpeg-4: Factory has no `_multibuild`, so that delete is a no-op. PMBS keeps `ffmpeg-4.changes`; we delete it like 7/8/9.
  - libheif: PMBS also builds the `:test` flavor; we drop it.

### Decision 2026-09-29: ffmpeg-6 vs SVT-AV1
Factory ships SVT-AV1 4.2.0; the frozen ffmpeg-6 needs SvtAv1Enc < 4. Rather than enabling Packman's private SVT-AV1 3.0.1 (which, with local-first repo precedence, would shadow Factory's SVT-AV1-devel for ffmpeg-7/8/9 too), the vendored ffmpeg-6 spec got a `%bcond_with svtav1` (off) guarding the BuildRequires and `--enable-libsvtav1`. ffmpeg-6 loses only the SVT-AV1 encoder; SVT-AV1 stays `enabled: false`.

## 2026-09-29: milestone 4, full run with the packman-nova CLI

Workdir `/run/media/oleg/c3996ce0-a379-4403-9d64-7d4c0536463f/dev/packman-nova`, 16 cores, `buildjobs 2`, `jobs 8`, TW snapshot 20260924. Production key generated (RSA 4096, `C2F2B2F52552208F`), private part only in `.env`.

| step | wall time | result |
|---|---|---|
| `check` | seconds | all ok after `image build` (image had no `state/image.json` record) |
| `sync` (warm cache) | 5 s | keyring now materializes; 38 packages; `sync --check` exit 0 |
| `build --no-sync --rebuild` (run 2) | 1 h 12 min | 39 of 39 succeeded (38 packages + `libx264:x264`), release `1699.2.nova.1` |
| `publish --provider localfs` | 21 s | 234 rpms added (195 binary, 39 src), 339 MB (x86_64 106 MB, src 233 MB) |
| second `publish` | 2 s | no-op |
| `run --provider localfs` | 23 s | nothing built (run 3 given back), publish no-op, exit 0 |

Slowest builds: vlc 18 m 22 s, ffmpeg-7 9 m 29 s, ffmpeg-4 8 m 35 s, ffmpeg-6 8 m 26 s, ffmpeg-9 6 m 25 s, x265 5 m 29 s, ffmpeg-8 4 m 51 s (built twice: once before libheif, once after, because ffmpeg-8 and libheif depend on each other), gpac 4 m 32 s, xine-lib 4 m 11 s, r8168 4 m 01 s. Every other package 45 s to 2 m 30 s. Sum of package times 1 h 53 min. 141 debuginfo/debugsource rpms produced but not published.

Disk: `_build.tumbleweed.x86_64` 2.2 GB (of which `.pbuild/_base` 1.6 GB, 1234 TW rpms), build-root 3.2 GB (two roots), cache 356 MB, repo 339 MB.

Verified:
- `pbuild --repoquery libavcodec62` / `libfdk-aac2`: our `1699.2.nova.1` from the build result repo, Tumbleweed's `8.1.2-5.1` / `2.0.3-1.2` shadowed. The milestone 2 fdk-aac observation is resolved: build roots now take our `libfdk-aac2`.
- ffmpeg-8 `_log`: `--enable-libx264 --enable-libx265`, build root with our libx264-165, libx265-215, fdk-aac-devel, libfdk-aac2 (`1699.2.nova.1`).
- vlc `_log`: built against `ffmpeg-8-lib*-devel-8.1.2-1699.2.nova.1` and `libavcodec62-8.1.2-1699.2.nova.1`.
- In the builder: `zypper --root /tmp/r --gpg-auto-import-keys ar file:///repo/opensuse_tumbleweed/essentials/x86_64 nova`, `ref`, `se -s -r nova` list all 195 binaries; `rpm -Kv libavcodec62-8.1.2-1699.2.nova.1.x86_64.rpm`: `Header V4 RSA/SHA256 Signature, key ID 2552208f: OK`.
- `index.html` parses cleanly (html.parser: no unclosed or mismatched tags), 39 package rows, install commands, key fingerprint, snapshot and release present.

### Learned
- obs-build in a container loses `/dev/fd` from the second build in a build root: with `/run/.containerenv` it bind-mounts `/dev/null` etc. and never unmounts them, so `--clean` removes the `fd`/`stdin`/`stdout`/`stderr` links but `create_devs` is skipped because `/dev/null` is still a char device. brp scripts using process substitution then fail (`/dev/fd/63: No such file or directory`; first seen on b43legacy-firmware and chromium-plugin-widevinecdm). The WP2 test missed it because each of its two packages was the first build in its root. Fixed in `container/Containerfile` by patching `init_buildsystem` to recreate the links; worth reporting upstream (openSUSE/obs-build).
- The first run (run 1) was stopped after that failure; run 2 used `--rebuild` so all packages share one release.
- First-run intermediate results show `unresolvable: nothing provides ...` for packages whose providers are not built yet; pbuild re-evaluates after each build and ends clean.
- Nothing needed `link.delete` for `_scmsync.obsinfo` / `build.specials.obscpio`, and no spec or manifest changes were needed.

## 2026-10-05: -32bit baselibs pass

- Run 5 (`1699.5.nova.1`), full rebuild: x86_64 39/39 in 64 min, then `pbuild --arch i586 --baselibs` against `ports/i586/tumbleweed/repo/oss/`: 22 succeeded, 17 excluded by `onlybuild`, 53 min.
- First attempt failed with `vminstalls: nothing provides kernel-obs-build` (OBS exports it to i586 from x86_64); fixed with `VMinstall: !kernel-obs-build` under `%ifarch i586`.
- The 57 `*-32bit` names equal Packman's x86_64 `-32bit` set (`reference/repo-metadata/Essentials.primary.xml.gz`) minus the 9 from ffmpeg-3. `publish --dry-run` adds all 57 to `x86_64/`; i586 rpms and `-32bit-debuginfo` are not published.
