#
# spec file for package libde265
#
# Copyright (c) 2023 Packman Team <packman@links2linux.de>
# Copyright (c) 2017 Bjørn Lie, Bryne, Norway.
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

%define so_ver  0
Name:           libde265
Version:        1.1.3
Release:        0
Summary:        Open H.265 video codec implementation
License:        LGPL-3.0-only
Group:          System/Libraries
URL:            https://www.libde265.org/
Source0:        https://github.com/strukturag/libde265/releases/download/v%{version}/%{name}-%{version}.tar.gz
Source99:       baselibs.conf

BuildRequires:  c++_compiler
BuildRequires:  cmake
BuildRequires:  pkgconfig

%description
libde265 is an open source implementation of the H.265 video codec.
It is written from scratch for simplicity and efficiency. Its simple
API makes it easy to integrate it into other software.

%package -n %{name}-%{so_ver}
Summary:        Open H.265 video codec implementation - libraries
Group:          System/Libraries

%description -n %{name}-%{so_ver}
libde265 is an open source implementation of the H.265 video codec.
It is written from scratch for simplicity and efficiency. Its simple
API makes it easy to integrate it into other software.

This package contains the library files.

%package devel
Summary:        Open H.265 video codec implementation - development files
Group:          Development/Libraries/Other
Requires:       %{name}-%{so_ver} = %{version}

%description devel
libde265 is an open source implementation of the H.265 video codec.
It is written from scratch for simplicity and efficiency. Its simple
API makes it easy to integrate it into other software.

The development headers for compiling programs that use libde265
are provided by this package.

%prep
%autosetup -p1

%build
%cmake \
	-D ENABLE_SDL=OFF \
	-D ENABLE_DECODER=OFF \
	%{nil}
%cmake_build

%install
%cmake_install

%ldconfig_scriptlets -n %{name}-%{so_ver}

%files -n %{name}-%{so_ver}
%license COPYING
%{_libdir}/%{name}.so.*

%files devel
%doc AUTHORS README.md
%{_includedir}/%{name}/
%dir %{_libdir}/cmake/%{name}
%{_libdir}/cmake/%{name}/%{name}*.cmake
%{_libdir}/%{name}.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
