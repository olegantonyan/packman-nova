# The build configuration that makes a Packman build

## Core finding
Packman's ffmpeg, vlc, libheif, libquicktime, xine-lib, shairplay are **unmodified openSUSE sources**.
The `_link` files contain no patches (ffmpeg links only delete Factory's `_multibuild` and `.changes`).
All codec differences come from the Essentials project config, which is inherited by every project below it.

Full file: `reference/pmbs/Essentials._config`. The effective part for Tumbleweed:

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

## Evidence in Factory specs (reference/opensuse-factory/)

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
- `gstreamer-plugins-bad-codecs`: Factory gst-plugins-bad tarball + `build_what_we_need_only.patch` that guts `meson.build` to build only `ext/{faac,de265,openaptx,x265}`; installs `libgstde265.so libgstfaac.so libgstopenaptx.so libgstx265.so`; `Supplements: gstreamer-plugins-bad`.
- `gstreamer-plugins-ugly-codecs`: same idea, x264 plugin only, no patch.
- `libx264` (multibuild: lib + `x264` CLI flavor needing ffmpeg + l-smash), `x265` (tar_scm from bitbucket, arm patches, pkgconfig patch), `libde265`, `kvazaar`, `fdk-aac`, `faac`, `vo-aacenc`, `amrnb`, `amrwb`, `dcadec`, `l-smash`, `libopenaptx`, `pipewire-aptx`, `gpac`, `rtmpdump`, `libaacs`, `libbdplus`, `libdvdcss2`, `SVT-AV1` (own copy), `broadcom-wl`, `r8168`, firmware and blob packages.
- Specs, `_service`, patches and `.changes` for all of them: `reference/pmbs/essentials-src-snapshot/<pkg>/`.

## Things that will bite
- Some Packman specs use `%packman_bs` or `BUILD_ORIG_ADDON`; grep the snapshot before dropping a macro.
- `Prefer:` lines resolve "have choice" errors; outside OBS the equivalent is pinning exact package names in the build root or using `zypper --solver` options in the build container.
- Factory's ffmpeg-8 `_multibuild` has a `mini` flavor; Packman deletes it via `_link`. Build only the main flavor.
