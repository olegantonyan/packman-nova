# Essentials inventory (openSUSE_Tumbleweed, 2026-09-28)

Source: `reference/pmbs/Essentials.packages.xml` (PMBS) and `reference/repo-metadata/Essentials.primary.xml.gz` (mirror).
Regenerate the tables below with `python3 tools/repo_inventory.py reference/repo-metadata/Essentials.primary.xml.gz`.

## PMBS packages and their origin

`A_16.*`, `A_sr-*`, `A_sle15-*` target Leap 16.x, Slowroll and SLE15 and are out of scope for a Tumbleweed-only successor.

| PMBS package | kind | origin / source fetch | notes |
|---|---|---|---|
| A_tw-ffmpeg-9 | link | openSUSE:Factory/ffmpeg-9 | current default ffmpeg API |
| A_tw-ffmpeg-8 | link | openSUSE:Factory/ffmpeg-8 | link deletes `_multibuild`, `.changes` |
| A_tw-ffmpeg-7 | link | openSUSE:Factory/ffmpeg-7 | |
| A_tw-ffmpeg-4 | link | openSUSE:Factory/ffmpeg-4 | legacy consumers |
| A_tw-ffmpeg-6 | native (frozen copy) | Factory snapshot, `_service` | Factory dropped it |
| A_tw-ffmpeg-3 | native (frozen copy) | old, `_service` | droppable |
| A_tw-vlc | link | openSUSE:Factory/vlc | yields `vlc-codecs` |
| A_tw-libquicktime | link | openSUSE:Factory/libquicktime | |
| libheif | link | openSUSE:Factory/libheif | HEVC plugins via `_with_x265` |
| xine-lib-12 | link | openSUSE.org:multimedia:xine/xine-lib | |
| shairplay | link | openSUSE.org:multimedia:libs/shairplay | |
| lightspark | link | openSUSE.org:multimedia:apps/lightspark | Flash player, droppable |
| A_tw-python-Cython, A_tw-python-docutils | branch link (frozen baserev) | Factory | build helpers only |
| gpg-offline | link | Leap 42.3 Update | dead, droppable |
| A_tw-cmake | native | cmake 3.31.7 copy | build helper, likely droppable now |
| A_tw-SVT-AV1 | native | gitlab tarball | own copy of Factory pkg; check if still needed |
| libx264 (+ :x264 flavor) | native | tar_scm code.videolan.org/videolan/x264.git rev b35605ac, `update.sh` | not in Factory |
| x265 | native | tar_scm bitbucket multicoreware/x265_git rev 32e25ff, 4 patches, `update.sh` | |
| libde265 | native | tarball | |
| kvazaar | native | tarball | |
| fdk-aac | native | tarball | ffmpeg dlopens it |
| faac | native | `_service` | |
| vo-aacenc | native | tarball | |
| amrnb, amrwb | native | tarball | |
| dcadec | native | tarball | |
| l-smash | native | tarball | needed by x264 CLI |
| gpac | native | tarball | |
| libopenaptx | native | tarball | |
| pipewire-aptx | native | `_service` | aptX for pipewire |
| rtmpdump | native | `_service` | |
| libaacs, libbdplus, libdvdcss2 | native | `_service`/tarball | Blu-ray/DVD decryption; libdvdcss2 spec only, no tarball on PMBS |
| gstreamer-plugins-bad-codecs | native | `download_files` from gstreamer.freedesktop.org + patch | |
| gstreamer-plugins-ugly-codecs | native | `download_files` | |
| r8168 | native | Realtek tarball, KMP | kernel module |
| broadcom-wl | native | ~35 kernel patches, KMP | proprietary wl driver |
| b43legacy-firmware, rtl8761b-firmware | native | firmware blobs | |
| libfprint-tod-broadcom, libfprint-tod-goodix | native | `_service`, vendor blobs | |
| chromium-plugin-widevinecdm | native | Google blob (117 MB) | |
| flash-player | native | Adobe blob | dead, droppable |
| psi+-iconsets | native | `_service` | odd fit, low value |
| rpmkey-packman | native | GPG keys + .repo | replace with our own |
| ffmpeg-mini | native | empty stub rpms | solver helper, keep equivalent |
| preinstallimage-base | native | OBS preinstall image | OBS-only, drop |
| A_KMP, A_sle15-aggregate | aggregate | other PMBS projects | out of scope |

## What is actually published on the mirror

Binary counts per arch, then every source package with the versions currently in the repo (two versions coexist while a rebuild is being published) and its binary subpackages.

| arch | count |
|---|---|
| aarch64 | 358 |
| armv7hl | 314 |
| i586 | 356 |
| noarch | 14 |
| src | 78 |
| x86_64 | 495 |

| source package | versions in repo | binary subpackages |
|---|---|---|
| SVT-AV1 | 3.0.1-1699.1.pm.3, 3.0.1-1699.1.pm.5 | SVT-AV1, SVT-AV1-debuginfo, SVT-AV1-debugsource, SVT-AV1-devel, libSvtAv1Enc3, libSvtAv1Enc3-debuginfo |
| amrnb | 11.0.0.0-1699.3.pm.136, 11.0.0.0-1699.3.pm.52 | amrnb, amrnb-debuginfo, amrnb-debugsource, libamrnb-devel, libamrnb3, libamrnb3-32bit, libamrnb3-32bit-debuginfo, libamrnb3-debuginfo |
| amrwb | 11.0.0.0-1699.2.pm.129, 11.0.0.0-1699.2.pm.53 | amrwb, amrwb-debuginfo, amrwb-debugsource, libamrwb-devel, libamrwb3, libamrwb3-32bit, libamrwb3-32bit-debuginfo, libamrwb3-debuginfo |
| b43legacy-firmware | 3.130.20.0-1699.3.pm.13, 3.130.20.0-1699.3.pm.52 | b43legacy-firmware |
| chromium-plugin-widevinecdm | 4.10.2891.0-1699.1.pm.6 | chromium-plugin-widevinecdm |
| dcadec | 0.2.0-1699.2.pm.162, 0.2.0-1699.2.pm.47 | dcadec, dcadec-debuginfo, dcadec-debugsource, libdcadec-devel, libdcadec0, libdcadec0-32bit, libdcadec0-32bit-debuginfo, libdcadec0-debuginfo |
| faac | 1.50-1699.3.pm.2, 1.50-1699.3.pm.8 | faac, faac-debuginfo, faac-debugsource, faac-devel, libfaac0, libfaac0-32bit, libfaac0-32bit-debuginfo, libfaac0-debuginfo |
| fdk-aac | 2.0.3-1699.2.pm.1 | fdk-aac-debugsource, fdk-aac-devel, libfdk-aac2, libfdk-aac2-32bit, libfdk-aac2-32bit-debuginfo, libfdk-aac2-debuginfo |
| ffmpeg-3 | 3.4.14-1699.2.pm.22, 3.4.14-1699.2.pm.46 | ffmpeg-3, ffmpeg-3-debuginfo, ffmpeg-3-debugsource, ffmpeg-3-libavcodec-devel, ffmpeg-3-libavdevice-devel, ffmpeg-3-libavfilter-devel, ffmpeg-3-libavformat-devel, ffmpeg-3-libavresample-devel, ffmpeg-3-libavutil-devel, ffmpeg-3-libpostproc-devel, ffmpeg-3-libswresample-devel, ffmpeg-3-libswscale-devel, ffmpeg-3-private-devel, libavcodec57, libavcodec57-32bit, libavcodec57-32bit-debuginfo, libavcodec57-debuginfo, libavdevice57, libavdevice57-32bit, libavdevice57-32bit-debuginfo, libavdevice57-debuginfo, libavfilter6, libavfilter6-32bit, libavfilter6-32bit-debuginfo, libavfilter6-debuginfo, libavformat57, libavformat57-32bit, libavformat57-32bit-debuginfo, libavformat57-debuginfo, libavresample3, libavresample3-32bit, libavresample3-32bit-debuginfo, libavresample3-debuginfo, libavutil55, libavutil55-32bit, libavutil55-32bit-debuginfo, libavutil55-debuginfo, libpostproc54, libpostproc54-32bit, libpostproc54-32bit-debuginfo, libpostproc54-debuginfo, libswresample2, libswresample2-32bit, libswresample2-32bit-debuginfo, libswresample2-debuginfo, libswscale4, libswscale4-32bit, libswscale4-32bit-debuginfo, libswscale4-debuginfo |
| ffmpeg-4 | 4.4.8-1699.15.pm.3, 4.4.8-1699.15.pm.4 | ffmpeg-4, ffmpeg-4-debuginfo, ffmpeg-4-debugsource, ffmpeg-4-libavcodec-devel, ffmpeg-4-libavdevice-devel, ffmpeg-4-libavfilter-devel, ffmpeg-4-libavformat-devel, ffmpeg-4-libavresample-devel, ffmpeg-4-libavutil-devel, ffmpeg-4-libpostproc-devel, ffmpeg-4-libswresample-devel, ffmpeg-4-libswscale-devel, ffmpeg-4-private-devel, libavcodec58_134, libavcodec58_134-32bit, libavcodec58_134-32bit-debuginfo, libavcodec58_134-debuginfo, libavdevice58_13, libavdevice58_13-32bit, libavdevice58_13-32bit-debuginfo, libavdevice58_13-debuginfo, libavfilter7_110, libavfilter7_110-32bit, libavfilter7_110-32bit-debuginfo, libavfilter7_110-debuginfo, libavformat58_76, libavformat58_76-32bit, libavformat58_76-32bit-debuginfo, libavformat58_76-debuginfo, libavresample4_0, libavresample4_0-32bit, libavresample4_0-32bit-debuginfo, libavresample4_0-debuginfo, libavutil56_70, libavutil56_70-32bit, libavutil56_70-32bit-debuginfo, libavutil56_70-debuginfo, libpostproc55_9, libpostproc55_9-32bit, libpostproc55_9-32bit-debuginfo, libpostproc55_9-debuginfo, libswresample3_9, libswresample3_9-32bit, libswresample3_9-32bit-debuginfo, libswresample3_9-debuginfo, libswscale5_9, libswscale5_9-32bit, libswscale5_9-32bit-debuginfo, libswscale5_9-debuginfo |
| ffmpeg-6 | 6.1.3-1699.6.pm.11, 6.1.3-1699.6.pm.5 | ffmpeg-6, ffmpeg-6-debuginfo, ffmpeg-6-debugsource, ffmpeg-6-libavcodec-devel, ffmpeg-6-libavdevice-devel, ffmpeg-6-libavfilter-devel, ffmpeg-6-libavformat-devel, ffmpeg-6-libavutil-devel, ffmpeg-6-libpostproc-devel, ffmpeg-6-libswresample-devel, ffmpeg-6-libswscale-devel, libavcodec60, libavcodec60-32bit, libavcodec60-32bit-debuginfo, libavcodec60-debuginfo, libavdevice60, libavdevice60-32bit, libavdevice60-32bit-debuginfo, libavdevice60-debuginfo, libavfilter9, libavfilter9-32bit, libavfilter9-32bit-debuginfo, libavfilter9-debuginfo, libavformat60, libavformat60-32bit, libavformat60-32bit-debuginfo, libavformat60-debuginfo, libavutil58, libavutil58-32bit, libavutil58-32bit-debuginfo, libavutil58-debuginfo, libpostproc57, libpostproc57-32bit, libpostproc57-32bit-debuginfo, libpostproc57-debuginfo, libswresample4, libswresample4-32bit, libswresample4-32bit-debuginfo, libswresample4-debuginfo, libswscale7, libswscale7-32bit, libswscale7-32bit-debuginfo, libswscale7-debuginfo |
| ffmpeg-7 | 7.1.5-1699.5.pm.2, 7.1.5-1699.5.pm.3 | ffmpeg-7, ffmpeg-7-debuginfo, ffmpeg-7-debugsource, ffmpeg-7-libavcodec-devel, ffmpeg-7-libavdevice-devel, ffmpeg-7-libavfilter-devel, ffmpeg-7-libavformat-devel, ffmpeg-7-libavutil-devel, ffmpeg-7-libpostproc-devel, ffmpeg-7-libswresample-devel, ffmpeg-7-libswscale-devel, libavcodec61, libavcodec61-32bit, libavcodec61-32bit-debuginfo, libavcodec61-debuginfo, libavdevice61, libavdevice61-32bit, libavdevice61-32bit-debuginfo, libavdevice61-debuginfo, libavfilter10, libavfilter10-32bit, libavfilter10-32bit-debuginfo, libavfilter10-debuginfo, libavformat61, libavformat61-32bit, libavformat61-32bit-debuginfo, libavformat61-debuginfo, libavutil59, libavutil59-32bit, libavutil59-32bit-debuginfo, libavutil59-debuginfo, libpostproc58, libpostproc58-32bit, libpostproc58-32bit-debuginfo, libpostproc58-debuginfo, libswresample5, libswresample5-32bit, libswresample5-32bit-debuginfo, libswresample5-debuginfo, libswscale8, libswscale8-32bit, libswscale8-32bit-debuginfo, libswscale8-debuginfo |
| ffmpeg-8 | 8.1.2-1699.6.pm.18, 8.1.2-1699.6.pm.8 | ffmpeg-8, ffmpeg-8-debuginfo, ffmpeg-8-debugsource, ffmpeg-8-libavcodec-devel, ffmpeg-8-libavdevice-devel, ffmpeg-8-libavfilter-devel, ffmpeg-8-libavformat-devel, ffmpeg-8-libavutil-devel, ffmpeg-8-libswresample-devel, ffmpeg-8-libswscale-devel, libavcodec62, libavcodec62-32bit, libavcodec62-32bit-debuginfo, libavcodec62-debuginfo, libavdevice62, libavdevice62-32bit, libavdevice62-32bit-debuginfo, libavdevice62-debuginfo, libavfilter11, libavfilter11-32bit, libavfilter11-32bit-debuginfo, libavfilter11-debuginfo, libavformat62, libavformat62-32bit, libavformat62-32bit-debuginfo, libavformat62-debuginfo, libavutil60, libavutil60-32bit, libavutil60-32bit-debuginfo, libavutil60-debuginfo, libswresample6, libswresample6-32bit, libswresample6-32bit-debuginfo, libswresample6-debuginfo, libswscale9, libswscale9-32bit, libswscale9-32bit-debuginfo, libswscale9-debuginfo |
| ffmpeg-9 | 9.0.1-1699.7.pm.2 | ffmpeg, ffmpeg-9-debugsource, ffmpeg-9-libavcodec-devel, ffmpeg-9-libavdevice-devel, ffmpeg-9-libavfilter-devel, ffmpeg-9-libavformat-devel, ffmpeg-9-libavutil-devel, ffmpeg-9-libswresample-devel, ffmpeg-9-libswscale-devel, ffmpeg-debuginfo, libavcodec63, libavcodec63-32bit, libavcodec63-32bit-debuginfo, libavcodec63-debuginfo, libavdevice63, libavdevice63-32bit, libavdevice63-32bit-debuginfo, libavdevice63-debuginfo, libavfilter12, libavfilter12-32bit, libavfilter12-32bit-debuginfo, libavfilter12-debuginfo, libavformat63, libavformat63-32bit, libavformat63-32bit-debuginfo, libavformat63-debuginfo, libavutil61, libavutil61-32bit, libavutil61-32bit-debuginfo, libavutil61-debuginfo, libswresample7, libswresample7-32bit, libswresample7-32bit-debuginfo, libswresample7-debuginfo, libswscale10, libswscale10-32bit, libswscale10-32bit-debuginfo, libswscale10-debuginfo |
| ffmpeg-mini | 1699-1699.1.pm.1 | ffmpeg-5-mini-devel, ffmpeg-5-mini-libs, ffmpeg-6-mini-devel, ffmpeg-6-mini-libs, ffmpeg-mini-debugsource |
| flash-player | 32.0.0.465-1699.3.pm.45 | flash-player |
| gpac | 2.4.0-1699.2.pm.122, 2.4.0-1699.2.pm.58 | gpac, gpac-debuginfo, gpac-debugsource, libgpac-devel, libgpac12 |
| gstreamer-plugins-bad-codecs | 1.28.7-1699.1.pm.1 | gstreamer-plugins-bad-codecs, gstreamer-plugins-bad-codecs-32bit, gstreamer-plugins-bad-codecs-32bit-debuginfo, gstreamer-plugins-bad-codecs-debuginfo, gstreamer-plugins-bad-codecs-debugsource |
| gstreamer-plugins-ugly-codecs | 1.28.7-1699.1.pm.1 | gstreamer-plugins-ugly-codecs, gstreamer-plugins-ugly-codecs-32bit, gstreamer-plugins-ugly-codecs-32bit-debuginfo, gstreamer-plugins-ugly-codecs-debuginfo, gstreamer-plugins-ugly-codecs-debugsource |
| kvazaar | 2.3.2-1699.1.pm.20, 2.3.2-1699.1.pm.8 | kvazaar, kvazaar-debuginfo, kvazaar-debugsource, libkvazaar-devel, libkvazaar7, libkvazaar7-debuginfo |
| l-smash | 2.14.5-1699.1.pm.149, 2.14.5-1699.1.pm.89 | l-smash, l-smash-debuginfo, l-smash-debugsource, l-smash-devel, liblsmash2, liblsmash2-debuginfo |
| libaacs | 0.12.0-1699.1.pm.2, 0.12.0-1699.1.pm.3 | libaacs-debugsource, libaacs-devel, libaacs0, libaacs0-debuginfo |
| libbdplus | 0.2.0-1699.1.pm.40, 0.2.0-1699.1.pm.86 | libbdplus-debugsource, libbdplus-devel, libbdplus0, libbdplus0-debuginfo |
| libde265 | 1.1.3-1699.1.pm.1 | libde265-0, libde265-0-32bit, libde265-0-32bit-debuginfo, libde265-0-debuginfo, libde265-debugsource, libde265-devel |
| libfprint-2-tod1-broadcom | 5.15.285+5.15.010.0-1699.1.pm.4 | libfprint-2-tod1-broadcom |
| libfprint-2-tod1-goodix | 0.0.6-1699.1.pm.25 | libfprint-2-tod1-goodix |
| libheif | 1.23.5-1699.4.pm.2, 1.23.5-1699.4.pm.6 | gdk-pixbuf-loader-libheif, gdk-pixbuf-loader-libheif-debuginfo, heif-examples, heif-examples-debuginfo, heif-thumbnailer, heif-thumbnailer-debuginfo, libheif-HEIF, libheif-HEIF-debuginfo, libheif-aom, libheif-aom-debuginfo, libheif-dav1d, libheif-dav1d-debuginfo, libheif-debugsource, libheif-devel, libheif-ffmpeg, libheif-ffmpeg-debuginfo, libheif-jpeg, libheif-jpeg-debuginfo, libheif-openh264, libheif-openh264-debuginfo, libheif-openjpeg, libheif-openjpeg-debuginfo, libheif-rav1e, libheif-rav1e-debuginfo, libheif-svtenc, libheif-svtenc-debuginfo, libheif-x264, libheif-x264-debuginfo, libheif1, libheif1-32bit, libheif1-32bit-debuginfo, libheif1-debuginfo |
| libheif-test | 1.23.5-1699.4.pm.3, 1.23.5-1699.4.pm.4 |  |
| libopenaptx | 0.2.0-1699.10.pm.133, 0.2.0-1699.10.pm.58 | libopenaptx-devel, libopenaptx-tools, libopenaptx0, libopenaptx0-32bit |
| libquicktime | 1.2.4+git20180804.fff99cd-1699.11.pm.19, 1.2.4+git20180804.fff99cd-1699.11.pm.42 | libquicktime, libquicktime-32bit, libquicktime-32bit-debuginfo, libquicktime-debuginfo, libquicktime-debugsource, libquicktime-devel, libquicktime-lang, libquicktime-orig-addon, libquicktime-orig-addon-32bit, libquicktime-orig-addon-32bit-debuginfo, libquicktime-orig-addon-debuginfo, libquicktime-tools, libquicktime-tools-debuginfo, libquicktime0, libquicktime0-32bit, libquicktime0-32bit-debuginfo, libquicktime0-debuginfo |
| libx264 | 20250608.b35605ac-1699.1.pm.14, 20250608.b35605ac-1699.1.pm.5 | libx264-165, libx264-165-32bit, libx264-165-32bit-debuginfo, libx264-165-debuginfo, libx264-debugsource, libx264-devel |
| libx264-x264 | 20250608.b35605ac-1699.1.pm.10, 20250608.b35605ac-1699.1.pm.22 | libx264-x264-debugsource, x264, x264-debuginfo |
| lightspark | 0.9.0-1699.15.pm.42 | lightspark, lightspark-debuginfo, lightspark-debugsource, lightspark-plugin, lightspark-plugin-debuginfo |
| pipewire-aptx | 1.6.9-1699.1.pm.1 | pipewire-aptx, pipewire-aptx-debuginfo, pipewire-aptx-debugsource |
| psi+-iconsets | 22.02.21+6-1699.1.pm.29, 22.02.21+6-1699.1.pm.8 | psi+-iconsets |
| python-Cython | 3.2.9-1699.2.pm.5 | python-Cython-debuginfo, python-Cython-debugsource, python313-Cython, python313-Cython-debuginfo, python314-Cython, python314-Cython-debuginfo |
| python-docutils | 0.23-1699.2.pm.2 | python313-docutils, python314-docutils |
| python-docutils-test | 0.23-1699.2.pm.9 |  |
| r8168 | 8.053.00-1699.2.pm.518 | r8168-blacklist-r8169, r8168-debugsource, r8168-kmp-default, r8168-kmp-default-debuginfo, r8168-kmp-pae, r8168-kmp-pae-debuginfo |
| rpmkey-packman | 1.0.0-1699.7.pm.11, 1.0.0-1699.7.pm.53 | rpmkey-packman |
| rtl8761b-firmware | 20200610-1699.1.pm.12, 20200610-1699.1.pm.46 | rtl8761b-firmware |
| rtmpdump | 2.4.20151223.fa8646d-1699.2.pm.16, 2.4.20151223.fa8646d-1699.2.pm.38 | librtmp-devel, librtmp1, librtmp1-32bit, librtmp1-32bit-debuginfo, librtmp1-debuginfo, rtmpdump, rtmpdump-debuginfo, rtmpdump-debugsource, rtmpgw, rtmpgw-debuginfo, rtmpsrv, rtmpsrv-debuginfo, rtmpsuck, rtmpsuck-debuginfo |
| shairplay | 20160101-1699.3.pm.18, 20160101-1699.3.pm.31 | libshairplay0, libshairplay0-debuginfo, shairplay, shairplay-debuginfo, shairplay-debugsource, shairplay-devel |
| vlc | 3.0.23-1699.10.pm.17, 3.0.23-1699.10.pm.41 | libvlc5, libvlc5-debuginfo, libvlccore9, libvlccore9-debuginfo, vlc, vlc-codec-fluidsynth, vlc-codec-fluidsynth-debuginfo, vlc-codec-gstreamer, vlc-codec-gstreamer-debuginfo, vlc-codecs, vlc-codecs-debuginfo, vlc-debuginfo, vlc-debugsource, vlc-devel, vlc-jack, vlc-jack-debuginfo, vlc-lang, vlc-noX, vlc-noX-debuginfo, vlc-qt, vlc-qt-debuginfo |
| vo-aacenc | 0.1.3-1699.1.pm.132, 0.1.3-1699.1.pm.44 | libvo-aacenc-devel, libvo-aacenc0, libvo-aacenc0-32bit, libvo-aacenc0-32bit-debuginfo, libvo-aacenc0-debuginfo, vo-aacenc-debugsource |
| x265 | 4.1-1699.4.pm.24, 4.1-1699.4.pm.7 | libhdr10plus-4_1, libhdr10plus-4_1-debuginfo, libx265-215, libx265-215-32bit, libx265-215-32bit-debuginfo, libx265-215-debuginfo, libx265-devel, x265, x265-debuginfo, x265-debugsource |
| xine-lib | 1.2.13-1699.210.pm.18, 1.2.13-1699.210.pm.7 | libxine-devel, libxine2, libxine2-32bit, libxine2-32bit-debuginfo, libxine2-codecs, libxine2-debuginfo, libxine2-jack, libxine2-jack-debuginfo, libxine2-pulse, libxine2-pulse-debuginfo, libxine2-sdl, libxine2-sdl-debuginfo, xine-lib-debugsource |
