# vim: set sw=4 ts=4 et:

%define pubring usr/lib/rpm/gnupg/pubring.gpg
%define packmanring usr/lib/rpm/gnupg/packman.gpg
%define pubkeyname packman

Name:           rpmkey-packman
Summary:        The %{pubkeyname} rpm public keys
Summary(de):    Die öffentlichen %{pubkeyname} rpm Schlüssel
License: GPL-2.0
Group:          System/Packages
URL:            http://%{pubkeyname}.links2linux.de/
Version:        1.0.0
Release:        2
Source0:        packman.repo
# please generate a new .gpg fle any time a new key is added with
# cat packman-*.asc >> keys.asc
# gpg --dearmor -o packman.gpg keys.asc
Source1:        packman.gpg
Source2:        packman-signing.asc
# old key used until approx. end April 2014, unusabale due to DSA only
# can probably be removed later in 2014
Source3:        packman-signing-alt.asc
# new key 2014-05-06, 2048bit RSA / 2048bit RSA, 
# valid until 2017-05-05 for now (can be extended)
Source4:        packman-signing-alt-20140506.asc
Source99:       rpmkey-packman-rpmlintrc
Vendor:         Packman
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
PreReq:         sh-utils gpg fileutils mktemp
Requires:       gpg

%description
The %{pubkeyname} rpm public keys of the packman
packagers and buildserver.

%description -l de
Die öffentlichen %{pubkeyname} rpm Schlüssel der
Packman Packetierer und des Buildservers.

%prep

%setup -c -T a1

%build
%install
%{__mkdir_p} %{buildroot}/usr/lib/rpm/gnupg
%{__install} -m 644 %{SOURCE2} %{buildroot}/usr/lib/rpm/gnupg/
%{__install} -m 644 %{SOURCE3} %{buildroot}/usr/lib/rpm/gnupg/
%{__install} -m 644 %{SOURCE4} %{buildroot}/usr/lib/rpm/gnupg/

%{__mkdir_p} %{buildroot}/etc/yum.repos.d
echo -ne "gpgkey=file://Sr/lib/rpm/gnupg/packman-signing.asc
	file://Sr/lib/rpm/gnupg/packman-signing-alt.asc
	file://Sr/lib/rpm/gnupg/packman-signing-alt-20140506.asc
" >> %{SOURCE0}
%{__install} -m 0644 %{SOURCE0} %{buildroot}/etc/yum.repos.d/packman.repo

install %{SOURCE1} $RPM_BUILD_ROOT/%{packmanring}
install -m 755 %{SOURCE1} $RPM_BUILD_ROOT/usr/lib/rpm/gnupg
touch $RPM_BUILD_ROOT/%{pubring}
touch $RPM_BUILD_ROOT/%{pubring}~

%files
%defattr(-, root, root)
%dir /etc/yum.repos.d
%config(noreplace) /etc/yum.repos.d/*
/usr/lib/rpm/gnupg/%{pubkeyname}*.asc
%attr(755,root,root) %dir /usr/lib/rpm/gnupg
%config /%{packmanring}
%ghost /%{pubring}
%ghost /%{pubring}~

%post
if [ ! -f %{pubring} ]; then
    touch %{pubring}
fi
echo -n "importing Packman build key to rpm keyring... "
TF=`mktemp /tmp/gpg.XXXXXX`
if [ -z "$TF" ]; then
  echo "suse-build-key::post: cannot make temporary file. Fatal error."
  exit 20
fi
if [ -z "$HOME" ]; then
  HOME=/root
  export HOME
fi
mkdir -vp "$HOME"
gpg -q --batch --no-options < /dev/null > /dev/null 2>&1 || true
# no kidding... gpg won't initialize correctly without being called twice.
gpg < /dev/null > /dev/null 2>&1 || true
gpg < /dev/null > /dev/null 2>&1 || true
gpg -q --batch --no-options --no-default-keyring --no-permission-warning \
         --keyring %{packmanring}    --export -a > $TF 
a="$?"
gpg -q --batch --no-options --no-default-keyring --no-permission-warning \
         --keyring %{pubring}   --import < $TF
b="$?"
rm -f "$TF"
if [ "$a" = 0 -a "$b" = 0 ]; then
    echo "done."
else
    echo "importing the key from the file %{packmanring}"
    echo "returned an error. This should not happen. It may not be possible"
    echo "to properly verify the authenticity of rpm packages from Packman sources."
    echo "The keyring containing the Packman rpm package signing keys can be found"
    echo "into /usr/lib/rpm/gnupg folder."
    exit -1
fi
### import suse package build key to roots gpg keyring
if test -f root/.gnupg/pubring.gpg ; then
   chroot . usr/bin/gpg --export --armor --no-default-keyring \
                   --keyring %{packmanring} packman@links2linux.de \
        | chroot . usr/bin/gpg --import || true
   if ! chroot . usr/bin/gpg --list-keys packman@links2linux.de >/dev/null 2>&1 ; then
      echo "gpg import for packman@links2linux.de failed, please import manually" >&2
   fi
else
   cp %{packmanring} root/.gnupg/pubring.gpg
fi
chmod 600 root/.gnupg/pubring.gpg

%changelog
