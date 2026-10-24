# Replacement plan (2026-09-28, updated 2026-10-16)

## Goal
Tumbleweed `Essentials` equivalent: same packages, same sources, same macro set, our infra, our key. Later: Leap 16.x, Slowroll, selected Multimedia apps.

## Decisions already taken
- Target arches: x86_64 and aarch64. Drop i586 and armv7hl unless demand appears. (GitHub has native arm64 runners; armv7 would need QEMU.) x86_64 ships Packman's `-32bit` packages, built by an i586 baselibs pass (2026-10-05, `docs/12-tool.md`).
- New signing key and our own `rpmkey-<name>` package. Never reuse Packman's key or vendor string.
- Do not depend on PMBS staying up: vendor the expanded sources of every native package into this repo; linked packages are `obs-link` manifests re-fetched from api.opensuse.org.
- Drop dead weight from day one: flash-player, lightspark, gpg-offline, ffmpeg-3, preinstallimage-base, psi+-iconsets. Dropped 2026-10-24 (legal risk or redundant): chromium-plugin-widevinecdm, libdvdcss2, rtmpdump, b43legacy-firmware, rtl8761b-firmware, dcadec. Review: A_tw-cmake, A_tw-SVT-AV1, python-Cython/docutils helpers.

## Pipeline
As built: `packman-nova` CLI (`docs/12-tool.md`) runs sync, pbuild in the builder container and a signed publish to R2, served at https://packman.omnipackage.org. Local results shadow Tumbleweed in build roots, so no per-tier staging repos. src.rpms are published, debuginfo is not (`repository.publish_debuginfo`).

## Open questions
- Legal: hosting HEVC/AAC/AMR encoders and DVD/Blu-ray decryption libs. Packman is operated from Germany. Decide jurisdiction; still open: libaacs/libbdplus and the libfprint-tod blobs.
- build-compare: implement "skip publish if unchanged" or accept churn.
- Coordination: the community successor (computersalat + seife + manfred-h) may keep PMBS alive. Decide whether to mirror their output, contribute, or run fully independent. Independent is the stated goal; still watch the list.

## First milestones
1. DONE 2026-09-28. Tier 0 + tier 1 (fdk-aac, libx264, x265, libde265, kvazaar) built with obs-build in a rootless podman container against TW oss, Factory prjconf + Packman macros. Output matches Packman's subpackage set minus debuginfo and -32bit.
2. DONE 2026-09-28. ffmpeg-8 from unmodified Factory sources with the macro set: x264/x265/xvid/fdk-aac-dlopen enabled, `Provides: libavcodec62(unrestricted)`, subpackages identical to Packman's.
3. DONE 2026-09-28. vlc (`vlc-codecs` with x264/x265 plugins), libheif (`libheif-HEIF` with x265/libde265 plugins), both gstreamer codec packages, x264 CLI. Subpackage sets equal Packman's.
4. DONE 2026-09-29. `packman-nova` CLI (`docs/12-tool.md`): sync from Factory/PMBS/upstream into a pbuild project, pbuild in the builder container (local results shadow Tumbleweed, so no staging repos per tier are needed), signed localfs repo with `packman-nova.repo`, keyring package and static index page. Full run: 39/39 packages in 72 min on 16 cores.
5. DONE 2026-10-05. GitHub Actions + R2: `.github/workflows/build-publish.yml` runs nightly (`state pull`, `run --provider s3`, `state push`); x86_64 ships `-32bit` from the i586 baselibs pass.
6. 2026-10-16. Leap 16.0 and 16.1 (16.1 GA due 2026-11) next to TW, x86_64, no -32bit (Leap 16 has none): `config/distros/<id>.yml`, per-distro packages like PMBS (`docs/04`), one CI job per distro, one site with a tab per distro.
7. Next: aarch64 (PMBS builds it for TW and both Leaps); Slowroll. PMBS now also sets `_with_kvazaar`/`_with_vvenc` and ships vvenc (+ `libheif-vvenc`); not mirrored yet on any distro.
