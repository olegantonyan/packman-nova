#
# spec file for package libaacs
#
# Copyright (c) 2022 Packman Team <packman@links2linux.de>
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
# Copyright (c) 2011 Dominique Leuenberger, Amsterdam, The Netherlands.
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


%define sover   0
Name:           libaacs
Version:        0.12.0
Release:        0
Summary:        Open implentation of AACS specification
License:        LGPL-2.1-or-later
Group:          System/Libraries
URL:            https://www.videolan.org/developers/libaacs.html
Source:         https://download.videolan.org/videolan/%{name}/%{version}/%{name}-%{version}.tar.bz2
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  bison
BuildRequires:  flex
BuildRequires:  libgcrypt-devel
BuildRequires:  libtool
BuildRequires:  pkgconfig

%description
libaacs is a research project to implement the Advanced Access Content System specification.
This research project provides, through an open-source library, a way to understand how the AACS works.

%package -n %{name}%{sover}
Summary:        Open implentation of AACS specification
Group:          System/Libraries

%description -n %{name}%{sover}
libaacs is a research project to implement the Advanced Access Content System specification.
This research project provides, through an open-source library, a way to understand how the AACS works.

%package devel
Summary:        Open implentation of AACS specification - Development files
Group:          Development/Languages/C and C++
Requires:       %{name}%{sover} = %{version}

%description devel
libaacs is a research project to implement the Advanced Access Content System specification.
This research project provides, through an open-source library, a way to understand how the AACS works.

%prep
%autosetup

%build
autoreconf -fvi
%configure \
    --disable-static \
    --disable-silent-rules
%make_build

%install
%make_install
find %{buildroot} -type f -name "*.la" -delete -print

%post -n %{name}%{sover} -p /sbin/ldconfig
%postun -n %{name}%{sover} -p /sbin/ldconfig

%files -n %{name}%{sover}
%license COPYING
%{_bindir}/aacs_info
%{_libdir}/%{name}.so.%{sover}
%{_libdir}/%{name}.so.%{sover}.*

%files devel
%{_libdir}/%{name}.so
%{_libdir}/pkgconfig/%{name}.pc
%{_includedir}/%{name}/

%changelog
