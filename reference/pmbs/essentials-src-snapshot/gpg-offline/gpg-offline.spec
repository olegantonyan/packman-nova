#
# spec file for package gpg-offline
#
# Copyright (c) 2014 SUSE LINUX Products GmbH, Nuernberg, Germany.
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


Name:           gpg-offline
Version:        0.1
Release:        0
Summary:        Trusted GPG Offline Keyring Manipulation Tool
License:        GPL-2.0+
Group:          Hardware/Other
Source:         %{name}.gopts
Source1:        %{name}.COPYING
Source2:        genopts
Source3:        %{name}.macros
Source4:        %{name}.man.in
Source5:        %{name}.PACKAGING.HOWTO
BuildRequires:  gpg2
Requires:       diffutils
Requires:       gpg2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

%description
A tool to manipulate with locally stored keyrings. 

Package sources can contain keyrings with keys used by upstream
developers for signing of their project tarballs. Keys can be verified
offline during building process.

Package includes RPM macros for build-time offline verification of
upstream tarballs during build.

%prep
%setup -q -T -c
cp -a %{S:0} %{S:1} %{S:2} %{S:3} %{S:4} %{S:5} .
mv %{name}.COPYING COPYING
mv %{name}.PACKAGING.HOWTO PACKAGING.HOWTO

%build
sed s:@docdir@:%{_docdir}/%{name}:g <%{name}.man.in >%{name}.man
bash ./genopts %{name}

%install
install -d %{buildroot}%{_bindir} %{buildroot}%{_mandir}/man1 %{buildroot}/etc/rpm
install %{name} %{buildroot}%{_bindir}
install -m0644 %{name}.macros %{buildroot}/etc/rpm/macros.%{name}
install -m0644 %{name}.man %{buildroot}%{_mandir}/man1/%{name}.1

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%doc COPYING PACKAGING.HOWTO
%{_bindir}/*
%doc %{_mandir}/man1/*.*
/etc/rpm/macros.*

%changelog
