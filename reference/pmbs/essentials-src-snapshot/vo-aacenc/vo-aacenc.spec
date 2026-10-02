Name:           vo-aacenc
Version:        0.1.3
%define so_nr   0
Release:        0
License:        Apache-2.0
Summary:        VisualOn AAC encoder library
Url:            http://opencore-amr.sourceforge.net/
Group:          System/Libraries
Source0:        http://downloads.sourceforge.net/project/opencore-amr/%{name}/%{name}-%{version}.tar.gz
Source1:        baselibs.conf
BuildRequires:  pkg-config
BuildRoot:      %_tmppath/%name-%version-build

%description
This library contains an encoder implementation of the Advanced
Audio Coding (AAC) audio codec. The library is based on a codec
implementation by VisualOn as part of the Stagefright framework
from the Google Android project.

%package -n lib%{name}%{so_nr}
Summary:        VisualOn AAC encoder library
Group:          System/Libraries

%description -n lib%{name}%{so_nr}
This library contains an encoder implementation of the Advanced
Audio Coding (AAC) audio codec. The library is based on a codec
implementation by VisualOn as part of the Stagefright framework
from the Google Android project.

%package -n lib%{name}-devel
Summary:        Development files for %{name}
Group:          Development/Libraries/C and C++
Requires:       lib%{name}%{so_nr} = %{version}

%description -n lib%{name}-devel
This package contains libraries and header files for
developing applications that use %{name}.

%prep
%setup -q

%build
%configure --disable-silent-rules --disable-static
make %{?_smp_mflags}

%install
make install DESTDIR=%{?buildroot}
rm %{buildroot}%{_libdir}/lib%{name}.la

%post   -n lib%{name}%{so_nr} -p /sbin/ldconfig
%postun -n lib%{name}%{so_nr} -p /sbin/ldconfig

%files -n lib%{name}%{so_nr}
%defattr(0644,root,root,0755)
%doc COPYING README NOTICE
%{_libdir}/lib%{name}.so.%{so_nr}*

%files -n lib%{name}-devel
%defattr(0644,root,root,0755)
%{_includedir}/%{name}
%{_libdir}/lib%{name}.so
%{_libdir}/pkgconfig/%{name}.pc

%changelog
