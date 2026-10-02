#
# spec file for package lightspark
#
# Copyright (c) 2021 SUSE LLC
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


%bcond_with    rtmp
Name:           lightspark
Version:        0.9.0
Release:        0
Summary:        Flash player implementation
License:        LGPL-3.0-or-later
Group:          Productivity/Multimedia/Other
URL:            https://lightspark.github.io/
Source0:        %{name}-%{version}.tar.xz

BuildRequires:  boost-devel
BuildRequires:  cmake
BuildRequires:  desktop-file-utils
BuildRequires:  gcc-c++
BuildRequires:  gettext-tools
BuildRequires:  hicolor-icon-theme
BuildRequires:  llvm-devel >= 2.8
BuildRequires:  nasm
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(cairo)
BuildRequires:  pkgconfig(gdk-2.0)
BuildRequires:  pkgconfig(gl)
BuildRequires:  pkgconfig(glew)
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(gmodule-2.0)
BuildRequires:  pkgconfig(gthread-2.0)
BuildRequires:  pkgconfig(libavcodec) < 59
BuildRequires:  pkgconfig(libavformat) < 59
BuildRequires:  pkgconfig(libavresample)
BuildRequires:  pkgconfig(libavutil) < 57
BuildRequires:  pkgconfig(libcurl)
BuildRequires:  pkgconfig(libjpeg)
BuildRequires:  pkgconfig(liblzma)
BuildRequires:  pkgconfig(libpng)
BuildRequires:  pkgconfig(libxml++-2.6) >= 2.33.1
BuildRequires:  pkgconfig(ncurses)
BuildRequires:  pkgconfig(pango)
BuildRequires:  pkgconfig(pangocairo)
BuildRequires:  pkgconfig(sdl2)
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(zlib)
Requires(post): hicolor-icon-theme
Requires(post): update-desktop-files
Requires(postun): hicolor-icon-theme
Requires(postun): update-desktop-files
Recommends:     %{_bindir}/gnash
ExclusiveArch:  %{ix86} x86_64

%if %{with librtmp}
BuildRequires:  pkgconfig(libcrypto)
BuildRequires:  pkgconfig(librtmp)
BuildRequires:  pkgconfig(libssl)
%endif

%description
Lightspark is an Flash player implementation for playing files in SWF
format. Lightspark can run as a web browser plugin or as a standalone
application.

Lightspark supports SWF files written on the newest version of the
ActionScript language, ActionScript 3.0, which was introduced at the
same time as Flash Player 9.

%package plugin
Summary:        NPAPI plugin for lightspark
Group:          Productivity/Multimedia/Other
Requires:       %{name} = %{version}
Enhances:       browser(npapi)
Conflicts:      flash-player
Conflicts:      gnash-browser-plugin

%description plugin
NPAPI plugin for lightspark.

%prep
%autosetup
rm -f build

%build
%cmake \
  -DPLUGIN_DIRECTORY=%{_libdir}/browser-plugins \
  -DPPAPI_PLUGIN_DIRECTORY=%{_libdir}/browser-plugins \
  -DENABLE_LIBAVCODEC=YES \
  -DENABLE_RTMP=%{?with_rtmp:YES}%{!?with_rtmp:NO} \
  %ifarch x86_64 || %{ix86}
  -DENABLE_SSE2=true \
  %endif
  -Wno-dev
%cmake_build

%install
%cmake_install
rm -f %{buildroot}%{_libdir}/%{name}/lib%{name}.so
mv %{buildroot}%{_libdir}/%{name}/* \
  %{buildroot}%{_libdir}/
# Not in hicolor theme (lp#1000840)
rm -rf %{buildroot}%{_datadir}/icons/hicolor/20x20

%ldconfig_scriptlets

%files
%license COPYING.LESSER
%doc ChangeLog
%config(noreplace) %{_sysconfdir}/xdg/lightspark.conf
%attr(0755,root,root) %{_bindir}/lightspark
%{_datadir}/applications/lightspark.desktop
%{_datadir}/icons/hicolor/*/*/*
%{_mandir}/man1/lightspark.1*
%{_libdir}/lib%{name}.so*
%{_libdir}/libCore.so

%files plugin
%{_libdir}/browser-plugins/*.so
%{_libdir}/browser-plugins/manifest.json

%changelog
