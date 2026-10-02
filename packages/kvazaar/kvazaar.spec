#
# spec file for package kvazaar
#
# Copyright (c) 2025 Packman Team <packman@links2linux.de>
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

%define libname libkvazaar
%define libmver 7
Name:           kvazaar
Version:        2.3.2
Release:        0
Summary:        HEVC encoder
License:        BSD-3-Clause
URL:            http://ultravideo.cs.tut.fi/#encoder
Source0:        https://github.com/ultravideo/%{name}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Patch0:         %%name.patch
BuildRequires:  cmake >= 3.25
BuildRequires:  pkgconfig
%if 0%{?suse_version} > 1500
BuildRequires:  gcc-c++
%else
BuildRequires:  gcc11
BuildRequires:  gcc11-c++
%endif
Requires:       %{libname}%{libmver} = %{version}
%ifnarch %{arm}
BuildRequires:  yasm
%endif

%description
An open-source HEVC encoder

%package -n %{libname}%{libmver}
Summary:        HEVC encoder
Group:          System/Libraries

%description -n %{libname}%{libmver}
%{libname} shared library

%package -n %{libname}-devel
Summary:        Header files %{libname}
Group:          Development/Libraries/C and C++
Requires:       %{libname}%{libmver} = %{version}

%description -n %{libname}-devel
Header files for the %{libname} library

%prep
%autosetup -p1

%build
export CC=gcc
export CXX=g++
test -x "$(type -p gcc-11)" && export CC=gcc-11
test -x "$(type -p g++-11)" && export CXX=g++-11

%cmake \
   -DCMAKE_SKIP_INSTALL_RPATH=ON
%cmake_build

%install
%cmake_install

%check

%post   -n %{libname}%{libmver} -p /sbin/ldconfig
%postun -n %{libname}%{libmver} -p /sbin/ldconfig

%files
%license LICENSE
%doc CREDITS README.md
%{_bindir}/%{name}
%{_mandir}/man1/%{name}.1%{ext_man}

%files -n %{libname}%{libmver}
%license LICENSE
%doc CREDITS README.md
%{_libdir}/%{libname}.so.%{libmver}*

%files -n %{libname}-devel
%{_includedir}/%{name}.h
%{_libdir}/%{libname}.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
