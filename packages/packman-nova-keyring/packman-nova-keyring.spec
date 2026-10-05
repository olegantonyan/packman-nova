Name:           packman-nova-keyring
Version:        1.0.1
Release:        0
Summary:        Repository configuration and signing key for packman-nova
License:        MIT
URL:            https://packman.omnipackage.org/
Source0:        packman-nova.repo
Source1:        packman-nova.key
Provides:       rpmkey-packman-nova
BuildArch:      noarch

%description
Public signing key and repository definition for the packman-nova
Essentials repository for Tumbleweed.

%prep

%build

%install
install -Dpm 0644 %{SOURCE1} %{buildroot}%{_datadir}/packman-nova/packman-nova.key
install -Dpm 0644 %{SOURCE0} %{buildroot}%{_sysconfdir}/zypp/repos.d/packman-nova.repo

%post
rpmkeys --import %{_datadir}/packman-nova/packman-nova.key || :

%files
%{_datadir}/packman-nova
%dir %{_sysconfdir}/zypp
%dir %{_sysconfdir}/zypp/repos.d
%config(noreplace) %{_sysconfdir}/zypp/repos.d/packman-nova.repo

%changelog
