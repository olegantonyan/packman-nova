#
# spec file for package psi+-iconsets
#
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

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


%define version_unconverted 22.02.21+6

Name:           psi+-iconsets
Url:            https://github.com/psi-plus
Version:        22.02.21+6
Release:        0
Summary:        Icons for Psi
License:        GPL-2.0 and CC-BY-ND-3.0
Group:          Productivity/Networking/Talk/Clients
Requires:       psi+ >= 0.16.584
Source0:        psi-plus-resources-%{version}.tar.xz
BuildArch:      noarch
BuildRequires:  fdupes
BuildRequires:  xz
Obsoletes:      %{name} >= 20100101

%define iconspath %{_datadir}/psi-plus/iconsets

%prep
%setup -q -n psi-plus-resources-%{version}

%build

%install
install -d -m 0755 %{buildroot}/%{iconspath}

for DIR in activities affiliations clients emoticons moods roster system; do
	DEST="%{buildroot}/%{iconspath}/$DIR/"
	install -d -m 0755 "$DEST"
	install -m 0644 -t "$DEST" iconsets/"$DIR"/*.jisp
done

%fdupes $RPM_BUILD_ROOT/%{iconspath}

%description
Some additional icons for Psi - emoticons.

%files
%defattr(-,root,root)
%dir %{_datadir}/psi-plus
%dir %{iconspath}
%dir %{iconspath}/activities
%dir %{iconspath}/affiliations
%dir %{iconspath}/clients
%dir %{iconspath}/emoticons
%dir %{iconspath}/moods
%dir %{iconspath}/roster
%dir %{iconspath}/system
%{iconspath}/activities/*.jisp
%{iconspath}/affiliations/*.jisp
%{iconspath}/clients/*.jisp
%{iconspath}/emoticons/*.jisp
%{iconspath}/moods/*.jisp
%{iconspath}/roster/*.jisp
%{iconspath}/system/*.jisp

%changelog
