#
# spec file for package libopenaptx
#
# Copyright (c) 2021 İsmail Dönmez
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:           libopenaptx
Version:        0.2.0
Release:        0
Summary:        An implementation of Audio Processing Technology codec (aptX)
License:        LGPL-2.1-or-later
URL:            https://github.com/pali/libopenaptx
Source:         https://github.com/pali/libopenaptx/releases/download/%{version}/libopenaptx-%{version}.tar.gz
Source1000:     baselibs.conf
Patch1:         remove-rpath.patch
Patch2:         no-static.patch
BuildRequires:  gcc
BuildRequires:  pkg-config
BuildRequires:  sed

%description
An Open Source implementation of Audio Processing Technology codec (aptX)
originally derived from ffmpeg 4.0 project and licensed under GPLv3+. This codec
is mainly used in Bluetooth A2DP profile.

%package tools
Summary:    An implementation of Audio Processing Technology codec (aptX)

%description tools
An Open Source implementation of Audio Processing Technology codec (aptX)
originally derived from ffmpeg 4.0 project and licensed under GPLv3+. This codec
is mainly used in Bluetooth A2DP profile.

This package contains the encoder and decoder tool.

%package -n libopenaptx0
Summary:    An implementation of Audio Processing Technology codec (aptX)

%description -n libopenaptx0
An Open Source implementation of Audio Processing Technology codec (aptX)
originally derived from ffmpeg 4.0 project and licensed under GPLv3+. This codec
is mainly used in Bluetooth A2DP profile.

This package contains the shared library

%package devel
Summary:    An implementation of Audio Processing Technology codec (aptX)
Requires:   libopenaptx0 = %{version}

%description devel
An Open Source implementation of Audio Processing Technology codec (aptX)
originally derived from ffmpeg 4.0 project and licensed under GPLv3+. This codec
is mainly used in Bluetooth A2DP profile.

This package contains the development headers.

%prep
%setup -q
%autopatch -p1

sed -i s/"^PREFIX =.*"/"PREFIX = \/usr"/ Makefile
sed -i s/"^LIBDIR = .*"/"LIBDIR = %{_lib}"/ Makefile

%build
%make_build CC=gcc

%install
%make_install

# Emulate libfreeaptx
ln -s %{_includedir}/openaptx.h %{buildroot}/%{_includedir}/freeaptx.h
ln -s %{_libdir}/pkgconfig/libopenaptx.pc %{buildroot}/%{_libdir}/pkgconfig/libfreeaptx.pc

%post -n libopenaptx0 -p /sbin/ldconfig
%postun -n libopenaptx0 -p /sbin/ldconfig

%files -n libopenaptx0
%{_libdir}/libopenaptx.so.*

%files devel
%license COPYING
%doc README
%{_includedir}/freeaptx.h
%{_includedir}/openaptx.h
%{_libdir}/libopenaptx.so
%{_libdir}/pkgconfig/libfreeaptx.pc
%{_libdir}/pkgconfig/libopenaptx.pc

%files tools
%{_bindir}/openaptxdec
%{_bindir}/openaptxenc

%changelog
