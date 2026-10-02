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

%global fversion 5.15.285-5.15.010.0

Name:           libfprint-2-tod1-broadcom
Version:        5.15.285+5.15.010.0
Release:        0
Summary:        Proprietary driver for the Broadcom fingerprint reader
License:        NonFree
Group:          Hardware/Mobile
URL:            http://dell.archive.canonical.com/updates/pool/public/libf/%{name}/%{name}_%{fversion}.orig.tar.gz
Source0:        %{name}_%{fversion}.orig.tar.gz
BuildRequires:  pkgconfig(udev)
ExclusiveArch:  x86_64
Supplements:    modalias(usb:v0A5Cp5842d*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v0A5Cp5843d*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v0A5Cp5844d*dc*dsc*dp*ic*isc*ip*)
Supplements:    modalias(usb:v0A5Cp5845d*dc*dsc*dp*ic*isc*ip*)

%description
Proprietary driver for the fingerprint reader on the Dell Latitude 7300 - direct from Dell's Ubuntu repo

%prep
%setup -q -n brcm_linux_fp

%build

%install
install -dm 0755 %{buildroot}%{_udevrulesdir} %{buildroot}%{_libdir}/libfprint-2/tod-1 %{buildroot}%{_sharedstatedir}/fprint/fw/
install -m 0644 lib/udev/rules.d/60-libfprint-2-device-broadcom.rules %{buildroot}%{_udevrulesdir}/60-libfprint-2-device-broadcom.rules
install -m 0644 var/lib/fprint/fw/* %{buildroot}%{_sharedstatedir}/fprint/fw/
install -m 0755 usr/lib/x86_64-linux-gnu/libfprint-2/tod-1/libfprint-2-tod-1-broadcom.so %{buildroot}%{_libdir}/libfprint-2/tod-1/libfprint-2-tod-1-broadcom.so

%files
%attr(644, -, -) %license LICENCE.broadcom
%{_udevrulesdir}/60-libfprint-2-device-broadcom.rules
%dir %{_libdir}/libfprint-2
%dir %{_libdir}/libfprint-2/tod-1
%{_libdir}/libfprint-2/tod-1/libfprint-2-tod-1-broadcom.so
%dir %{_sharedstatedir}/fprint
%dir %{_sharedstatedir}/fprint/fw/
%{_sharedstatedir}/fprint/fw/*

%changelog
