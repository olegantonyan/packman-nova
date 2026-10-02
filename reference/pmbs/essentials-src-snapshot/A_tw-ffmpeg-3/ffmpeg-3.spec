#
# spec file for package ffmpeg-3
#
# Copyright (c) 2019 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


%define _lto_cflags %{nil}
# Create proper conflicts to make sure we require all from one version
# p:   Conflict string, eg if you need them all for requires instead
#      Default value Conflicts:
# c:   copmare string ie "<" or ">=", must be defined
# v:   version string ie. "< 42.3.4" or ">= 15.0.2.1", must be defined
%define devel_conflicts(p:c:v:) \
%define preamble_string %{-p:%{-p*}}%{!-p:Conflicts:} \
%define comparator %{-c:%{-c*}}%{!-c:%{error:Comparator not defined}} \
%define conflicts_version %{-v:%{-v*}}%{!-v:%{error:Version not defined}} \
\
%{preamble_string} libavcodec-devel %{comparator} %{conflicts_version} \
%{preamble_string} libavdevice-devel %{comparator} %{conflicts_version} \
%{preamble_string} libavfilter-devel %{comparator} %{conflicts_version} \
%{preamble_string} libavformat-devel %{comparator} %{conflicts_version} \
%{preamble_string} libavresample-devel %{comparator} %{conflicts_version} \
%{preamble_string} libavutil-devel %{comparator} %{conflicts_version} \
%{preamble_string} libpostproc-devel %{comparator} %{conflicts_version} \
%{preamble_string} libswresample-devel %{comparator} %{conflicts_version} \
%{preamble_string} libswscale-devel %{comparator} %{conflicts_version} \
%{preamble_string} ffmpeg-private-devel %{comparator} %{conflicts_version} \
%{nil}

%bcond_with    fdk_aac
%bcond_without librtmp
%bcond_without nvidia
%bcond_without opencore
%bcond_without vidstab
%bcond_without vo_aacenc
%bcond_without x264
%bcond_without x265
%bcond_without xvid
%bcond_without zimg
%bcond_without ffmpeg3_full_build


%define _major_version 3
%define _major_expected 4
Name:           ffmpeg-3
Version:        3.4.14
Release:        0
Summary:        Library for working with various multimedia formats
License:        LGPL-2.1-or-later AND GPL-2.0-or-later
Group:          Productivity/Multimedia/Video/Editors and Convertors
Url:            https://git.ffmpeg.org/gitweb/ffmpeg.git
Source:         %name-%version.tar.xz
Source3:        %name-rpmlintrc
Source4:        enable_decoders
Source5:        enable_encoders
Source99:       baselibs.conf
Patch0:         %name.patch
Patch1:         ffmpeg-libcdio_cdda-pkgconfig.patch
Patch2:         ffmpeg-arm6l.diff
Patch3:         ffmpeg-libopenjpeg.patch
Patch4:         ffmpeg-codec-choice.diff
Patch6:         0001-opusenc-psy-disable-stereo-searches.patch
Patch7:         ffmpeg-fix-build-fdk-aac2.patch
Patch8:         ffmpeg-x86-mathops.patch
BuildRequires:  ladspa-devel
BuildRequires:  libgsm-devel
BuildRequires:  libmp3lame-devel
BuildRequires:  nasm
BuildRequires:  pkg-config
BuildRequires:  pkgconfig(alsa)
BuildRequires:  pkgconfig(bzip2)
BuildRequires:  pkgconfig(celt) >= 0.11.0
BuildRequires:  pkgconfig(enca)
BuildRequires:  pkgconfig(fontconfig) >= 2.4.2
BuildRequires:  pkgconfig(freetype2)
BuildRequires:  pkgconfig(fribidi) >= 0.19.0
BuildRequires:  pkgconfig(gnutls)
BuildRequires:  pkgconfig(jack)
BuildRequires:  pkgconfig(libass)
BuildRequires:  pkgconfig(libavc1394)
BuildRequires:  pkgconfig(libbluray)
BuildRequires:  pkgconfig(libcdio)
BuildRequires:  pkgconfig(libcdio_paranoia)
BuildRequires:  pkgconfig(libdc1394-2)
BuildRequires:  pkgconfig(libiec61883)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  pkgconfig(libraw1394)
BuildRequires:  pkgconfig(libva) >= 0.35.0
BuildRequires:  pkgconfig(libwebp) >= 0.4
BuildRequires:  pkgconfig(ogg)
BuildRequires:  pkgconfig(opus)
BuildRequires:  pkgconfig(speex)
BuildRequires:  pkgconfig(theora) >= 1.1
BuildRequires:  pkgconfig(twolame)
BuildRequires:  pkgconfig(vdpau)
%if %{with vidstab}
BuildRequires:  pkgconfig(vidstab) >= 0.98
%endif
BuildRequires:  pkgconfig(vorbis)
BuildRequires:  pkgconfig(vpx) >= 1.3.0
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(xcb)
BuildRequires:  pkgconfig(xcb-render)
BuildRequires:  pkgconfig(xcb-shape)
BuildRequires:  pkgconfig(xcb-shm)
BuildRequires:  pkgconfig(xcb-xfixes)
BuildRequires:  pkgconfig(xext)
BuildRequires:  pkgconfig(xfixes)
%if %{with zimg}
BuildRequires:  pkgconfig(zimg)
%endif
BuildRequires:  pkgconfig(zlib)
BuildRequires:  pkgconfig(zvbi-0.2)
BuildRequires:  pkgconfig(libopenjp2)
BuildRequires:  pkgconfig(sdl2)
%if %{with fdk_aac}
BuildRequires:  pkgconfig(fdk-aac)
%endif
%if %{with librtmp}
BuildRequires:  pkgconfig(librtmp)
%endif
%if %{with xvid}
BuildRequires:  libxvidcore-devel
%endif
%if %{with opencore}
BuildRequires:  pkgconfig(opencore-amrnb)
%endif
%if %{with x264}
BuildRequires:  pkgconfig(x264)
%endif
%if %{with x265}
BuildRequires:  pkgconfig(x265)
%endif
Provides:       ffmpeg-tools = %version-%release
Obsoletes:      ffmpeg-tools < %version-%release
Provides:       ffmpeg = %version-%release
Obsoletes:      ffmpeg < %version-%release
Requires:       libavcodec57 = %version-%release
Requires:       libavdevice57 = %version-%release
Requires:       libavfilter6 = %version-%release
Requires:       libavformat57 = %version-%release
Requires:       libavresample3 = %version-%release
Requires:       libavutil55 = %version-%release
Requires:       libpostproc54 = %version-%release
Requires:       libswresample2 = %version-%release
Requires:       libswscale4 = %version-%release

%description
FFmpeg is a multimedia framework, able to decode, encode,
transcode, mux, demux, stream, filter and play several formats
that humans and machines have created.

%package -n libavcodec57
Summary:        FFmpeg codec library
# For mozillas
Group:          System/Libraries
Requires:       libavutil55 = %version-%release
Requires:       libswresample2 = %version-%release
Provides:       libavcodec = %version-%release
Provides:       libavcodec-full = %version-%release
# This can be required by packages likes vlc-codecs - following the shlib name to not get random lib providers
Provides:       libavcodec57(unrestricted)

%description -n libavcodec57
The libavcodec library provides a generic encoding/decoding framework
and contains multiple decoders and encoders for audio, video and
subtitle streams, and several bitstream filters.

%package libavcodec-devel
Summary:        Development files for FFmpeg's codec library
Group:          Development/Libraries/C and C++
Provides:       libavcodec-devel = %version-%release
Obsoletes:      libavcodec-devel < %version-%release
Requires:       %{name}-libavresample-devel = %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       libavcodec57 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavcodec-devel
The libavcodec library provides a generic encoding/decoding framework
and contains multiple decoders and encoders for audio, video and
subtitle streams, and several bitstream filters.

This subpackage contains the headers for FFmpeg libavcodec.

%package -n libavdevice57
Summary:        FFmpeg device library
Group:          System/Libraries
Requires:       libavcodec57 = %version-%release
Requires:       libavfilter6 = %version-%release
Requires:       libavformat57 = %version-%release
Requires:       libavutil55 = %version-%release

%description -n libavdevice57
The libavdevice library provides a generic framework for grabbing from
and rendering to many common multimedia input/output devices, and
supports several input and output devices, including Video4Linux2, VfW,
DShow, and ALSA.

%package libavdevice-devel
Summary:        Development files for FFmpeg's device library
Group:          Development/Libraries/C and C++
Provides:       ffmpeg-devel = %version-%release
Conflicts:      ffmpeg-devel
Provides:       ffmpeg3-devel = %version-%release
Obsoletes:      ffmpeg3-devel < %version-%release
Provides:       libavdevice-devel = %version-%release
Obsoletes:      libavdevice-devel < %version-%release
Requires:       %{name}-libavcodec-devel = %version-%release
Requires:       %{name}-libavfilter-devel = %version-%release
Requires:       %{name}-libavformat-devel = %version-%release
Requires:       %{name}-libavresample-devel = %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       %{name}-libpostproc-devel = %version-%release
Requires:       %{name}-libswresample-devel = %version-%release
Requires:       %{name}-libswscale-devel = %version-%release
Requires:       libavdevice57 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavdevice-devel
The libavdevice library provides a generic framework for grabbing from
and rendering to many common multimedia input/output devices, and
supports several input and output devices, including Video4Linux2, VfW,
DShow, and ALSA.

This subpackage contains the headers for FFmpeg libavcodec.

%package -n libavfilter6
Summary:        FFmpeg audio and video filtering library
Group:          System/Libraries
Requires:       libavcodec57 = %version-%release
Requires:       libavformat57 = %version-%release
Requires:       libavresample3 = %version-%release
Requires:       libavutil55 = %version-%release
Requires:       libpostproc54 = %version-%release
Requires:       libswresample2 = %version-%release
Requires:       libswscale4 = %version-%release

%description -n libavfilter6
The libavfilter library provides a generic audio/video filtering
framework containing several filters, sources and sinks.

%package libavfilter-devel
Summary:        Development files for FFmpeg's audio/video filter library
Group:          Development/Libraries/C and C++
Provides:       libavfilter-devel = %version-%release
Obsoletes:      libavfilter-devel < %version-%release
Requires:       %{name}-libavcodec-devel = %version-%release
Requires:       %{name}-libavformat-devel = %version-%release
Requires:       %{name}-libavresample-devel = %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       %{name}-libpostproc-devel = %version-%release
Requires:       %{name}-libswresample-devel = %version-%release
Requires:       %{name}-libswscale-devel = %version-%release
Requires:       libavfilter6 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavfilter-devel
The libavfilter library provides a generic audio/video filtering
framework containing several filters, sources and sinks.

This subpackage contains the headers for FFmpeg libavfilter.

%package -n libavformat57
Summary:        FFmpeg's stream format library
Group:          System/Libraries
Requires:       libavcodec57 = %version-%release
Requires:       libavutil55 = %version-%release

%description -n libavformat57
The libavformat library provides a generic framework for multiplexing
and demultiplexing (muxing and demuxing) audio, video and subtitle
streams. It encompasses multiple muxers and demuxers for multimedia
container formats.

%package libavformat-devel
Summary:        Development files for FFmpeg's stream format library
Group:          Development/Libraries/C and C++
Provides:       libavformat-devel = %version-%release
Obsoletes:      libavformat-devel < %version-%release
Requires:       %{name}-libavcodec-devel = %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       %{name}-libswresample-devel = %version-%release
Requires:       libavformat57 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavformat-devel
The libavformat library provides a generic framework for multiplexing
and demultiplexing (muxing and demuxing) audio, video and subtitle
streams. It encompasses multiple muxers and demuxers for multimedia
container formats.

This subpackage contains the headers for FFmpeg libavformat.

%package -n libavresample3
Summary:        FFmpeg alternate audio resampling library
Group:          System/Libraries
Requires:       libavutil55 = %version-%release

%description -n libavresample3
An audio resampling library that is being provided for drop-in
compatibility with libav.

It is advised to use libswresample for new code.

%package libavresample-devel
Summary:        Development files for libavresample as present in FFmpeg
Group:          Development/Libraries/C and C++
Provides:       libavresample-devel = %version-%release
Obsoletes:      libavresample-devel < %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       libavresample3 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavresample-devel
An audio resampling library that is being provided for drop-in
compatibility with libav.

It is advised to use libswresample for new code.

This subpackage contains the headers for FFmpeg's copy of libavresample.

%package -n libavutil55
Summary:        FFmpeg's utility library
Group:          System/Libraries

%description -n libavutil55
The libavutil library is a utility library to aid portable multimedia
programming. It contains safe portable string functions, random
number generators, data structures, additional mathematics functions,
cryptography and multimedia related functionality (like enumerations
for pixel and sample formats).

%package libavutil-devel
Summary:        Development files for FFmpeg's utility library
Group:          Development/Libraries/C and C++
Provides:       libavutil-devel = %version-%release
Obsoletes:      libavutil-devel < %version-%release
Requires:       libavutil55 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libavutil-devel
The libavutil library is a utility library to aid portable multimedia
programming. It contains safe portable string functions, random
number generators, data structures, additional mathematics functions,
cryptography and multimedia related functionality (like enumerations
for pixel and sample formats).

This subpackage contains the headers for FFmpeg libavutil.

%package -n libpostproc54
Summary:        FFmpeg post-processing library
Group:          System/Libraries
Requires:       libavutil55 = %version-%release

%description -n libpostproc54
A library with video postprocessing filters, such as deblocking and
deringing filters, noise reduction, automatic contrast and brightness
correction, linear/cubic interpolating deinterlacing.

%package libpostproc-devel
Summary:        Development files for the FFmpeg post-processing library
Group:          Development/Libraries/C and C++
Provides:       libpostproc-devel = %version-%release
Obsoletes:      libpostproc-devel < %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       libpostproc54 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libpostproc-devel
A library with video postprocessing filters, such as deblocking and
deringing filters, noise reduction, automatic contrast and brightness
correction, linear/cubic interpolating deinterlacing.

This subpackage contains the headers for FFmpeg libpostproc.

%package -n libswresample2
Summary:        FFmpeg software resampling library
Group:          System/Libraries
Requires:       libavutil55 = %version-%release

%description -n libswresample2
The libswresample library performs audio conversion between different
sample rates, channel layout and channel formats.

%package libswresample-devel
Summary:        Development files for the FFmpeg software resampling library
Group:          Development/Libraries/C and C++
Provides:       libswresample-devel = %version-%release
Obsoletes:      libswresample-devel < %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       libswresample2 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libswresample-devel
The libswresample library performs audio conversion between different
sample rates, channel layout and channel formats.

This subpackage contains the headers for FFmpeg libswresample.

%package -n libswscale4
Summary:        FFmpeg image scaling and colorspace/pixel conversion library
Group:          System/Libraries
Requires:       libavutil55 = %version-%release

%description -n libswscale4
The libswscale library performs image scaling and colorspace and
pixel format conversion operations.

%package libswscale-devel
Summary:        Development files for FFmpeg's image scaling and colorspace library
Group:          Development/Libraries/C and C++
Provides:       libswscale-devel = %version-%release
Conflicts:      libswscale-devel
Requires:       %{name}-libavutil-devel = %version-%release
Requires:       libswscale4 = %version-%release
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description libswscale-devel
The libswscale library performs image scaling and colorspace and
pixel format conversion operations.

This subpackage contains the headers for FFmpeg libswscale.

%package private-devel
Summary:        Some FFmpeg private headers
Group:          Development/Libraries/C and C++
Requires:       %{name}-libavcodec-devel = %version-%release
Requires:       %{name}-libavformat-devel = %version-%release
Requires:       %{name}-libavutil-devel = %version-%release
Provides:       ffmpeg-private-devel = %version
Obsoletes:      ffmpeg-private-devel < %version
%devel_conflicts -c < -v %{_major_version}
%devel_conflicts -c >= -v %{_major_expected}

%description private-devel
FFmpeg is a multimedia framework, able to decode, encode,
transcode, mux, demux, stream, filter and play several formats
that humans and machines have created.

This package contains some private headers for libavformat, libavcodec and
libavutil which are needed by libav-tools to build. No other package apart
from libav should depend on these private headers which are expected to
break compatibility without any notice.

%prep
%autosetup -p1

%build
echo '%version' > VERSION

if \
env \
CFLAGS="%optflags" \
./configure \
	--prefix="%_prefix" --libdir="%_libdir" --shlibdir="%_libdir" \
	--incdir="%_includedir/ffmpeg" \
	--extra-cflags="%optflags" --optflags="%optflags" \
	--disable-htmlpages \
	--enable-pic --disable-stripping \
	--enable-shared --disable-static \
	--enable-gpl \
	--disable-openssl \
	--enable-avresample \
	--enable-libcdio \
	--enable-gnutls \
	--enable-ladspa \
%if %{without nvidia}
	--disable-cuda \
	--disable-cuvid \
%endif
	--enable-libass \
	--enable-libbluray \
	--enable-libcelt \
	--enable-libcdio \
	--enable-libdc1394 \
	--enable-libfreetype \
	--enable-libgsm \
	--enable-libiec61883 \
	--enable-libmp3lame \
	--enable-libopenjpeg \
	--enable-libopus \
	--enable-libpulse \
	--enable-libspeex \
	--enable-libtheora \
	--enable-libtwolame \
%if %{with vidstab}
	--enable-libvidstab \
%endif
	--enable-libvorbis \
	--enable-libvpx \
	--enable-libwebp \
%if %{with zimg}
	--enable-libzimg \
%endif
	--enable-libzvbi \
	--enable-vaapi \
	--enable-vdpau \
%if %{with fdk_aac}
	--enable-libfdk_aac --enable-nonfree \
%endif
%if %{with opencore}
	--enable-libopencore-amrnb \
	--enable-libopencore-amrwb \
	--enable-version3 \
%endif
%if %{with x264}
	--enable-libx264 \
%endif
%if %{with x265}
	--enable-libx265 \
%endif
%if %{with xvid}
	--enable-libxvid \
%endif
	%{nil}
then
	: good
else
	: bad
	cat ffbuild/config.log
	exit 1
fi

cat config.h
%make_build

%global extratools aviocat cws2fws ffescape ffeval ffhash fourcc2pixfmt graph2dot ismindex pktdumper probetest qt-faststart seek_print sidxindex trasher

for i in %extratools; do
	make "tools/$i"
done

%install
b="%buildroot"
%make_install install-man

%if %{with ffmpeg3_full_build}
rm -Rf "$b/%_datadir/ffmpeg/examples"
for i in %extratools; do
	cp -a "tools/$i" "$b/%_bindir/"
done
%else
rm -Rf "$b/%_bindir" "$b/%_mandir/man1" "$b/%_datadir/ffmpeg"
%endif

# Install private headers required by libav-tools
for i in libavformat/options_table.h libavformat/os_support.h \
  libavformat/internal.h libavcodec/options_table.h libavutil/libm.h \
  libavutil/internal.h libavutil/colorspace.h libavutil/timer.h \
  libavutil/x86/emms.h libavutil/aarch64/timer.h libavutil/arm/timer.h \
  libavutil/bfin/timer.h libavutil/ppc/timer.h libavutil/x86/timer.h; do
	mkdir -p "$b/%_includedir/ffmpeg/private/"`dirname $i`
	cp -a $i "$b/%_includedir/ffmpeg/private/$i"
done

%post   -n libavcodec57 -p /sbin/ldconfig
%postun -n libavcodec57 -p /sbin/ldconfig
%post   -n libavdevice57 -p /sbin/ldconfig
%postun -n libavdevice57 -p /sbin/ldconfig
%post   -n libavfilter6 -p /sbin/ldconfig
%postun -n libavfilter6 -p /sbin/ldconfig
%post   -n libavformat57 -p /sbin/ldconfig
%postun -n libavformat57 -p /sbin/ldconfig
%post   -n libavresample3 -p /sbin/ldconfig
%postun -n libavresample3 -p /sbin/ldconfig
%post   -n libavutil55 -p /sbin/ldconfig
%postun -n libavutil55 -p /sbin/ldconfig
%post   -n libpostproc54 -p /sbin/ldconfig
%postun -n libpostproc54 -p /sbin/ldconfig
%post   -n libswresample2 -p /sbin/ldconfig
%postun -n libswresample2 -p /sbin/ldconfig
%post   -n libswscale4 -p /sbin/ldconfig
%postun -n libswscale4 -p /sbin/ldconfig

%if %{with ffmpeg3_full_build}
%files
%doc CREDITS README.md
%_bindir/*
%_mandir/man1/ff*.1*
%_datadir/ffmpeg/
%endif

%files -n libavcodec57
%_libdir/libavcodec.so.*

%files -n libavdevice57
%_libdir/libavdevice.so.*

%files -n libavfilter6
%_libdir/libavfilter.so.*

%files -n libavformat57
%_libdir/libavformat.so.*

%files -n libavresample3
%_libdir/libavresample.so.*

%files -n libavutil55
%doc Changelog
%license COPYING.GPLv2 LICENSE.md
%_libdir/libavutil.so.*

%files -n libpostproc54
%_libdir/libpostproc.so.*

%files -n libswresample2
%_libdir/libswresample.so.*

%files -n libswscale4
%_libdir/libswscale.so.*

%files libavcodec-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavcodec/
%_libdir/libavcodec.so
%_libdir/pkgconfig/libavcodec.pc
%_mandir/man3/libavcodec.3*

%files libavdevice-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavdevice/
%_libdir/libavdevice.so
%_libdir/pkgconfig/libavdevice.pc
%_mandir/man3/libavdevice.3*

%files libavfilter-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavfilter/
%_libdir/libavfilter.so
%_libdir/pkgconfig/libavfilter.pc
%_mandir/man3/libavfilter.3*

%files libavformat-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavformat/
%_libdir/libavformat.so
%_libdir/pkgconfig/libavformat.pc
%_mandir/man3/libavformat.3*

%files libavresample-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavresample/
%_libdir/libavresample.so
%_libdir/pkgconfig/libavresample.pc

%files libavutil-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libavutil/
%_libdir/libavutil.so
%_libdir/pkgconfig/libavutil.pc
%_mandir/man3/libavutil.3*

%files libpostproc-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libpostproc/
%_libdir/libpostproc.so
%_libdir/pkgconfig/libpostproc.pc

%files libswresample-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libswresample/
%_libdir/libswresample.so
%_libdir/pkgconfig/libswresample.pc
%_mandir/man3/libswresample.3*

%files libswscale-devel
%dir %_includedir/ffmpeg/
%_includedir/ffmpeg/libswscale/
%_libdir/libswscale.so
%_libdir/pkgconfig/libswscale.pc
%_mandir/man3/libswscale.3*

%files private-devel
%_includedir/ffmpeg/private/

%changelog
