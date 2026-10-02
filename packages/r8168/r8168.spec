#
# spec file for package r8168
#
# Copyright (c) 2019 Packman Team <packman@links2linux.de>
# Copyright (c) 2017 SUSE LINUX Products GmbH, Nuernberg, Germany.
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

#!BuildIgnore: enough-build-resources
Name:           r8168
Version:        8.053.00
Release:        0
Summary:        Device driver for RealTek Gigabit Ethernet controllers
License:        GPL-2.0-or-later
Group:          System/Kernel
URL:            https://github.com/mtorromeo/r8168
Source0:        https://github.com/mtorromeo/r8168/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz
Source1:        preamble
Source2:        Module.supported
Source3:        https://github.com/mtorromeo/r8168/releases/download/%{version}/%{name}-%{version}.tar.gz.asc
Source4:        r8168.keyring
Patch0:         r8168-kernel_version.patch
Patch1:         r8168-configuration.patch
Patch2:         r8168-support-linux-5.19.patch
Patch3:         r8168-support-ethtool_keee.patch
Patch4:         r8168-support-dev0x8136.patch
Patch5:         r8168-support-linux-L15.5.patch
BuildRequires:  kernel-source
BuildRequires:  kernel-syms
BuildRequires:  libelf-devel
BuildRequires:  module-init-tools
BuildRequires:  %kernel_module_package_buildreqs
Requires:       r8168-kmp
ExclusiveArch:  %{ix86} x86_64
%kernel_module_package -p preamble

%description
This is the Linux device driver released for RealTek RTL8168B/8111B,
RTL8168C/8111C, RTL8168CP/8111CP, RTL8168D/8111D, RTL8168DP/8111DP,
and RTL8168E/8111E Gigabit Ethernet controllers with PCI-Express interface.

%package blacklist-r8169
Summary:        To favour r8168 blacklist the r8169 device driver
Group:          Hardware/Wifi
##BuildArch:      noarch
Requires:       %{name}-kmp = %{version}

%description blacklist-r8169
On many Realtek Ethernet controllers the old device driver r8169 does
not work reliably.  To solve this the r8169 kernel module has to be
blacklisted to enable the system to load the new device driver r8168.

%prep
version=$(readlink /usr/src/linux | sed -r 's/linux-//;s/-.*//;s/\./,/g')
[[ "$version" =~ [0-9]+,[0-9]+,[0-9]+ ]] || \
version=$(uname -r|sed -r 's/-.*//;s/\./,/g')
%setup -q
%patch -P 0 -b .p0
%patch -P 1 -b .p1
%patch -P 2 -p1 -b .p2
%patch -P 4 -p1 -b .p4
if test -e /usr/src/linux/include/linux/ethtool.h
then
    argc=$(sed -rn '/\*get_ringparam/,/;$/p' /usr/src/linux/include/linux/ethtool.h | wc -l)
    if test -n "$argc" -a "$argc" -eq 4
    then
%patch -P 5 -b .p5
    fi
    argc=$(sed -rn '/ethtool_keee/p' /usr/src/linux/include/linux/ethtool.h | wc -l)
    if test -n "$argc" -a "$argc" -eq 3
    then
%patch -P 3 -p1 -b .p3
	sed -ri "/KERNEL_VERSION/{s/\(6,9,0\)/(${version})/}" src/r8168_n.c
    fi
fi
if test -e /usr/src/linux/include/net/gso.h
then
    sed -ri "/KERNEL_VERSION/{s/\(6,4,10\)/(${version})/}" src/r8168_n.c
fi
cp %{S:1} .
cp %{S:2} .

%build
#
# SUSE kernel does include some patches/commits which do not increase
# the kernel's version, there we test here if the linux/pci-acpi.h exits
#
if test -e /usr/src/linux/include/linux/pci-aspm.h
then
    sed -ri '/#define HAS_PCI_ASPM_H/{ s/@ASPM@/1/ }' src/r8168_n.c
else
    sed -ri '/#define HAS_PCI_ASPM_H/{ s/@ASPM@/0/ }' src/r8168_n.c
fi
ln -sf $(type -p kmod) modinfo
mkdir obj
for flavor in %{flavors_to_build}
do
    rm   -rf obj/$flavor
    cp   -rp src obj/$flavor
    make V=1 -C %{kernel_source $flavor} M=$PWD/obj/$flavor modules
    ./modinfo -F alias $(find $PWD/obj/$flavor/ -name '%{name}.ko')
done

%install
export INSTALL_MOD_PATH=%{buildroot}
export INSTALL_MOD_DIR=updates
for flavor in %{flavors_to_build}
do
    make -C %{kernel_source $flavor} M=$PWD/obj/$flavor modules_install
done
mkdir -p %{buildroot}%{_sysconfdir}/modprobe.d/
cat > %{buildroot}%{_sysconfdir}/modprobe.d/50-blacklist-r8169.conf<<-'EOF'
	# On many Realtek Ethernet controllers the old device driver r8169 does
	# not work reliably.  To solve this the r8169 kernel module has to be
	# blacklisted to enable the system to load the new device driver r8168.
	blacklist r8169
	EOF

%files blacklist-r8169
%config %{_sysconfdir}/modprobe.d/50-blacklist-r8169.conf

%changelog
