#
# spec file for package rtmpdump
#
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
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


%define soname 1
Name:           rtmpdump
Version:        2.4.20251114.138fdb2
Release:        0
Summary:        RTMP Stream Dumper
License:        GPL-2.0+ and LGPL-2.1+
Url:            https://rtmpdump.mplayerhq.hu/
Source:         %name-%version.tar.xz
Source1:        baselibs.conf
Patch1:         rtmpdump-fix_u32.patch
BuildRequires:  pkgconfig
BuildRequires:  pkgconfig(gnutls)
BuildRequires:  pkgconfig(zlib)
Requires:       librtmp%{soname} = %version-%release

%description
A small dumper for media content streamed over the RTMP protocol (like BBC's
iPlayer high quality streams). Supplying an rtmp url will result in a dumped
flv file, which can be played/transcoded using ffmpeg/mplayer, etc.

%package -n librtmp%{soname}
Summary:        RTMP Stream Dumper Library
Group:          System/Libraries
License:        LGPL-2.1+

%description -n librtmp%{soname}
A small dumper for media content streamed over the RTMP protocol (like BBC's
iPlayer high quality streams). Supplying an rtmp url will result in a dumped
flv file, which can be played/transcoded using ffmpeg/mplayer, etc.

%package -n rtmpsuck
Summary:        RTMP Transparent Proxy Server
Requires:       librtmp%{soname} = %version-%release
License:        GPL-2.0+

%description -n rtmpsuck
Proxy server that dumps RTMP streams.

%package -n rtmpsrv
Summary:        RTMP Server
Requires:       librtmp%{soname} = %version-%release
License:        GPL-2.0+

%description -n rtmpsrv
Server for RTMP streams.

%package -n rtmpgw
Summary:        RTMP to HTTP Gateway
Requires:       librtmp%{soname} = %version-%release
License:        GPL-2.0+

%description -n rtmpgw
HTTP gateway: this is an HTTP server that accepts requests that consist of
rtmpdump parameters. It then connects to the specified RTMP server and returns
the retrieved data in the HTTP response.

%package -n librtmp-devel
Summary:        RTMP Stream Dumping Library
Requires:       librtmp%{soname} = %version-%release
License:        LGPL-2.1+

%description -n librtmp-devel
A small dumper for media content streamed over the RTMP protocol (like BBC's
iPlayer high quality streams). Supplying an rtmp url will result in a dumped
flv file, which can be played/transcoded using ffmpeg/mplayer, etc.

%prep
%autosetup -p0

%build
make \
	 CC="gcc"            \
	 CRYPTO="GNUTLS"     \
	 OPT="%optflags"   \
	 prefix="%_prefix" \
	 libdir="%_libdir" \
	 MANDIR="%_mandir"

make -C librtmp              \
	 CC="gcc"            \
	 CRYPTO="GNUTLS"     \
	 OPT="%optflags"   \
	 prefix="%_prefix" \
	 libdir="%_libdir" \
	 MANDIR="%_mandir" \
	 librtmp.pc

%install
install -d "%buildroot%_bindir"
find . -mindepth 1 -maxdepth 1 -type f -executable -exec install -m0755 '{}' '%buildroot%_bindir/' \;

pushd librtmp
install -d "%buildroot%_includedir/librtmp" "%buildroot%_libdir" "%buildroot%_libdir/pkgconfig"
make \
	 prefix="%buildroot%_prefix" \
	 libdir="%buildroot%_libdir" \
	 INCDIR="%buildroot%_includedir/librtmp" \
	 MANDIR="%buildroot%_mandir" \
	 install
popd #librtmp
rm %buildroot%_libdir/librtmp.a

%post   -n librtmp%{soname} -p /sbin/ldconfig

%postun -n librtmp%{soname} -p /sbin/ldconfig

%files
%doc README
%license COPYING
%_bindir/rtmpdump

%files -n librtmp%{soname}
%license librtmp/COPYING
%_libdir/librtmp.so.%{soname}

%files -n rtmpsuck
%license COPYING
%_bindir/rtmpsuck

%files -n rtmpgw
%license COPYING
%_bindir/rtmpgw

%files -n rtmpsrv
%license COPYING
%_bindir/rtmpsrv

%files -n librtmp-devel
%_includedir/librtmp
%_libdir/librtmp.so
%_libdir/pkgconfig/librtmp.pc
%_mandir/man3/librtmp.3%{ext_man}

%changelog

