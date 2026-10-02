# norootforbuild

%define _firmlib /lib/firmware

Summary:	Legacy Firmware for Broadcom bcm43xx series based PCI/PCMCIA cards
Name:		b43legacy-firmware
Version:	3.130.20.0
Release:	2
License: SUSE-NonFree
Group:		Hardware/Wifi
URL:		http://www.linuxwireless.org/en/users/Drivers/b43#devicefirmware
Source0:	wl_apsta-3.130.20.0.o
Source1:	%{name}.rpmlintrc
Source100:	%{name}.changes
BuildRoot:	%{_tmppath}/%{name}-%{version}-build
BuildArch:	noarch
Requires:	b43-fwcutter
Buildrequires:	b43-fwcutter

%description
This package provides firmware required by the b43legacy WiFi Linux driver

%prep
# nothing to do

%build
# nothing to do

%install
mkdir -p "${RPM_BUILD_ROOT}"%{_firmlib}/broadcom-wl-firmwares

install -m 0644 %{SOURCE0} $RPM_BUILD_ROOT%{_firmlib}/broadcom-wl-firmwares

%post

echo "Cutting firmware"

pushd %{_firmlib}/broadcom-wl-firmwares
/usr/bin/b43-fwcutter  -w /lib/firmware wl_apsta-3.130.20.0.o || echo "Cutting of firmware failed"
popd

echo "Firmware installed"

test -f /.buildenv && exit 0
driver_active()
{
        for i in /sys/class/net/*/device/driver ; do
                test -e $i || continue
                DRV=$(basename `readlink $i`)
                test "$DRV" = "$1" && return 0
        done
        return 1
}
driver_loaded()
{
        lsmod | grep -q "$1"
}
if ! driver_active b43legacy ; then
        if driver_loaded b43legacy; then
                echo "Reloading module b43legacy"
                modprobe -r b43legacy
                modprobe b43legacy
        fi
fi
exit 0

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%dir %{_firmlib}/broadcom-wl-firmwares
%{_firmlib}/broadcom-wl-firmwares/wl_apsta-3.130.20.0.o

%changelog
