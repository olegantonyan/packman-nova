#
# spec file for package l-smash
#
# Copyright (c) 2020 Packman Team <packman@links2linux.de>
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
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


%define sover   2
Name:           l-smash
Version:        2.14.5
Release:        0
Summary:        A simple tool for MP4
License:        ISC
Group:          System/Libraries
URL:            https://github.com/l-smash/l-smash
Source:         https://github.com/l-smash/l-smash/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
#PATCH-FIX-UPSTREAM marguerite@opensuse.org - importer.h is needed by x264_tMod
Patch1:         %{name}-install_importer.h.patch
#PATCH-FEATURE-OPENSUSE l-smash-PIE.patch build tools as PIE -- aloisio@gmx.com
Patch3:         l-smash-PIE.patch
BuildRequires:  pkgconfig
Requires:       liblsmash%{sover} = %{version}

%description
Loyal to Spec of Mpeg4 and Ad-hoc Simple Hackwork.
Yet another opensource mp4 handler™

%package -n liblsmash%{sover}
Summary:        Libraries of L-SMASH
Group:          System/Libraries

%description -n liblsmash%{sover}
Loyal to Spec of Mpeg4 and Ad-hoc Simple Hackwork.
Yet another opensource mp4 handler™

This package provides runtime libraries for L-SMASH.

%package devel
Summary:        Development headers for L-SMASH
Group:          Development/Libraries/C and C++
Requires:       %{name} = %{version}

%description devel
Loyal to Spec of Mpeg4 and Ad-hoc Simple Hackwork.
Yet another opensource mp4 handler™

This package provides development headers for L-SMASH.

%prep
%autosetup -p1

%build
./configure --prefix=%{_prefix} \
	--libdir=%{_libdir} \
	--disable-static \
	--enable-shared \
	--enable-debug \
	--extra-cflags="%{optflags}"
%make_build

%install
%make_install

%post -n liblsmash%{sover} -p /sbin/ldconfig

%postun -n liblsmash%{sover} -p /sbin/ldconfig

%files
%license LICENSE
%{_bindir}/boxdumper
%{_bindir}/muxer
%{_bindir}/remuxer
%{_bindir}/timelineeditor

%files -n liblsmash%{sover}
%{_libdir}/liblsmash.so.%{sover}

%files devel
%{_includedir}/lsmash.h
%{_includedir}/lsmash_importer.h
%{_libdir}/liblsmash.so
%{_libdir}/pkgconfig/liblsmash.pc

%changelog
