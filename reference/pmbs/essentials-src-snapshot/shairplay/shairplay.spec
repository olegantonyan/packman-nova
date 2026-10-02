#
# spec file for package shairplay
#
# Copyright (c) 2016 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


%define libname lib%{name}0
Name:           shairplay
Version:        20160101
Release:        0
Summary:        Apple airplay and raop protocol server
License:        LGPL-2.1+ and MIT and BSD-4-Clause
Group:          Productivity/Multimedia/Sound/Players
Url:            https://github.com/juhovh/shairplay
Source:         %{name}-%{version}.tar.gz
Source1:        %{name}.service
Patch0:         makefile.patch
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  pkgconfig(ao) >= 1.1.0
BuildRequires:  libtool
BuildRequires:  pkg-config
BuildRequires:  systemd
%{?systemd_requires}
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Free portable AirPlay server implementation similar to ShairPort.
Currently only AirPort Express emulation is supported.

Download airport.key from <url>
and place it into direcory /etc/shairplay/
Shairplay need this key. 

%package        devel
Summary:        Development files for shairplay
Group:          Development/Libraries/C and C++
Requires:       %{libname} = %{version}

%description    devel
Free portable AirPlay server implementation similar to ShairPort.
Currently only AirPort Express emulation is supported.

This package contains devel files.

%package        -n %{libname}
Summary:        A library providing AirPlay server implementation
Group:          Development/Libraries/C and C++

%description    -n %{libname}
Free portable AirPlay server implementation similar to ShairPort.
Currently only AirPort Express emulation is supported.

This package contains library.

%prep
%autosetup -p1
autoreconf -vi

%build

%configure \
    --disable-static
make %{?_smp_mflags}

%install
%make_install

find %{buildroot} -type f -name "*.la" -delete -print

mkdir %{buildroot}%{_sbindir}
ln -s %{_sbindir}/service %{buildroot}%{_sbindir}/rcshairplay
# install systemd service file
install -Dm644 %{SOURCE1} %{buildroot}%{_unitdir}/shairplay.service

%pre
%service_add_pre shairplay.service

%post
%service_add_post shairplay.service

%preun
%service_del_preun shairplay.service

%postun
%service_del_postun shairplay.service

%post -n %{libname} -p /sbin/ldconfig
%postun -n %{libname} -p /sbin/ldconfig

%files
%defattr(-,root,root)
%{_sbindir}/rcshairplay
%{_unitdir}/shairplay.service
%{_bindir}/shairplay
%doc LICENSE README.md

%files -n %{libname}
%defattr(-,root,root,-)
%{_libdir}/libshairplay.so.*

%files devel
%defattr(-,root,root)
%{_libdir}/libshairplay.so
%{_includedir}/shairplay/

%changelog
