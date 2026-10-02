#
# spec file for package gstreamer-plugins-ugly-codecs
#

%define _name gst-plugins-ugly
%define gst_branch 1.0
%define _version 1.28.0

Name:           gstreamer-plugins-ugly-codecs
Version:        1.28.7
Release:        0
Summary:        Codecs/plugins for gstreamer-plugins-ugly
License:        LGPL-2.1-or-later
Group:          Productivity/Multimedia/Other
URL:            https://gstreamer.freedesktop.org
Source0:        %{url}/src/%{_name}/%{_name}-%{version}.tar.xz
Source99:       baselibs.conf

BuildRequires:  c++_compiler
BuildRequires:  c_compiler
BuildRequires:  meson
BuildRequires:  orc >= 0.4.16
BuildRequires:  pkgconfig
BuildRequires:  python3-base
BuildRequires:  pkgconfig(glib-2.0) >= 2.40.0
BuildRequires:  pkgconfig(gmodule-no-export-2.0)
BuildRequires:  pkgconfig(gstreamer-1.0) >= %{_version}
BuildRequires:  pkgconfig(gstreamer-app-1.0)
BuildRequires:  pkgconfig(gstreamer-audio-1.0)
BuildRequires:  pkgconfig(gstreamer-base-1.0)
BuildRequires:  pkgconfig(gstreamer-controller-1.0)
BuildRequires:  pkgconfig(gstreamer-fft-1.0)
BuildRequires:  pkgconfig(gstreamer-net-1.0)
BuildRequires:  pkgconfig(gstreamer-pbutils-1.0)
BuildRequires:  pkgconfig(gstreamer-riff-1.0)
BuildRequires:  pkgconfig(gstreamer-rtp-1.0)
BuildRequires:  pkgconfig(gstreamer-rtsp-1.0)
BuildRequires:  pkgconfig(gstreamer-sdp-1.0)
BuildRequires:  pkgconfig(gstreamer-tag-1.0)
BuildRequires:  pkgconfig(gstreamer-video-1.0)
BuildRequires:  pkgconfig(x264) >= 0.156

Requires:       gstreamer-plugins-ugly >= %{_version}
Supplements:    gstreamer-plugins-ugly
Provides:       gstreamer-plugins-ugly-orig-addon = %{version}
Obsoletes:      gstreamer-plugins-ugly-orig-addon < 1.18.6

%description
This package contains well-written plug-ins that can't be shipped
in gstreamer-plugins-good or in distro gstreamer-plugins-ugly because:
- the license is not LGPL
- the license of the library is not LGPL
- there are possible licensing issues with the code.

Package provides the missing plugins from main distro
gstreamer-plugins-ugly package.
- x264 encoder

%prep
%autosetup -n %{_name}-%{version} -p1

%build
%meson \
	--auto-features=disabled \
	-Dpackage-name='Packman GStreamer-plugins-ugly-codecs' \
	-Dpackage-origin='https://pmbs.links2linux.de' \
	-Dgpl=enabled \
	-Dorc=enabled \
	-Dx264=enabled \
	%{nil}
%meson_build

%install
%meson_install

%files
%license COPYING
%{_datadir}/gstreamer-%{gst_branch}/presets/GstX264Enc.prs
%{_libdir}/gstreamer-%{gst_branch}/libgstx264.so

%changelog

