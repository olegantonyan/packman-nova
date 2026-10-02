#
# spec file for package pipewire-aptx
#


%define spaversion   0.2
%define soversion 0_2
%define minimum_version 1.6.0

Name:           pipewire-aptx
Version:        1.6.9
Release:        0
Summary:        PipeWire Bluetooth aptX codec plugin
License:        MIT
URL:            https://gitlab.freedesktop.org/pipewire/pipewire
Source0:        %{url}/-/archive/%{version}/pipewire-%{version}.tar.bz2
Source1:        pipewire-aptx-rpmlintrc

BuildRequires:  c++_compiler
BuildRequires:  c_compiler
BuildRequires:  meson >= 0.61.1
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(bluez)
BuildRequires:  pkgconfig(dbus-1)
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(libfreeaptx)
BuildRequires:  pkgconfig(sbc)

Requires:       pipewire >= %{minimum_version}
Requires:       pipewire-spa-plugins-%{soversion} >= %{version}
# Disable autoinstall
#Supplements:    (pipewire and pipewire-spa-plugins-%%{soversion})

%description
PipeWire media server Bluetooth aptX codec plugin.

%prep
%autosetup -p1 -n pipewire-%{version}

%build
%meson \
	--auto-features=disabled \
	-D examples=disabled \
	-D session-managers="[]" \
	-D bluez5=enabled \
	-D bluez5-codec-aptx=enabled \
	%{nil}
%meson_build spa-codec-bluez5-aptx

%install
mkdir -p %{buildroot}%{_libdir}/spa-%{spaversion}/bluez5
install -pm 0755 %{_vpath_builddir}/spa/plugins/bluez5/libspa-codec-bluez5-aptx.so \
   %{buildroot}%{_libdir}/spa-%{spaversion}/bluez5/

%files
%license COPYING
%dir %{_libdir}/spa-%{spaversion}
%dir %{_libdir}/spa-%{spaversion}/bluez5
%{_libdir}/spa-%{spaversion}/bluez5/libspa-codec-bluez5-aptx.so

%changelog
