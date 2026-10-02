#
# spec file for package libfprint-tod-broadcom
#
# Copyright (c) 2022 Lukas Krejza "Gryffus" <gryffus@hkfree.org> 
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

%define soname libfprint-tod-goodix-53xc

Name:           libfprint-2-tod1-goodix
Version:        0.0.6
Release:        0
Summary:        Goodix driver module for libfprint-2 Touch OEM Driver
License:        NonFree
Group:          Hardware/Mobile
URL:            http://dell.archive.canonical.com/updates/pool/public/libf/%{name}/%{name}_%{version}.orig.tar.gz
Source0:        %{name}_%{version}.orig.tar.gz
Source1:        LICENCE.goodix
BuildRequires:  pkgconfig(udev)
ExclusiveArch:  x86_64
Supplements:    modalias(usb:v27C6p538Cd*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v27C6p533Cd*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v27C6p530Cd*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v27C6p5840d*dc*dsc*dp*ic*isc*ip*)

%description
This is user space driver for Goodix finger print module. Proprietary driver for the fingerprint reader on the Dell XPS 13 9300 - direct from Dell's Ubuntu repo.

%prep
%setup -q
# Copy license file to build directory
cp %{SOURCE1} .

%build

%install
install -dm 0755 %{buildroot}%{_udevrulesdir} %{buildroot}%{_libdir}/libfprint-2/tod-1/
install -m 0644 lib/udev/rules.d/60-%{name}.rules %{buildroot}%{_udevrulesdir}/60-%{name}.rules
install -m 0755 usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/%soname-%{version}.so %{buildroot}%{_libdir}/libfprint-2/tod-1/%soname-%{version}.so

%files
%license LICENCE.goodix
%{_udevrulesdir}/60-%{name}.rules
%dir %{_libdir}/libfprint-2
%dir %{_libdir}/libfprint-2/tod-1
%{_libdir}/libfprint-2/tod-1/%soname-%{version}.so

%changelog
