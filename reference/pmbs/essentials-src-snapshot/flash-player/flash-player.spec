#
# spec file for package flash-player
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


Name:           flash-player
Version:        32.0.0.465
Release:        0
Summary:        Adobe Flash Standalone Player
License:        NonFree
URL:            https://get.adobe.com/flashplayer
%ifarch %{ix86}
Source0:        flash_player_sa_11.2.202.644_linux.i386.tar.gz
%endif
%ifarch x86_64
Source0:        https://fpdownload.macromedia.com/pub/labs/flashruntimes/flashplayer/linux64/flash_player_sa_linux.x86_64.tar.gz#/flash_player_sa_%{version}_linux.x86_64.tar.gz
%endif
Source1:        flashplayer.desktop
Source2:        flashplayer.png
BuildRequires:  hicolor-icon-theme
BuildRequires:  update-desktop-files
# Flash Player dynamically opens that one and segfaults if not available (2008-11-12).
Requires:       libasound2%{?_isa}
Requires:       libcurl4%{?_isa}
ExclusiveArch:  %ix86 x86_64

%description
This package contains Adobe's Flash Player application.

%prep
%setup -q -c

cp -f %{SOURCE1} flashplayer.desktop
cp -f %{SOURCE2} flashplayer.png

%build
# Nothing to build.

%install
install -Dpm 0755 flashplayer %{buildroot}%{_bindir}/flashplayer
install -Dpm 0644 flashplayer.desktop \
  %{buildroot}%{_datadir}/applications/flashplayer.desktop
install -Dpm 0644 flashplayer.png %{buildroot}%{_datadir}/pixmaps/flashplayer.png

%suse_update_desktop_file flashplayer

%post
%ifarch %ix86
# This is an ugly hack: flash-player hard-requires SSE2. Neither
# rpm nor zypper can limit installation to SSE2 equipped systems
# only. We have to choose one of two bad things: install and let it
# crash or install and deliberately break it. The second is done
# here (boo#856386).
if ( ! grep -q '^flags.*sse2' /proc/cpuinfo ); then
    rm -f %{_bindir}/flashplayer
    echo "Flash Player requires a CPU with SSE2. It cannot work on your system." >&2
    echo "Please, uninstall it!" >&2
fi
%endif

%files
%ifarch x86_64
%license LGPL/ license.pdf
%endif
%{_bindir}/flashplayer
%{_datadir}/applications/flashplayer.desktop
%{_datadir}/pixmaps/flashplayer.png

%changelog
