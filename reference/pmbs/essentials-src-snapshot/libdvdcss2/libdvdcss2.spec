# vim: set sw=4 ts=4 et:
#
# spec file for package libdvdcss2
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
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


Name:           libdvdcss2
Version:        1.4.0
Release:        0
Summary:        Library for accessing DVDs like block device usind deCSS if needed
License:        GPL-2.0+
Group:          System/Libraries
Url:            http://www.videolan.org/libdvdcss/
Source0:        http://download.videolan.org/pub/libdvdcss/%{version}/libdvdcss-%{version}.tar.bz2
BuildRequires:  gcc
BuildRequires:  pkgconfig
Provides:       libdvdcss = %{version}
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
libdvdcss is a simple library designed for accessing DVDs like a block device
without having to bother about the decryption.

%package -n libdvdcss-devel
Summary:        Development tools for programs which will use the libdvdcss library
Group:          Development/Libraries/C and C++
Requires:       %{name} = %{version}-%{release}
Provides:       %{name}devel = %{version}-%{release}

%description -n libdvdcss-devel
The libdvdcss-devel package includes the header files and static libraries
necessary for developing programs which will manipulate DVDs files using
the libdvdcss library.

If you are going to develop programs which will manipulate DVDs, you
should install libdvdcss-devel.

%prep
%setup -q -n libdvdcss-%{version}

%build
%configure \
    --disable-static \
    --disable-silent-rules
make %{?_smp_mflags}

%install
%make_install
find %{buildroot} -type f -name "*.la" -delete -print
rm -rf %{buildroot}%{_datadir}/doc/

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root)
%doc AUTHORS COPYING NEWS README
%{_libdir}/libdvdcss.so.*

%files -n libdvdcss-devel
%defattr(-,root,root)
%doc ChangeLog COPYING
%{_includedir}/dvdcss
%{_libdir}/libdvdcss.so
%{_libdir}/pkgconfig/libdvdcss.pc

%changelog
