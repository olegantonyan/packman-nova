#
# spec file for package libbdplus
#
# Copyright (c) 2022 SUSE LLC
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


%define libname %{name}0
Name:           libbdplus
Version:        0.2.0
Release:        0
Summary:        Open implementation of BD+ protocol
License:        LGPL-2.1+
Group:          System/Libraries
Url:            http://www.videolan.org/developers/libbdplus.html
Source0:        ftp://ftp.videolan.org/pub/videolan/%{name}/%{version}/%{name}-%{version}.tar.bz2
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libaacs-devel >= 0.7.0
BuildRequires:  libgcrypt-devel
BuildRequires:  libtool
BuildRequires:  pkgconfig

%description
libbdplus is a research project to implement the BD+ System Specifications.
This research project provides, through an open-source library, a way to
understand how the BD+ protocol works.

%package -n %{libname}
Summary:        Open implementation of BD+ protocol
Group:          System/Libraries

%description -n %{libname}
libbdplus is a research project to implement the BD+ System Specifications.
This research project provides, through an open-source library, a way to
understand how the BD+ protocol works.

%package devel
Summary:        Open implementation of BD+ protocol - Development files
Group:          Development/Languages/C and C++
Requires:       %{libname} = %{version}

%description devel
libbdplus is a research project to implement the BD+ System Specifications.
This research project provides, through an open-source library, a way to
understand how the BD+ protocol works.

%prep
%setup -q

%build
autoreconf -fvi
%configure \
    --disable-static \
    --disable-silent-rules
make %{?_smp_mflags}

%install
%make_install
find %{buildroot} -type f -name "*.la" -delete -print

%post -n %{libname} -p /sbin/ldconfig
%postun -n %{libname} -p /sbin/ldconfig

%files -n %{libname}
%license COPYING
%doc ChangeLog README.md
%{_libdir}/libbdplus.so.*

%files devel
%{_libdir}/libbdplus.so
%{_libdir}/pkgconfig/libbdplus.pc
%{_includedir}/%{name}/

%changelog
