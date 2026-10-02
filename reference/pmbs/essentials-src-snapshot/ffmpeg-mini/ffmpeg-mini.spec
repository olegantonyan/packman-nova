#
# spec file for package ffmpeg-mini
#
# Copyright (c) 2025 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           ffmpeg-mini
Version:        %suse_version
Release:        0
Summary:        %name
License:        MIT
%description
%package -n ffmpeg-5-mini-devel 
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-5-mini-devel 
%package -n ffmpeg-5-mini-libs
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-5-mini-libs
%package -n ffmpeg-6-mini-devel 
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-6-mini-devel 
%package -n ffmpeg-6-mini-libs
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-6-mini-libs
%package -n ffmpeg-7-mini-devel 
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-7-mini-devel 
%package -n ffmpeg-7-mini-libs
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-7-mini-libs
%package -n ffmpeg-8-mini-devel 
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-8-mini-devel 
%package -n ffmpeg-8-mini-libs
Summary: %name
Requires: %name = %version-%release
%description -n ffmpeg-8-mini-libs
%prep
%build
%install
mkdir -p %buildroot%_datadir%name
%files -n ffmpeg-5-mini-devel 
%dir %_datadir%name
%files -n ffmpeg-5-mini-libs
%dir %_datadir%name
%files -n ffmpeg-6-mini-devel 
%dir %_datadir%name
%files -n ffmpeg-6-mini-libs
%dir %_datadir%name
%files -n ffmpeg-7-mini-devel 
%dir %_datadir%name
%files -n ffmpeg-7-mini-libs
%dir %_datadir%name
%files -n ffmpeg-8-mini-devel 
%dir %_datadir%name
%files -n ffmpeg-8-mini-libs
%dir %_datadir%name
%changelog
