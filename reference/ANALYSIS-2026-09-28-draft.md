# Packman Essentials: end-to-end analysis for an independent rebuild

Date: 2026-09-28. Scope: `openSUSE_Tumbleweed/Essentials`. Sources of truth: the gwdg mirror, the public PMBS API, the openSUSE OBS public API, the packman mailing list and forum thread.

## 1. Shutdown facts

- Announced 27 Aug 2026 by Marc Schiffbauer and Stefan Botter: Packman ends 31 Dec 2026 unless successors take over. Reason: the two infrastructure operators are out of time and energy. No legal trigger.
  https://lists.links2linux.de/pipermail/packman/2026-August/018314.html
- What exists: PMBS (an OBS instance, Leap 16 VM, 1.3 TB, 10 GB RAM, 6 cores), two x86_64 workers plus community ARM workers, one repo server (website, master repo, rsync to mirrors, signing scripts), ~800-900 GB/month traffic on the master.
- What is offered to successors: the PMBS VM, the publishing/signing shell scripts, advisory help. Domain and mailing list stay with Marc.
- Community status (late Sep 2026): Christian "computersalat" offered to host PMBS and is the preferred candidate; seife offers OBS admin and ARM64 workers; manfred-h continues packaging and has the core set building privately. No formal decision yet.
- Signing key: `PackMan Project (signing key)`, fingerprint F887 5B88 0D51 8B6B 8C53 0D13 45A1 D067 1ABD 1AFB, RSA 4096, currently expires 2027-01-01. Nobody has said the private key will be handed over. Assume a new key.
- Forum: https://forums.opensuse.org/t/packman-discontinued-from-jan-1st-2027-but-heres-your-chance/195731

## 2. How the pipeline works today

```
openSUSE OBS (api.opensuse.org)  --remote link "openSUSE.org:"-->  PMBS (pmbs.links2linux.de, plain OBS)
                                                                    |  project Essentials
                                                                    |  prjconf sets BUILD_ORIG=1 + %_with_x264 ... macros
                                                                    |  builds against openSUSE.org:openSUSE:Tumbleweed/standard
                                                                    v
                                                             repo server (links2linux.de): sign repomd, rsync
                                                                    v
                                                             mirrors: ftp.gwdg.de, ftp.fau.de, halifax.rwth-aachen.de, karneval.cz, aliyun
```

- PMBS is a stock Open Build Service. Its public read API is open without an account:
  `https://pmbs.links2linux.de/public/source/Essentials` (package list), `.../<pkg>?expand=1` (expanded file list), `.../<pkg>/<file>?expand=1&rev=<srcmd5>` (file download). `fetch_essentials.py` in this directory mirrors everything (517 MB, verified 2026-09-28).
- openSUSE OBS is equally readable anonymously: `https://api.opensuse.org/public/source/openSUSE:Factory/<pkg>`.
- The mirror also carries `src/*.src.rpm` for every Essentials package (70 files), so the exact build inputs are recoverable from the mirror alone.
- Project layout on PMBS: `Essentials` (base), `Multimedia` (217 pkgs, path -> Essentials), `Extra` (70), `Games` (29), `KMP`, `SLE15`, `build-compare`. Prjconf is inherited down the repository path, so Multimedia builds with Essentials' macros.

## 3. The actual "secret sauce": project config, not patches

The Factory ffmpeg/vlc/libheif specs already contain every codec switch. openSUSE builds them with `BUILD_ORIG` unset. Packman links the *unmodified* Factory sources and flips macros in the project config (`Essentials/_config`):

```
Release: %{suse_version}.<CI_CNT>.pm.<B_CNT>        # gives the "1699.6.pm.18" release strings
Prefer: -libfdk-aac-devel
Prefer: opencv-devel
Prefer: vlc-devel
%define BUILD_ORIG 1  /  %define BUILD_ORIG_ADDON 1
%define _with_aac 1 _with_aptx 1 _with_amrnb 1 _with_amrwb 1 _with_faac 1 _with_faad 1
%define _without_fdk_aac 1 _with_fdk_aac_dlopen 1 _with_librtmp 1 _with_smbclient 1
%define _with_vo_aacenc 1 _with_vidstab 1 _with_x264 1 _with_x265 1 _with_xvid 1
%define _without_distributable 1 _without_onlynondistributable 1
%define _without_amf_sdk 1           (TW)
%define _without_freerdp 1 _without_imagemagick 1   (TW)
Macros: %vendor http://packman.links2linux.de  %packager packman@links2linux.de  %packman_bs 1  + the same list
Prefer: -ffmpeg-3-*-devel            (solver help between ffmpeg API variants)
```

Effect in Factory specs (verified):
- `ffmpeg-8.spec`: `%if 0%{?BUILD_ORIG}` enables amf/cuda SDK, amrwb, opencore, xvid, vidstab...; `%bcond_with x264/x265/xvid/fdk_aac_dlopen/smbclient` become `with` via `%_with_*`; without BUILD_ORIG the configure step runs `--disable-decoders --disable-decoder=h264,hevc,vc1,prores_raw,vvc` and only enables the whitelist in `enable_decoders`/`enable_encoders`. With BUILD_ORIG libavcodec gets `Provides: libavcodec62(unrestricted)` and `libavcodec-full`, which `vlc-codecs` requires.
- `vlc.spec`: `%if 0%{?BUILD_ORIG}` adds x264/x265 BuildRequires, `--enable-x265`, and the `vlc-codecs` subpackage with x264/x26410b/x265 plugins.
- `libheif.spec`: `%bcond_with x265/kvazaar` -> with; pulls libde265 + x265, ships `libheif-libde265.so`, `libheif-x265.so` (HEIC decode/encode, the most requested Packman feature).

The `_link` files carry no source changes. ffmpeg links only delete `_multibuild` (Factory's `mini` flavor) and the `.changes` file; vlc/libquicktime/libheif are bare links with `cicount="add"`. Cython/docutils are branch links (frozen `baserev`, only there to unblock builds).

## 4. Package inventory (Tumbleweed subset of Essentials)

45 source names produce 1615 binaries (x86_64 495, aarch64 358, i586 356, armv7hl 314, noarch 14, src 78).

Links to openSUSE OBS, rebuilt with the prjconf above (zero local patches):
- ffmpeg-4, ffmpeg-7, ffmpeg-8, ffmpeg-9 (Factory), vlc, libquicktime, libheif (Factory), python-Cython, python-docutils (frozen branch), shairplay (multimedia:libs), xine-lib (multimedia:xine), lightspark (multimedia:apps), gpg-offline (Leap 42.3, legacy).

Native to PMBS (own spec + tarball, some via `_service`):
- Codec libs openSUSE cannot ship: libx264 (+ x264 CLI flavor, tar_scm from code.videolan.org), x265 (tar_scm from bitbucket multicoreware, 4 patches), libde265, kvazaar, fdk-aac, faac, vo-aacenc, amrnb, amrwb, dcadec, l-smash, libopenaptx, pipewire-aptx, gpac, rtmpdump, libaacs, libbdplus, libdvdcss2, SVT-AV1 (own copy), gstreamer-plugins-bad-codecs (Factory tarball + `build_what_we_need_only.patch`: builds only de265/faac/openaptx/x265 plugins), gstreamer-plugins-ugly-codecs (x264 plugin only).
- Kernel/firmware/proprietary blobs: r8168, broadcom-wl (KMP, ~35 kernel patches), b43legacy-firmware, rtl8761b-firmware, libfprint-tod-broadcom/goodix, chromium-plugin-widevinecdm, flash-player, psi+-iconsets.
- Plumbing: rpmkey-packman (ships the GPG keys and `packman.repo`), ffmpeg-mini (empty stub so the solver never picks Factory's `ffmpeg-N-mini-*`), preinstallimage-base, A_tw-cmake, A_tw-ffmpeg-3, A_tw-ffmpeg-6 (frozen old copies).

Stale or droppable: flash-player, lightspark, gpg-offline, ffmpeg-3, ffmpeg-4 (only for old consumers), chromium-plugin-widevinecdm.

## 5. Dependency graph inside Essentials (build order)

```
tier 0 (no Packman deps): libde265, kvazaar, fdk-aac, faac, vo-aacenc, amrnb, amrwb, dcadec, l-smash,
                          libopenaptx, rtmpdump, libaacs, libbdplus, libdvdcss2, SVT-AV1, gpac
tier 1: libx264 (lib), x265, pipewire-aptx (libopenaptx)
tier 2: ffmpeg-8/9/7 (x264, x265, fdk-aac headers, amr*, rtmpdump, vo-aacenc), libheif (x265, libde265, kvazaar)
tier 3: libx264:x264 CLI (ffmpeg libs, l-smash, ffms2), vlc (ffmpeg, x264, x265, libdvdcss), gstreamer-*-codecs,
        libquicktime, xine-lib, shairplay
```
Everything else comes from the openSUSE Tumbleweed `oss` repo of the same snapshot.

## 6. Keeping in sync with Tumbleweed

Two independent triggers:
1. Upstream source changes in Factory: poll `https://api.opensuse.org/public/source/openSUSE:Factory/<pkg>` and compare `srcmd5` (or watch `src.opensuse.org` git for `pool/<pkg>`). Rebuild the linked package on change. This is what OBS link tracking does automatically on PMBS.
2. Tumbleweed snapshot changes (ABI bumps of glibc, libva, dav1d, libvpx, ...): OBS rebuilds dependents automatically. Outside OBS, rebuild everything on every new snapshot or diff `primary.xml` of the `oss` repo for changed BuildRequires. Snapshot id is in `https://download.opensuse.org/tumbleweed/repo/oss/media.1/media`.
3. Release numbers: Tumbleweed uses `<CI_CNT>.<B_CNT>`; Packman prefixes `%{suse_version}` (1699 on TW) so its ffmpeg always beats Factory's for `zypper dup --allow-vendor-change`. Keep this scheme, or clients will silently flip back to the codec-less Factory build. Also keep `Vendor:` distinct (vendor stickiness).

## 7. Build environment realities

- OBS builds in a clean chroot/KVM using only the repo path. The local equivalent is the `build` package (installed here, `build-20260505`) or `osc build`: `build --repo https://download.opensuse.org/tumbleweed/repo/oss/ --repo <our-r2-repo> --define 'BUILD_ORIG 1' ... pkg.spec`. Both need root (no passwordless sudo on this host).
- No `_constraints` on ffmpeg/vlc/x265, so default 4 GB-class workers suffice; vlc and ffmpeg builds are 20-40 min on 4 cores. Mesa (Extra project, HW video decode) needs ~20 GB RAM; it is outside Essentials.
- arm: aarch64 and armv7hl are built natively on community Raspberry Pi and cloud workers. GitHub Actions has native arm64 runners; armv7hl would need QEMU (slow) or dropping.
- i586 is still published; consider dropping.

## 8. Plan for an independent replacement (GitHub Actions + Cloudflare R2)

1. Repo of sources: one directory per package with `_link`-style provenance file (`project`, `package`, `srcmd5`), or vendor the expanded files. Start from `fetch_essentials.py` output.
2. Shared `prjconf.macros` file reproducing section 3, injected via `--define` or a `.rpmmacros` layer in the build container.
3. Builder: `opensuse/tumbleweed` container matching the target snapshot, `zypper si -d`/`build` in privileged job, or `osc build` against a local OBS-less chroot. Emit RPMs per arch as job artifacts.
4. Ordering: matrix jobs per tier; publish tier N RPMs to a staging R2 prefix and add it as a repo for tier N+1.
5. Repo generation: `createrepo_c`, `gpg --detach-sign repomd.xml`, export `repomd.xml.key`; upload with `rclone` to R2, serve via a custom domain.
6. Your own `rpmkey-<name>` package and `.repo` file; users must import your key. Packman's key cannot be reused.
7. Sync bot: scheduled job that compares Factory `srcmd5` for linked packages and the TW snapshot id, opens a PR or triggers a rebuild.
8. Debuginfo and `src.rpm` publishing are optional but cheap on R2.

## 9. Legal note

The reason these builds live outside openSUSE is patent exposure (HEVC, AAC variants, AMR) and a few non-redistributable blobs (widevine, flash, broadcom firmware). Hosting them is your jurisdictional call; Packman is run from Germany. libdvdcss2 on PMBS is spec-only for that reason.
