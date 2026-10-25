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
%define _xhe_sover 0
Name:           fdk-aac
Version:        3.0.0
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

%package -n libfdk-xhe-aac%{_xhe_sover}
Summary:        Fraunhofer FDK xHE-AAC encoder library

%description -n libfdk-xhe-aac%{_xhe_sover}
A standalone library of the Fraunhofer FDK xHE-AAC encoder

%package devel
Summary:        Development headers for Fraunhofer FDK AAC
Requires:       libfdk-aac%{_sover} = %{version}
Requires:       libfdk-xhe-aac%{_xhe_sover} = %{version}

%description devel
This package provides development headers for Fraunhofer FDK AAC code

%prep
%autosetup -p1
# Remove DATE/TIME, make build more reproducible
grep -rlZ -e __DATE__ -e __TIME__ cpp xhe-aac | xargs -0 sed -i -e 's/__DATE__/""/g' -e 's/__TIME__/""/g'

%build
NOCONFIGURE=1 ./autogen.sh
%configure \
	--disable-static
%make_build

%install
%make_install
find %{buildroot} -type f -name "*.la" -delete -print

%ldconfig_scriptlets -n libfdk-aac%{_sover}
%ldconfig_scriptlets -n libfdk-xhe-aac%{_xhe_sover}

%files -n libfdk-aac%{_sover}
%license NOTICE
%{_libdir}/libfdk-aac.so.*

%files -n libfdk-xhe-aac%{_xhe_sover}
%license NOTICE
%{_libdir}/libfdk-xhe-aac.so.*

%files devel
%doc ChangeLog
%{_includedir}/fdk-aac
%{_includedir}/fdk-xhe-aac
%{_libdir}/libfdk-aac.so
%{_libdir}/libfdk-xhe-aac.so
%{_libdir}/pkgconfig/fdk-aac.pc
%{_libdir}/pkgconfig/fdk-xhe-aac.pc

%changelog
