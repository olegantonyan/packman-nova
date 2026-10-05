# Replacement plan (draft 2026-09-28, milestones updated 2026-09-29)

## Goal
Tumbleweed `Essentials` equivalent: same packages, same sources, same macro set, our infra, our key. Later: Leap 16.x, Slowroll, selected Multimedia apps.

## Decisions already taken
- Target arches: x86_64 and aarch64. Drop i586 and armv7hl unless demand appears. (GitHub has native arm64 runners; armv7 would need QEMU.) x86_64 ships Packman's `-32bit` packages, built by an i586 baselibs pass (2026-10-05, `docs/12-tool.md`).
- New signing key and our own `rpmkey-<name>` package. Never reuse Packman's key or vendor string.
- Do not depend on PMBS staying up: vendor the expanded sources of every native package into this repo; keep linked packages as provenance records (Factory package + srcmd5) and re-fetch from api.opensuse.org.
- Drop dead weight from day one: flash-player, lightspark, gpg-offline, ffmpeg-3, preinstallimage-base, psi+-iconsets. Review: chromium-plugin-widevinecdm, A_tw-cmake, A_tw-SVT-AV1, python-Cython/docutils helpers.

## Pipeline sketch
```
packages/<name>/            spec, patches, _service or SOURCES url list, provenance.yaml (factory pkg + srcmd5 for links)
prjconf/macros.tw           the macro set from docs/04
.github/workflows/
   build.yml                matrix per tier (docs/05) x arch; privileged job in opensuse/tumbleweed container
                            steps: zypper ar oss + our staging repo -> `build`/`rpmbuild` with macros -> upload rpms as artifacts
   publish.yml              createrepo_c, gpg --detach-sign repomd.xml, export key, rclone sync to R2 prefix
   sync.yml (cron)          compare Factory srcmd5 + TW snapshot id -> open PR / dispatch build
```
- Builder (decided): obs-build inside `packman-nova-builder` (rootless podman, `--privileged`). It resolves BuildRequires from the spec, applies the prjconf `Macros:`/`Prefer:` blocks, and takes previously built rpms via `--rpms`. No sudo on the host needed.
- Tier ordering: tier N publishes to `r2://staging/tierN`, which becomes a repo for tier N+1 jobs; final job promotes to the public prefix.
- Hosting: R2 bucket behind a custom domain; serve `repodata/`, `<arch>/`, `src/`, `.repo` file, key. Traffic estimate from Packman: 800-900 GB/month for everything, Essentials only is a fraction.
- Debuginfo and src.rpm: publish, cheap on R2.

## Open questions
- Legal: hosting HEVC/AAC/AMR encoders and DVD/Blu-ray decryption libs. Packman is operated from Germany. Decide jurisdiction and whether to exclude libdvdcss/libaacs/libbdplus and the proprietary blobs (widevine, broadcom firmware) in phase 1.
- Solver parity: how to reproduce `Prefer:` and "have choice" handling outside OBS (pin exact BuildRequires per package in the container).
- build-compare: implement "skip publish if unchanged" or accept churn.
- Coordination: the community successor (computersalat + seife + manfred-h) may keep PMBS alive. Decide whether to mirror their output, contribute, or run fully independent. Independent is the stated goal; still watch the list.
- Name and domain for the public repo.

## First milestones
1. DONE 2026-09-28. Tier 0 + tier 1 (fdk-aac, libx264, x265, libde265, kvazaar) built with obs-build in a rootless podman container against TW oss, Factory prjconf + Packman macros. Output matches Packman's subpackage set minus debuginfo and -32bit. Details: `docs/11-build-journal.md`.
2. DONE 2026-09-28. ffmpeg-8 from unmodified Factory sources with the macro set: x264/x265/xvid/fdk-aac-dlopen enabled, `Provides: libavcodec62(unrestricted)`, subpackages identical to Packman's. See `docs/11-build-journal.md`.
3. DONE 2026-09-28. vlc (`vlc-codecs` with x264/x265 plugins), libheif (`libheif-HEIF` with x265/libde265 plugins), both gstreamer codec packages, x264 CLI. Subpackage sets equal Packman's.
4. DONE 2026-09-29. `packman-nova` CLI (`docs/12-tool.md`): sync from Factory/PMBS/upstream into a pbuild project, pbuild in the builder container (local results shadow Tumbleweed, so no staging repos per tier are needed), signed localfs repo with `packman-nova.repo`, keyring package and static index page. Full real run: `docs/11-build-journal.md` 2026-09-29.
5. Next: GitHub Actions + R2. Enable `.github/workflows/build-publish.yml` (draft) with `run --provider s3` and `state push/pull`; create the bucket and domain, seed `_state/` from a local build, install on a TW VM and run `zypper dup --allow-vendor-change` from Packman to ours.
6. Sync cron (`sync --check`, exit 2 triggers a build), aarch64.
