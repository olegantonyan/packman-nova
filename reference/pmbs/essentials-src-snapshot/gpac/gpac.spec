#
# spec file for package gpac
#
# Copyright (c) 2024 Packman Team <packman@links2linux.de>
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
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


%define sover   12
Name:           gpac
Version:        2.4.0
Release:        0
Summary:        A multimedia framework covering MPEG-4, VRML/X3D and SVG
License:        LGPL-2.1-or-later
Group:          Productivity/Multimedia/Video/Editors and Convertors
Url:            http://gpac.io
Source:         https://github.com/gpac/%{name}/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
#PATCH-FIX-UPSTREAM i@marguerite.su - fix SVGGen ldflags
Patch2:         gpac-0.7.1-SVGGen_abuild.patch
#PATCH-FIX-UPSTREAM wengxuetian@gmail.com - fix E: 64bit-portability-issue
Patch3:         gpac-1.0.0-64bit-portability.patch
Patch12:        gpac.ssl.patch
#PATCH-FIX-OPENSUSE gpac-rpath.patch aloisio@gmx.com - fix rpath error
Patch13:        gpac-rpath.patch
%if 0%{?suse_version} > 1500
#PATCH-FIX-OPENSUSE gpac.a52dec.patch manfred.h@gmx.net - add missing parameter to a52_init()
Patch15:        gpac.a52dec.patch
%endif
#PATCH-FIX-OPENSUSE gpac-missing-prototype.patch manfred.h@gmx.net - add missing prototype declarations
Patch16:        gpac-missing-prototype.patch
BuildRequires:  Mesa-devel
BuildRequires:  dos2unix
BuildRequires:  doxygen
BuildRequires:  fdupes
BuildRequires:  gcc-c++
BuildRequires:  graphviz
BuildRequires:  hicolor-icon-theme
BuildRequires:  libxvidcore-devel
BuildRequires:  update-desktop-files
BuildRequires:  pkgconfig(alsa)
BuildRequires:  pkgconfig(faad2)
BuildRequires:  pkgconfig(freetype2)
BuildRequires:  pkgconfig(glut)
BuildRequires:  pkgconfig(liba52)
BuildRequires:  pkgconfig(libavcodec) < 60
BuildRequires:  pkgconfig(libavformat) < 60
BuildRequires:  pkgconfig(libswscale) < 7
BuildRequires:  pkgconfig(libavdevice) < 60
BuildRequires:  pkgconfig(libavutil) < 58
BuildRequires:  pkgconfig(libjpeg)
BuildRequires:  pkgconfig(libopenjp2)
BuildRequires:  pkgconfig(libxml-2.0)
BuildRequires:  pkgconfig(mad)
BuildRequires:  pkgconfig(ogg)
BuildRequires:  pkgconfig(openssl)
BuildRequires:  pkgconfig(libpng)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  pkgconfig(librsvg-2.0)
BuildRequires:  pkgconfig(sdl2)
BuildRequires:  pkgconfig(theora)
BuildRequires:  pkgconfig(vorbis)
BuildRequires:  pkgconfig(zlib)

%description
GPAC is a multimedia framework for MPEG-4, VRML/X3D and SVG/SMIL.

GPAC is built upon an implementation of the MPEG-4 Systems standard
(ISO/IEC 14496-1) developed from scratch in C.

The main development goal is to provide a clean (a.k.a. readable by
as many people as possible), small and flexible alternative to the
MPEG-4 Systems reference software (known as IM1 and distributed in
ISO/IEC 14496-5).

The second development goal is to achieve integration of recent
multimedia standards (SVG/SMIL, VRML, X3D, SWF, etc) into a single
framework. This stage is still under drafting but GPAC already
supports most of VRML97, some X3D as well as very simple SVG.

GPAC already features 2D and 3D multimedia playback, MPEG-4 Systems
encoders/multiplexers and publishing tools for content distribution.

GPAC is licensed under the GNU Lesser General Public License.

The current GPAC release (0.4.5) already covers a very large part of
the MPEG-4 standard, and features what can probably be seen as the
most advanced and robust 2D MPEG-4 Player available worldwide, as
well as a decent 3D MPEG-4/VRML player.

%package -n libgpac%{sover}
Summary:        Shared libraries for gpac
Group:          System/Libraries

%description -n libgpac%{sover}
Shared libraries for package gpac.

%package -n libgpac-devel
Summary:        Development files for gpac
Group:          Development/Languages/C and C++
Requires:       libgpac%{sover} = %{version}
# old name
Provides:       gpac-devel = %{version}
Obsoletes:      gpac-devel < %{version}

%description -n libgpac-devel
Development files for gpac.

%prep
%autosetup -p1

%build
# configure the beast
./configure \
   --prefix="%{_prefix}" \
   --libdir="%{_lib}" \
   --mandir="%{_mandir}" \
   --use-a52=system \
   --extra-cflags="%{optflags} -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES -D_LARGEFILE_SOURCE=1 -DXP_UNIX -fPIC"

%make_build all
%make_build -C applications/generators/MPEG4
%make_build -C applications/generators/SVG
%make_build -C applications/generators/X3D

# create dev-docs
pushd share/doc
    doxygen -u
    doxygen
popd

%install
%make_install

# header files
make install-lib \
    DESTDIR=%{buildroot}

# generated sggen binaries
for i in MPEG4 SVG X3D; do
    install -m 755 applications/generators/$i/${i}Gen \
    	%{buildroot}%{_bindir}
done

# install manpages
mkdir -pv %{buildroot}%{_mandir}/man1
install -m0644 share/doc/man/* -t %{buildroot}%{_mandir}/man1

# install html documentation
mkdir -pv %{buildroot}%{_defaultdocdir}/libgpac-devel
cp -a share/doc/html-libgpac %{buildroot}%{_defaultdocdir}/libgpac-devel/

# fix categories
%suse_update_desktop_file -r %{name} 'AudioVideo;Player;'

# static lib
rm -rf %{buildroot}%{_libdir}/*.a

# Windows includes
rm -rf %{buildroot}%{_includedir}/win32 %{buildroot}%{_includedir}/wince

%fdupes %{buildroot}

%post -n libgpac%{sover} -p /sbin/ldconfig

%postun -n libgpac%{sover} -p /sbin/ldconfig

%files
%doc Changelog README.md
%license COPYING
%{_bindir}/MP4Box
%{_bindir}/MPEG4Gen
%{_bindir}/X3DGen
%{_bindir}/SVGGen
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_libdir}/%{name}
%{_mandir}/man1/gpac.1%{?ext_man}
%{_mandir}/man1/gpac-filters.1%{?ext_man}
%{_mandir}/man1/mp4box.1%{?ext_man}

%files -n libgpac%{sover}
%{_libdir}/libgpac.so.%{sover}
%{_libdir}/libgpac.so.%{sover}.*

%files -n libgpac-devel
%doc share/doc/CODING_STYLE share/doc/ipmpx_syntax.bt
%doc share/doc/html-libgpac
%{_includedir}/%{name}/
%{_libdir}/libgpac.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
