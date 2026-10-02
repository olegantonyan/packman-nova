# How Packman builds and ships today

```
api.opensuse.org (openSUSE OBS)
   | remote project "openSUSE.org" on PMBS -> https://api.opensuse.org/public   (reference/pmbs/openSUSE.org._meta.xml)
   v
PMBS  https://pmbs.links2linux.de   (stock Open Build Service, webui + API)
   projects: Essentials -> Multimedia -> (Extra, Games) ; KMP ; SLE15 ; build-compare
   repository openSUSE_Tumbleweed:
       path build-compare/bc  +  openSUSE.org:openSUSE:Tumbleweed/standard
       arch x86_64, i586, aarch64, armv7l
   prjconf (Essentials/_config) sets BUILD_ORIG and %_with_* macros   -> docs/04
   v
publish -> repo server links2linux.de (createrepo + detached GPG signature of repomd.xml, rsync export)
   v
mirrors: ftp.gwdg.de (4h), ftp.fau.de (1h), ftp.halifax.rwth-aachen.de (1h), mirror.karneval.cz (1h), mirrors.aliyun.com (24h)
   layout: suse/openSUSE_Tumbleweed/{Essentials,Multimedia,Extra,Games}/{x86_64,i586,aarch64,armv7hl,noarch,src,repodata}
   plus a merged suse/openSUSE_Tumbleweed/repodata (the classic single "packman" repo)
```

## Key properties
- PMBS is OBS. Everything OBS does automatically is what a replacement must re-implement: link tracking to Factory, rebuild on dependency change, clean chroot builds per arch, build-compare (skip publish when binaries are identical), publishing, signing.
- Two package kinds:
  1. `_link` to an openSUSE OBS package (Factory, Slowroll, Leap, SLFO, multimedia:*). Sources are Factory's, unmodified; the codec switches come from prjconf. `cicount="add"` makes the Packman release counter extend Factory's.
  2. Native packages with own spec + tarball. Tarballs fetched either by hand, `download_files` (from `Source:` URLs), or `tar_scm` from git (x265, libx264).
- Repositories per project inherit path and prjconf: Multimedia builds against Essentials' output and with Essentials' macros (`reference/pmbs/Multimedia._config` adds only a few Prefer lines and app macros).
- Release string: `%{suse_version}.<CI_CNT>.pm.<B_CNT>` (e.g. `1699.6.pm.18`). `1699` is Tumbleweed's `suse_version`. Purpose: always outrank the Factory build of the same version so `zypper dup --allow-vendor-change` prefers Packman.
- Vendor string `http://packman.links2linux.de`, packager `packman@links2linux.de`, macro `%packman_bs 1` available to specs.
- Debuginfo enabled. `build-compare` is a pre-fetched noarch rpm in its own project so PMBS does not have to build it.
- Special repositories: `Factory` repo builds only `A_KMP` (aggregate of kernel modules from project KMP against Kernel:stable); `SLE_15` builds only an aggregate of prebuilt SLE15 packages; Slowroll i586 builds a whitelist.
- Helper packages that exist only to fix solver behaviour: `ffmpeg-mini` (empty rpms named `ffmpeg-N-mini-devel/libs` so the solver never picks Factory's mini flavor), `A_tw-cmake`, `A_tw-python-Cython`, `A_tw-python-docutils` (frozen copies to unblock builds), `preinstallimage-base`.
- Signing happens on the repo server with shell scripts, not with OBS's signd (asked on the list 2026-09-01, unanswered).

## Client side
`packman-essentials.repo` (reference/repo-metadata/) points at `packman.inode.at`, `gpgcheck=1`, key from `repodata/repomd.xml.key`. The `rpmkey-packman` package installs the public keys under `/usr/lib/rpm/gnupg/` and a `.repo` file.
