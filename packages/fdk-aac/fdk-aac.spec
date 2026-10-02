#
# spec file for package fdk-aac
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


%define _sover  2
Name:           fdk-aac
Version:        2.0.3
Release:        0
Summary:        A standalone library of the Fraunhofer FDK AAC code from Android
License:        NonFree
URL:            https://github.com/mstorsjo/fdk-aac
Source0:        %{url}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
Source1:        baselibs.conf

BuildRequires:  c++_compiler
BuildRequires:  libtool
BuildRequires:  pkgconfig

%description
A standalone library of the Fraunhofer FDK AAC code from Android

For further information, read:
wiki.hydrogenaud.io/Fraunhofer_FDK_AAC

%package -n libfdk-aac%{_sover}
Summary:        A standalone library of the Fraunhofer FDK AAC code from Android

%description -n libfdk-aac%{_sover}
A standalone library of the Fraunhofer FDK AAC code from Android

For further information, read:
wiki.hydrogenaud.io/Fraunhofer_FDK_AAC

%package devel
Summary:        Development headers for Fraunhofer FDK AAC
Requires:       libfdk-aac%{_sover} = %{version}

%description devel
This package provides development headers for Fraunhofer FDK AAC code

%prep
%autosetup -p1
# Remove DATE/TIME, make build more reproducible
sed -i "s/__DATE__/\"\"/g" lib*/src/{*.cpp,*version.h}
sed -i "s/__TIME__/\"\"/g" lib*/src/{*.cpp,*version.h}

%build
NOCONFIGURE=1 ./autogen.sh
%configure \
	--disable-static
%make_build

%install
%make_install
find %{buildroot} -type f -name "*.la" -delete -print

%ldconfig_scriptlets -n libfdk-aac%{_sover}

%files -n libfdk-aac%{_sover}
%license NOTICE
%{_libdir}/libfdk-aac.so.*

%files devel
%doc ChangeLog
%{_includedir}/fdk-aac
%{_libdir}/libfdk-aac.so
%{_libdir}/pkgconfig/fdk-aac.pc

%changelog
