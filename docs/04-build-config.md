# The build configuration that makes a Packman build

## Core finding
Packman's ffmpeg, vlc, libheif, libquicktime, xine-lib are **unmodified openSUSE sources**.
The `_link` files contain no patches (ffmpeg links only delete Factory's `_multibuild` and `.changes`). Ours match, except that on TW we pin each Factory link to the revision the current snapshot was built from (PMBS follows head); `link.patches` exists for fixes Factory lacks (none currently). `openapv` (not in PMBS) is linked from Factory because BUILD_ORIG ffmpeg links liboapv.
All codec differences come from the Essentials project config, which is inherited by every project below it.

Raw evidence (`reference/`: PMBS `Essentials._config`, Factory specs, Essentials source snapshot) was removed; see `git show c4ee8c6:reference/...`.

Effective part of PMBS `Essentials/_config` for Tumbleweed:

```
Release: %{suse_version}.<CI_CNT>.pm.<B_CNT>

Prefer: -libfdk-aac-devel        # have choice for pkgconfig(fdk-aac)
Prefer: opencv-devel
Prefer: vlc-devel
Prefer: -ffmpeg-3-libavcodec-devel ... (all ffmpeg-3 devel subpackages)

%define BUILD_ORIG 1
%define BUILD_ORIG_ADDON 1
%define _with_aac 1
%define _with_aptx 1
%define _with_amrnb 1
%define _with_amrwb 1
%define _with_faac 1
%define _with_faad 1
%define _without_fdk_aac 1
%define _with_fdk_aac_dlopen 1
%define _with_librtmp 1
%define _with_smbclient 1
%define _with_vo_aacenc 1
%define _with_vidstab 1
%define _with_x264 1
%define _with_x265 1
%define _with_xvid 1
%define _without_distributable 1
%define _without_onlynondistributable 1
%define _without_amf_sdk 1          # TW and Leap 16
%define _without_freerdp 1          # TW
%define _without_imagemagick 1      # TW

Macros:
%vendor http://packman.links2linux.de
%packager packman@links2linux.de
%packman_bs 1
(... the same %BUILD_ORIG / %_with_* list again, so they reach rpmbuild inside the chroot)
:Macros
```
The `%define` block affects OBS dependency expansion; the `Macros:` block is written to the build root's rpm macros. A replacement needs both effects: expand BuildRequires with these macros, and build with them.

## Evidence in Factory specs

### ffmpeg-8.spec
- `%bcond_with amf_sdk amrwb cuda_sdk fdk_aac_dlopen opencore smbclient vvenc x264 x265 xvid` default off; `%_with_<name> 1` in macros flips them on (standard rpm bcond semantics).
- `%if 0%{?BUILD_ORIG}`: enables amf/cuda SDK headers, amrwb, codec2, mysofa, opencore, rubberband, vidstab, vulkan, xvid.
- Without BUILD_ORIG configure runs with `--disable-encoders --disable-decoders --disable-decoder=h264,hevc,vc1,prores_raw,vvc` and re-enables only the whitelist in `enable_decoders` / `enable_encoders`. With BUILD_ORIG all codecs are built.
- With BUILD_ORIG: `Provides: libavcodec-full = %version-%release` and `Provides: libavcodec62(unrestricted)`. `vlc-codecs` and others require these.
- `fdk_aac_dlopen`: ffmpeg dlopens libfdk-aac at runtime (`ffmpeg-4.2-dlopen-fdk_aac.patch` is in Factory); Packman ships `fdk-aac` itself.

### vlc.spec
- `%if 0%{?BUILD_ORIG}`: BuildRequires x264/x265, `--enable-x265`, produces `vlc-codecs` with `libx264_plugin.so`, `libx26410b_plugin.so`, `libx265_plugin.so`; faad enabled on TW regardless. `Recommends: libdvdcss`.

### libheif.spec
- `%bcond_with x264 x265 kvazaar openjpeg openjph svtenc`; Packman's `%_with_x265 1` pulls `libde265` + `x265` and ships `libheif-libde265.so` and `libheif-x265.so` (HEIC decode/encode). Kvazaar plugin is also switchable.

## Native packages: what they add over Factory
- `gstreamer-plugins-bad-codecs`: Factory gst-plugins-bad tarball + `build_what_we_need_only.patch` that guts `meson.build` to build only `ext/{de265,x265}`; installs `libgstde265.so libgstx265.so` (openaptx dropped 2026-10-11: Factory gst-plugins-bad ships it via libfreeaptx; faac dropped 2026-10-24); `Supplements: gstreamer-plugins-bad`.
- `gstreamer-plugins-ugly-codecs`: same idea, x264 plugin only, no patch.
- `libx264` (library only; Packman also builds the `x264` CLI), `x265` (git snapshot from bitbucket, arm patches, pkgconfig patch), `libde265`, `fdk-aac`.
- Scope (2026-10-24): codecs only. Not carried over from Essentials: drivers and firmware (`r8168`, `broadcom-wl`, `libfprint-tod-*`, `b43legacy-firmware`, `rtl8761b-firmware`), DRM (`libdvdcss2`, `libaacs`, `libbdplus`, `chromium-plugin-widevinecdm`), tools (`gpac`, `l-smash`, x264 CLI, `rtmpdump`, `shairplay`), codecs no remaining package uses or the distro already ships (`amrnb`, `amrwb`, `dcadec`, `kvazaar`, `vo-aacenc`, `faac`, `libopenaptx`, `pipewire-aptx`, `SVT-AV1`), and `ffmpeg-6` (no distro ships `libavcodec60`). Unset macros: `_with_librtmp`, `_with_faac`, `_with_amrnb`, `_with_vo_aacenc`, `_with_aptx`.
- Specs, patches and `.changes` for all of them are vendored in `packages/<pkg>/`; `update` bumps versions (`docs/12-tool.md`).

## Leap 16.0 / 16.1 (verified 2026-10-16)
- PMBS repos `openSUSE_Leap_16.0`/`_16.1` build against `openSUSE.org:openSUSE:Leap:16.x/standard` (x86_64, aarch64; no i586, so no -32bit). `_config`: `Release: <CI_CNT>.<B_CNT> spec:160000.<CI_CNT>.pm.<B_CNT>` (16.1: `160100.`); the common macro list minus `_without_freerdp`/`_without_imagemagick` (`> 1610` only); `Substitute:` clamav, malwarescan, rpmlint-Factory/-mini; `%source_date_epoch_from_changelog N`. Ours: `prjconf/packman-nova-macros-leap.conf`, release `160000.<run>.nova.1`, which beats SLFO's `160000.N.M` and Backports' `bp160.*`.
- Per-distro packages are separate PMBS packages enabled per repo; ours are separate dirs with `distros:`. Leap: `ffmpeg-4` from `openSUSE:Leap:16.0` (16.1: `openSUSE:Backports:SLE-16.1`), `ffmpeg-7` from `SUSE:SLFO:1.2` (16.1: `1.3`), `vlc` like `ffmpeg-4`, `libquicktime` from `SUSE:SLFO:1.2` for both. `libheif` from Factory and `xine-lib` on every distro. TW-only: `ffmpeg-8`, `ffmpeg-9`, `openapv` (Leap ships no `libavcodec62`, so nothing there needs them).
- gstreamer codecs: Leap 16.0 ships gstreamer 1.26.7, so it gets the 1.26.10 spec and patch of Packman's 16.0 src.rpm, reduced to `ext/{de265,x265}` like the TW package. Leap 16.1 ships 1.28.5 and shares the TW package (`_version 1.28.0`).
- Base prjconf: obs-build `configs/leap-16.x.conf`, made for the public `repo/oss`. OBS's own project configs (SLFO + Backports + Leap) do not fit outside OBS: they `Conflict: gcc-PIE` and prefer the unpublished `gcc-build` packages. obs-build's file tests `%bootstrap_stage` without defining it (pbuild: `syntax error in expression`): `prjconf/leap-base-fixup.conf` is prepended. Its 16.1 file predates SLFO 1.3: `prjconf/leap-16.1-fixup.conf` sets `suse_version 1610` and maps `/usr/bin/python3` to the `python3-base` wrapper (`Prefer: -python313-base`) like `SUSE:SLFO:1.3`, else every cmake build has a python choice.
- Leap's base config also prefers `ffmpeg-7-mini-*`, so the `ffmpeg-mini` stub is needed there too.
- Leap's `lua-macros` and `compat-usrmerge-build` require plain `lua`, which resolves to the preferred `lua54` and trips vlc's `BuildConflicts: lua >= 5.4` (TW's require `lua-interpreter`, which lua53 satisfies): the Leap macros add `Prefer: -lua-macros:lua54 -compat-usrmerge-build:lua54`.
- GCC 15 with older Leap sources: libv4l 1.30 declares `v4l2_ioctl(int, int, ...)`, rejected by ffmpeg-4's `--enable-libv4l2` (link patch `ffmpeg-4-libv4l2-ioctl-type.patch`); `SUSE:SLFO:1.2/libquicktime` lacks Factory's `fix-gcc15-build.patch` (added as a link patch).

## Things that will bite
- Some Packman specs use `%packman_bs` or `BUILD_ORIG_ADDON`; grep `packages/` before dropping a macro.
- -32bit: `%ifarch i586` block in `prjconf/packman-nova-macros.conf`. `BuildFlags: onlybuild:` limits the i586 pass to the 14 packages with a `baselibs.conf` plus the ffmpeg-mini solver stub; add a package there when it gains one. `VMinstall: !kernel-obs-build` because OBS exports that package to i586 from x86_64 and the i586 port lacks it; chroot builds do not need it.
- `Prefer:` lines resolve "have choice" errors; outside OBS the equivalent is pinning exact package names in the build root or using `zypper --solver` options in the build container.
- Factory's ffmpeg-8 `_multibuild` has a `mini` flavor; Packman deletes it via `_link`. Build only the main flavor.
