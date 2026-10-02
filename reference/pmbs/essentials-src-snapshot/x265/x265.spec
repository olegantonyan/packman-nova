#
# spec file for package x265
#
# Copyright (c) 2024 Packman Team <packman@links2linux.de>
# Copyright (c) 2014 Torsten Gruner <t.gruner@katodev.de>
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


# add previous sover to weakremover() list below
%define sover   215
%define libname lib%name
%define libsoname %{libname}-%{sover}
%define uver    4_1
Name:           x265
Version:        4.1
Release:        0
Summary:        A free h265/HEVC encoder - encoder binary
License:        GPL-2.0-or-later
URL:            https://bitbucket.org/multicoreware/x265_git
Source0:        %name-%version.tar
Patch0:         %name.patch
Patch1:         x265.pkgconfig.patch
Patch3:         0001-Fix-arm-flags.patch
Patch4:         0004-Do-not-build-with-assembly-support-on-arm.patch
BuildRequires:  cmake
%if 0%{?suse_version} > 1500
BuildRequires:  gcc-c++
%else
BuildRequires:  gcc13
BuildRequires:  gcc13-c++
%endif
BuildRequires:  nasm >= 2.13
BuildRequires:  pkgconfig
%ifarch x86_64
BuildRequires:  libnuma-devel >= 2.0.9
%endif

%description
x265 is a free library for encoding next-generation H265/HEVC video
streams.

%package -n %{libsoname}
Summary:        A free H265/HEVC encoder - encoder binary
Provides:       weakremover(libx265-209)
Provides:       weakremover(libx265-199)
Provides:       weakremover(libx265-192)
Provides:       weakremover(libx265-188)
Provides:       weakremover(libx265-179)

%description -n %{libsoname}
x265 is a free library for encoding next-generation H265/HEVC video
streams.

%package -n libhdr10plus-%{uver}
Summary:        A free HDR10+ library

%description -n libhdr10plus-%{uver}
A free library supporting HDR10+.

%package -n %{libname}-devel
Summary:        Libraries and include file for the %{libname} encoder
Requires:       %{libsoname} = %version-%release
Requires:       libhdr10plus-%{uver} = %version-%release
Provides:       %name-devel = %version
Obsoletes:      %name-devel < %version

%description -n %{libname}-devel
x265 is a free library for encoding next-generation H265/HEVC video
streams.

%prep
%autosetup -p1

%build
test -x "$(type -p gcc)"    && CC="$_"
test -x "$(type -p g++)"    && CXX="$_"
test -x "$(type -p gcc-13)" && CC="$_"
test -x "$(type -p g++-13)" && CXX="$_"
export CC="$(readlink -f ${CC})"
export CXX="$(readlink -f ${CXX})"
CFLAGS='%optflags -Wno-misleading-indentation -Wno-unused-parameter -Wno-unused-variable'
CXXFLAGS='%optflags -Wno-misleading-indentation -Wno-unused-parameter -Wno-unused-variable'
# set the version by hand
sed -i~ "/^include(Version)/d" source/CMakeLists.txt
diff -u "$_"~ "$_" && exit 1
# force version number in the soname
sed -i~ 's/hdr10plus-shared PROPERTIES OUTPUT_NAME hdr10plus/hdr10plus-shared PROPERTIES OUTPUT_NAME hdr10plus-%version/' \
       source/CMakeLists.txt
diff -u "$_"~ "$_" && exit 1

SOURCE_DIR="$PWD"/source
COMMON_FLAGS="-DENABLE_TESTS=OFF -DENABLE_PIC=ON -Wno-dev"
HIGH_BIT_DEPTH_FLAGS="-DENABLE_CLI=OFF -DENABLE_SHARED=OFF -DEXPORT_C_API=OFF -DHIGH_BIT_DEPTH=ON"

%define __sourcedir ./source

# Build 10bit depth version of the library
%define __builddir ./source/build-10bit
%cmake $COMMON_FLAGS $HIGH_BIT_DEPTH_FLAGS \
%ifarch i586
      -DENABLE_ASSEMBLY=OFF
%endif

%make_build
cd ../..

# Build 12bit depth version of the library
%define __builddir ./source/build-12bit
%cmake $COMMON_FLAGS $HIGH_BIT_DEPTH_FLAGS -DMAIN12=ON \
%ifarch i586
      -DENABLE_ASSEMBLY=OFF
%endif

%make_build
cd ../..

mv source/build-10bit/libx265.a source/build-10bit/libx265_main10.a
mv source/build-12bit/libx265.a source/build-12bit/libx265_main12.a

# Build general version of the library linking in the 10/12bit depth versions
%define __builddir ./source/build
%cmake $COMMON_FLAGS \
       -DENABLE_SHARED=ON \
       -DX265_LATEST_TAG="%{sover}.0" \
       -DX265_VERSION="%version" \
       -DENABLE_HDR10_PLUS=ON \
       -DENABLE_CLI=ON \
       -DLINKED_10BIT=ON \
       -DLINKED_12BIT=ON \
       -DEXTRA_LINK_FLAGS="-L$SOURCE_DIR/build-10bit -L$SOURCE_DIR/build-12bit" \
       -DEXTRA_LIB="x265_main10.a;x265_main12.a"
%make_build
cd ../../

%install
%cmake_install
find %buildroot -type f -name "*.a" -delete -print0

%check

%post -n %{libsoname} -p /sbin/ldconfig
%postun -n %{libsoname} -p /sbin/ldconfig

%post -n libhdr10plus-%{uver} -p /sbin/ldconfig
%postun -n libhdr10plus-%{uver} -p /sbin/ldconfig

%files -n %{libsoname}
%doc doc/reST/releasenotes.rst
%_libdir/%{libname}.so.%{sover}*

%files -n libhdr10plus-%{uver}
%_libdir/libhdr10plus-%version.so

%files
%_bindir/*

%files -n %{libname}-devel
%license COPYING
%_includedir/*
%_libdir/pkgconfig/*.pc
%_libdir/%{libname}.so

%changelog
