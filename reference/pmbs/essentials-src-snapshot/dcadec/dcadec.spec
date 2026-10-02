#
# spec file for package dcadec
#
# Copyright (c) 2016 Packman Team <packman@links2linux.de>
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.links2linux.org/
#

%define libmaj  0
Name:           dcadec
Version:        0.2.0
Release:        0
Summary:        DTS Coherent Acoustics decoder with support for HD extensions
License:        LGPL-2.1
Group:          Productivity/Multimedia/Video/Editors and Convertors
Url:            https://github.com/foo86/dcadec
Source0:        https://github.com/foo86/dcadec/archive/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildRequires:  make
BuildRequires:  pkg-config
BuildRequires:  xz
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Requires:       lib%{name}%{libmaj} = %{version}

%description
Free DTS Coherent Acoustics decoder with support for HD extensions.

Supported features:
    Decoding of standard DTS core streams with up to 5.1 channels
    Decoding of DTS-ES streams with discrete back channel
    Decoding of High Resolution streams with up to 7.1 channels and extended bitrate
    Decoding of 96/24 core streams
    Lossless decoding of Master Audio streams with up to 7.1 channels, 192 kHz
    Downmixing to stereo and 5.1 using embedded coefficients

Features not implemented:
    Decoding of DTS Express streams
    Applying dynamic range compression and dialog normalization

%package     -n lib%{name}%{libmaj}
Summary:        Shared library for dcadec
Group:          System/Libraries

%description -n lib%{name}%{libmaj}
DTS Coherent Acoustics decoder with support for HD extensions

%package     -n lib%{name}-devel
Summary:        Header files and static library for lib%{name}
Group:          Development/Libraries/C and C++
Requires:       lib%{name}%{libmaj} = %{version}

%description -n lib%{name}-devel
DTS Coherent Acoustics decoder with support for HD extensions

%prep
%setup -q

%build
export CFLAGS="-fPIC %{optflags}"
make CONFIG_SHARED=1 %{?_smp_mflags}

%install
make CONFIG_SHARED=1 PREFIX=%{_prefix} LIBDIR=%{_libdir} DESTDIR=%{buildroot} install %{?_smp_mflags}
mv -v %{buildroot}%{_bindir}/%{name} %{buildroot}%{_bindir}/%{name}-%{version}

%post   -n lib%{name}%{libmaj} -p /sbin/ldconfig
%postun -n lib%{name}%{libmaj} -p /sbin/ldconfig

%files
%defattr(-,root,root)
%doc COPYING.LGPLv2.1 README.md
%{_bindir}/*

%files -n lib%{name}%{libmaj}
%defattr(-,root,root)
%doc COPYING.LGPLv2.1 README.md
%{_libdir}/lib%{name}.so.0
%{_libdir}/lib%{name}.so.0.1.0

%files -n lib%{name}-devel
%defattr(-,root,root)
%doc COPYING.LGPLv2.1 README.md
%{_includedir}/lib%{name}/
%{_libdir}/lib%{name}.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
