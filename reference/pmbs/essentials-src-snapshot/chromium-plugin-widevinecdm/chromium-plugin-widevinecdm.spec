#
# spec file for package chromium-plugin-widevinecdm
#
# Copyright (c) 2016 Packman Team <packman@links2linux.de>
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


# To find out the real version of Widevine CDM, do something like this.
# d="$(mktemp -d)" && rpm2cpio *.rpm|cpio -idmD"$d" && grep \"version\" "$d"/opt/google/chrome/WidevineCdm/manifest.json | sed 's/[a-z":,[:space:]]*//g' && rm -r "$d"
%define _chrome_version 134.0.6998.165
Name:           chromium-plugin-widevinecdm
Version:        4.10.2891.0
Release:        0
Summary:        Chromium Widevine CDM plugin
License:        NonFree
URL:            https://google.com/chrome
Source:         https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-%{_chrome_version}-1.x86_64.rpm
BuildRequires:  cpio
BuildRequires:  rpm
Requires:       chromium-browser
# chromium-widevinecdm-plugin was last used in openSUSE Leap 42.1.
Provides:       chromium-widevinecdm-plugin = 22.%{version}
Obsoletes:      chromium-widevinecdm-plugin < 22.%{version}
ExclusiveArch:  x86_64

%description
Official Widevine CDM plugin for Google's FOSS browser Chromium.

%prep
%setup -q -c -T
rpm2cpio %{SOURCE0} | cpio -idmv

%build
# Nothing to build.

%install
mkdir -p %{buildroot}%{_libdir}/chromium/
cp -r opt/google/chrome/WidevineCdm %{buildroot}%{_libdir}/chromium/

%files
%license opt/google/chrome/WidevineCdm/LICENSE
%dir %{_libdir}/chromium
%dir %{_libdir}/chromium/WidevineCdm
%dir %{_libdir}/chromium/WidevineCdm/_platform_specific
%dir %{_libdir}/chromium/WidevineCdm/_platform_specific/linux_x64
%{_libdir}/chromium/WidevineCdm/LICENSE
%{_libdir}/chromium/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so
%{_libdir}/chromium/WidevineCdm/manifest.json

%changelog
