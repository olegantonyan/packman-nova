#
# spec file for package gstreamer-plugins-bad-codecs
#

%define _name gst-plugins-bad
%define gst_branch 1.0
%define _version 1.28.0

Name:           gstreamer-plugins-bad-codecs
Version:        1.28.7
Release:        0
Summary:        Codecs/plugins for gstreamer-plugins-bad
License:        LGPL-2.1-or-later
Group:          Productivity/Multimedia/Other
URL:            https://gstreamer.freedesktop.org
Source:         %{url}/src/%{_name}/%{_name}-%{version}.tar.xz
Source99:       baselibs.conf
Patch:          build_what_we_need_only.patch

BuildRequires:  c++_compiler
BuildRequires:  faac-devel
BuildRequires:  fdupes
BuildRequires:  meson
BuildRequires:  orc >= 0.4.11
BuildRequires:  pkgconfig
BuildRequires:  python3-base
BuildRequires:  pkgconfig(glib-2.0) >= 2.40.0
BuildRequires:  pkgconfig(gmodule-export-2.0)
BuildRequires:  pkgconfig(gstreamer-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-allocators-1.0)
BuildRequires:  pkgconfig(gstreamer-audio-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-pbutils-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-plugins-base-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-video-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-codecparsers-1.0) >= %{_version}
BuildRequires:  pkgconfig(libde265) >= 0.9
BuildRequires:  pkgconfig(libopenaptx)
BuildRequires:  pkgconfig(x265)

Provides:       gstreamer-plugins-bad-orig-addon = %{version}
Obsoletes:      gstreamer-plugins-bad-orig-addon < 1.18.6
Requires:       gstreamer-plugins-bad >= %{_version}
Supplements:    gstreamer-plugins-bad

%description
GStreamer is a streaming media framework based on graphs of filters
that operate on media data. Applications using this library can do
anything media-related,from real-time sound processing to playing
videos. Its plug-in-based architecture means that new data types or
processing capabilities can be added simply by installing new
plug-ins.

%prep
%autosetup -n %{_name}-%{version} -p1

%build
%meson \
	--auto-features=disabled \
	-Dpackage-name='Packman GStreamer-plugins-bad-codecs' \
	-Dpackage-origin='https://pmbs.links2linux.de' \
	-Dlibde265=enabled \
	-Dgpl=enabled \
	-Dorc=enabled \
	-Dfaac=enabled \
	-Dx265=enabled \
	-Dopenaptx=enabled \
	%{nil}
%meson_build

%install
%meson_install

# Nuke pc file built in gstreamer-plugins-bad in distro
rm -rv %{buildroot}%{_libdir}/pkgconfig/

%files
%license COPYING
%{_libdir}/gstreamer-%{gst_branch}/libgstde265.so
%{_libdir}/gstreamer-%{gst_branch}/libgstfaac.so
%{_libdir}/gstreamer-%{gst_branch}/libgstopenaptx.so
%{_libdir}/gstreamer-%{gst_branch}/libgstx265.so

%changelog

