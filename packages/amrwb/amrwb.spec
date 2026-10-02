#
# spec file for package amrwb
#
# Copyright (c) 2013 Marguerite Su <marguerite@opensuse.org>.
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


%define major     3
%define lib       libamrwb
%define libname   %{lib}%{major}

Name:           amrwb
Version:        11.0.0.0
Release:        0
License:        BSD-3-Clause
Summary:        Adaptive Multi-Rate - Wideband (AMR-WB) Speech Codec
Url:            http://www.penguin.cz/~utx/amr
Group:          System/Libraries
Source0:        http://ftp.penguin.cz/pub/users/utx/amr/%{name}-%{version}.tar.bz2
Source1:        http://www.3gpp.org/ftp/Specs/archive/26_series/26.204/26204-b00.zip
BuildRequires:  gcc
BuildRequires:  glibc-devel
BuildRequires:  unzip
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Summary(de):    Adaptiver Multi-Rate - Weitband (AMR-WB) Sprachcodec

%description
Adaptive Multi-Rate Wideband decoder and encoder library.
(3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%description -l de
Adaptiver Multi-Rate weitbandige decoding und encoding Bibliothek.
(3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%package -n %{libname}
Summary:        Shared library part of amrwb
Group:          System/Libraries
Provides:       %{lib} = %{version}
Obsoletes:      %{lib} < %{version}
Summary(de):    Bibliotheken zu amrwb

%description -n %{libname}
Adaptive Multi-Rate Wideband decoder and encoder library.
Shared library part (3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%description -n %{libname} -l de
Adaptiver Multi-Rate weitbandige decoding und encoding Bibliothek.
Bibliotheken (3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%package -n %{lib}-devel
Summary:        Adaptive Multi-Rate - Wideband (AMR-WB) Speech Codec Developer Package
Group:          Development/Libraries/C and C++
Requires:       %{libname} = %{version}
Obsoletes:      amrwb-devel < %{version}
Provides:       amrwb-devel = %{version}
Summary(de):    Adaptiver Multi-Rate - Weitband (AMR-WB) Sprachcodec Entwicklerpaket

%description -n %{lib}-devel
Adaptive Multi-Rate Wideband decoder and encoder library,
Developer Package. (3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%description -n %{lib}-devel -l de
Adaptiver Multi-Rate weitbandige decoding und encoding Bibliothek,
Entwicklerpaket. (3GPP TS 26.204 V10.0.0)

http://www.3gpp.org/ftp/Specs/html-info/26204.htm

%prep
%autosetup -p1

%build
cp %{SOURCE1} .
%configure
make %{?_smp_mflags}

%install
%makeinstall
rm -f %{buildroot}/%{_libdir}/*.{la,a}

%post -n %{libname} -p /sbin/ldconfig
%postun -n %{libname} -p /sbin/ldconfig

%files
%defattr (-, root, root)
%doc AUTHORS ChangeLog COPYING NEWS README TODO
%{_bindir}/*

%files -n %{libname}
%defattr(-,root,root)
%{_libdir}/*.so.%{major}*

%files -n %{lib}-devel
%defattr (-, root, root)
%{_includedir}/amrwb
%{_libdir}/*.so

%changelog
