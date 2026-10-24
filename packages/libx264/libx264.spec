#
# spec file for package libx264
#
# Copyright (c) 2024 Packman Team <packman@links2linux.de>
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.links2linux.org/
#


# remember to adjust baselibs.conf
%define sover   165
Name:           libx264
Version:        20250608.b35605ac
Release:        0
Summary:        A free h264/avc encoder
License:        GPL-2.0-or-later
Group:          Productivity/Multimedia/Video/Editors and Convertors
URL:            https://code.videolan.org/videolan/x264
Source:         x264-%{version}.tar.xz
Source1:        baselibs.conf
BuildRequires:  nasm >= 2.13
BuildRequires:  pkgconfig
BuildRequires:  yasm >= 1.2.0

%description
x264 is a free library for encoding next-generation H264/AVC video
streams. The code is written from scratch by Laurent Aimar, Loren
Merritt, Eric Petit (OS X), Min Chen (vfw/asm), Justin Clay (vfw), Mans
Rullgard, Radek Czyz, Christian Heine (asm), Alex Izvorski (asm), and
Alex Wright. It is released under the terms of the GPL license. This
package contains the shared library.

Encoder features:
- CAVLC/CABAC
- Multi-references
- Intra: all macroblock types (16x16, 8x8, and 4x4 with all predictions)
- Inter P: all partitions (from 16x16 down to 4x4)
- Inter B: partitions from 16x16 down to 8x8 (including skip/direct)
- Ratecontrol: constant quantizer, single or multipass ABR, optional VBV
- Scene cut detection
- Adaptive B-frame placement
- B-frames as references / arbitrary frame order
- 8x8 and 4x4 adaptive spatial transform
- Lossless mode
- Custom quantization matrices
- Parallel encoding of multiple slices

%package %{sover}
Summary:        A free h264/avc encoder
Group:          System/Libraries

%description %{sover}
x264 is a free library for encoding next-generation H264/AVC video streams.

%package devel
Summary:        Libraries and include file for the %{name} encoder
Group:          Development/Libraries/C and C++
Requires:       %{name}-%{sover} = %{version}-%{release}
Provides:       x264-devel = %{version}
Obsoletes:      x264-devel < %{version}

%description devel
x264 is a free library for encoding next-generation H264/AVC video streams.

%prep
%autosetup -p1 -n x264-%{version}

%build
%configure \
  --disable-opencl \
  --enable-shared \
  --disable-cli \
  --disable-swscale \
  --disable-lavf \
  --disable-ffms \
  --enable-lto \
  --enable-pic
%make_build

%install
%make_install

rm -f %{buildroot}%{_libdir}/%{name}.so
rm -f %{buildroot}%{_libdir}/%{name}.a
ln -s %{name}.so.%{sover} %{buildroot}%{_libdir}/%{name}.so

# fix pkg-config version
sed -i 's/Version:.*/Version: %{version}/' %{buildroot}%{_libdir}/pkgconfig/x264.pc

%post -n %{name}-%{sover} -p /sbin/ldconfig
%postun -n %{name}-%{sover} -p /sbin/ldconfig

%files %{sover}
%{_libdir}/%{name}.so.%{sover}

%files devel
%{_includedir}/x264.h
%{_includedir}/x264_config.h
%{_libdir}/pkgconfig/x264.pc
%{_libdir}/%{name}.so

%changelog
