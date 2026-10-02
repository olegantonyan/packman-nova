#
# spec file for package faac
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
# Copyright (c) 2013 Marguerite Su <marguerite@opensuse.org>
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

%define so_name libfaac0

Name:           faac
Version:        1.50
Release:        0
Summary:        Frontend for encoding MPEG2/4 AAC
# Original Code was free to use but restricted. Modifications are LGPL-2.1+
License:        SUSE-Freeware and LGPL-2.1+
Url:            https://github.com/knik0/faac
Source0:        %name-%version.tar
Source99:       baselibs.conf
BuildRequires:  meson
BuildRequires:  gcc-c++
Requires:       %so_name = %version-%release

%description
FAAC is a LC, MAIN and LTP profile, MPEG2 and MPEG-4 AAC encoder, completely
written from scratch.

%package -n %so_name
Summary:        Shared library part of faac

%description -n %so_name
FAAC is a LC, MAIN and LTP profile, MPEG2 and MPEG-4 AAC encoder, completely
written from scratch.
Shared library part of faac

%package devel
Summary:        Header files and static library for the faac library
Requires:       %so_name = %version-%release
Provides:       libfaac-devel = %version-%release

%description devel
FAAC is a LC, MAIN and LTP profile, MPEG2 and MPEG-4 AAC encoder, completely
written from scratch.
Header files and static library for the faac library

%prep
%autosetup -p1

%build
%meson \
	-Ddefault_library=shared \
	-Dfrontend=true \
	-Dfloating-point="double" \
	%nil
%meson_build

%install
%meson_install

%ldconfig_scriptlets -n %so_name

%files
%doc AUTHORS ChangeLog README
%license COPYING
%_bindir/*
%_mandir/man1/faac.1%{ext_man}

%files -n %so_name
%_libdir/*.so.*

%files devel
%_libdir/*.so
%_libdir/pkgconfig/*.pc
%_includedir/*

%changelog
