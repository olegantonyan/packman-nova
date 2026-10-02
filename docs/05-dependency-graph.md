# Build order inside Essentials

Everything not listed comes from the Tumbleweed `oss` repo of the matching snapshot.

```
tier 0  no Packman-internal deps:
        libde265  kvazaar  fdk-aac  faac  vo-aacenc  amrnb  amrwb  dcadec  l-smash  libopenaptx
        rtmpdump  libaacs  libbdplus  libdvdcss2  SVT-AV1  gpac  r8168  broadcom-wl  firmware/blobs
tier 1  libx264 (lib flavor)        x265                pipewire-aptx (libopenaptx)
tier 2  ffmpeg-9/8/7/4 (x264 x265 fdk-aac amr* vo-aacenc rtmpdump xvid[Factory] ...)
        libheif (x265 libde265 kvazaar)
tier 3  libx264:x264 CLI (ffmpeg libs, l-smash, ffms2)
        vlc (ffmpeg, x264, x265, libdvdcss recommends)
        gstreamer-plugins-bad-codecs (x265 libde265 faac libopenaptx)   gstreamer-plugins-ugly-codecs (x264)
        libquicktime, xine-lib, shairplay (ffmpeg)
```

Cross-project: Multimedia (handbrake, kodi, MPlayer, obs-studio ...) builds on top of Essentials' ffmpeg/x264/x265. Extra's Mesa builds need nothing from Essentials but ~20 GB RAM.

Solver hazards handled by Packman's prjconf: multiple ffmpeg API versions provide the same unversioned `pkgconfig(libavcodec)`, and Factory's `ffmpeg-N-mini-*` flavors. Replicate with explicit versioned BuildRequires or pinned build-root package lists.
