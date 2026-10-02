#
# spec file for package rtl8761b-firmware
#
# Copyright (c) 2020 Packman team: http://packman.links2linux.org/
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


Name:           rtl8761b-firmware
Version:        20200610
Release:        0
Summary:        Firmware for RTL8761B-based BT 5.0 dongles
License:        SUSE-Firmware
URL:            https://www.xmpow.com/pages/download
Source0:        https://mpow.s3-us-west-1.amazonaws.com/mpow_MPBH456AB_driver+for+Linux.tgz
# for directory ownership purposes
BuildRequires:  kernel-firmware
BuildArch:      noarch

%description
Contains firmware for RTL8761B-based BT 5.0 dongles such as MPOW BH456A,
EDIMAX BT-8500 or Hommie BT-501.

%prep
%setup -q -n %{version}_LINUX_BT_DRIVER

%build
# nothing to do here

%install
mkdir -pv %{buildroot}/lib/firmware/rtl_bt
install -m0644 rtkbt-firmware/lib/firmware/rtlbt/rtl8761b_config %{buildroot}/lib/firmware/rtl_bt/rtl8761b_config.bin
install -m0644 rtkbt-firmware/lib/firmware/rtlbt/rtl8761b_fw %{buildroot}/lib/firmware/rtl_bt/rtl8761b_fw.bin

%files
/lib/firmware/rtl_bt/rtl8761b_config.bin
/lib/firmware/rtl_bt/rtl8761b_fw.bin

%changelog
