# vim: set ts=4 sw=4 et:
#
# spec file for package broadcom-wl
#
# Copyright (c) 2017-2026 SUSE LLC and contributors
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
# norootforbuild
# needssslcertforbuild

#!BuildIgnore: enough-build-resources
%define underversion 6_30_223_271
%ifarch x86_64
%define driverarch _64
%else
%define driverarch %{nil}
%endif
Name:           broadcom-wl
Version:        6.30.223.271
Release:        0
Summary:        Wireless driver for Broadcom 43xx series of chips
License:        SUSE-NonFree
Group:          System/Kernel
Url:            https://www.broadcom.com/site-search?filters[pages][content_type][type]=and&filters[pages][content_type][values][]=Downloads&page=1&per_page=10&q=802.11%20linux%20sta%20wireless%20driver
Source0:        hybrid-v35%{driverarch}-nodebug-pcoem-%{underversion}.tar.gz
Source1:        README.SUSE
Source2:        broadcom-wl-blacklist
Patch0:         broadcom-sta-6.30.223.141-eth-to-wlan.patch
Patch1:         broadcom-sta-6.30.223.141-gcc.patch
Patch2:         broadcom-sta-6.30.223.141-makefile.patch
Patch3:         broadcom-sta-6.30.223.248-r3-Wno-date-time.patch
Patch4:         broadcom-sta-6.30.223.271-r1-linux-3.18.patch
Patch5:         broadcom-sta-6.30.223.271-r2-linux-4.3-v2.patch
Patch6:         broadcom-sta-6.30.223.271-r4-linux-4.7.patch
Patch7:         broadcom-sta-6.30.223.271-r4-linux-4.8.patch
Patch8:         isprint.patch
Patch9:         broadcom-sta-6.30.223.271-Fix-fall-through-warnings.patch
Patch10:        broadcom-sta-6.30.223.271-Fix-mac-address-setting.patch
Patch11:        broadcom-wl.linux-4.11.patch
Patch12:        broadcom-wl.linux-4.12.patch
Patch14:        broadcom-wl.linux-4.14.patch
Patch15:        broadcom-wl.linux-4.15.patch
Patch16:        broadcom-wl.linux-5.1.patch
Patch17:        broadcom-wl.linux-5.6.patch
Patch18:        broadcom-wl.linux-5.9.patch
Patch19:        broadcom-wl.linux-5.17.patch
Patch20:        broadcom-wl.linux-5.18.patch
Patch21:        broadcom-wl.linux-6.0.patch
Patch22:        broadcom-wl.linux-6.1.patch
Patch23:        broadcom-wl.linux-6.5.patch
Patch24:        broadcom-wl.linux-6.10_fix_empty_body_in_if_warning.patch
Patch25:        broadcom-sta-6.30.223.271-wpa_supplicant-2.11_add_max_scan_ie_len.patch
Patch26:        broadcom-wl.linux-6.12.patch
Patch27:        broadcom-wl.linux-6.13.patch
Patch28:        broadcom-wl.linux-6.14.patch
Patch29:        broadcom-wl.linux-6.15.patch
Patch30:        broadcom-wl.linux-6.16.patch
Patch31:        broadcom-wl.linux-6.17.patch
Patch32:        broadcom-wl.linux-7.1.patch
Patch33:        leap161.patch
Patch34:        broadcom-wl.linux-7.2.patch

%if %{defined kernel_module_package_buildreqs}
BuildRequires:  %{kernel_module_package_buildreqs}
%endif

%if 0%{?sle_version} >= 150400
BuildRequires:  kernel-syms-rt
%endif

%if 0%{?suse_version} > 1500
BuildRequires:  suse-module-tools-scriptlets
%endif

%ifarch x86_64
%if 0%{?suse_version} >= 1210
BuildRequires: libelf-devel
%endif
%if 0%{?suse_version} > 160099
%define kmp_longterm 1
%endif
%endif
%if 0%{?kmp_longterm}
BuildRequires:  kernel-syms-longterm
%endif
Requires:       broadcom-wl-kmp
Provides:       wl-kmod-common = %{version}
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
ExclusiveArch:  %{ix86} x86_64
%if %{defined kernel_module_package}
%kernel_module_package -n broadcom-wl -x debug -x trace -c %_sourcedir/_projectcert.crt -p %_sourcedir/preamble
%endif

%description
These packages contain Broadcom's IEEE 802.11a/b/g/n hybrid Linux®
device driver for use with Broadcom's BCM4311-, BCM4312-, BCM4321-,
and BCM4322-based hardware.

%package KMP
Summary:        Wireless driver for Broadcom 43xx series of chips
Group:          System/Kernel

%description KMP
These packages contain Broadcom's IEEE 802.11a/b/g/n hybrid Linux®
device driver for use with Broadcom's BCM4311-, BCM4312-, BCM4321-,
and BCM4322-based hardware.

%prep
%autosetup -c hybrid-v35%{driverarch}-nodebug-pcoem-%{underversion} -N

%autopatch -p1 -M 32
%if 0%{?suse_version} == 1610 && 0%{?is_opensuse}
%autopatch -p1 33
%endif
%autopatch -p1 -m 34 -M 34

%build
sed -i 's/\r$//' lib/LICENSE.txt

set -- *
mkdir source
mv "$@" source/
mkdir obj

export EXTRA_CFLAGS='-DVERSION=\"%{version}\"'
for flavor in %{flavors_to_build}; do
    rm -rf obj/$flavor
    cp -r source obj/$flavor
    make -C %{_prefix}/src/linux-obj/%{_target_cpu}/$flavor modules \
       M=$PWD/obj/$flavor V=1
done

%install
# blacklist
mkdir -p %{buildroot}%{_sysconfdir}/modprobe.d/
mkdir -p %{buildroot}%{_docdir}/%{name}/
install -p -m0644 %{SOURCE2} %{buildroot}/%{_sysconfdir}/modprobe.d/
install -p -m0644 %{SOURCE1} %{buildroot}%{_docdir}/%{name}/
install -p -m0644 source/lib/LICENSE.txt %{buildroot}%{_docdir}/%{name}/

mv %{buildroot}/%{_sysconfdir}/modprobe.d/broadcom-wl-blacklist %{buildroot}/%{_sysconfdir}/modprobe.d/50-broadcom-wl-blacklist.conf


# Kernel module
export INSTALL_MOD_PATH=%{buildroot}
export INSTALL_MOD_DIR=updates
export BRP_PESIGN_FILES='*.ko'
export BRP_PESIGN_COMPRESS_MODULE="xz"
for flavor in %{flavors_to_build}; do
     make -C %{_prefix}/src/linux-obj/%{_target_cpu}/$flavor modules_install \
        M=$PWD/obj/$flavor
done

%files
%defattr(-,root,root)
%doc %dir %{_docdir}/%{name}
%doc %{_docdir}/%{name}/LICENSE.txt
%doc %{_docdir}/%{name}/README.SUSE
%config(noreplace) %{_sysconfdir}/modprobe.d/50-broadcom-wl-blacklist.conf

%changelog
