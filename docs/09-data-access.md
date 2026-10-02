# Anonymous data access: URLs that work without an account

## PMBS (Packman Build Service, an OBS instance)
- Package list: `https://pmbs.links2linux.de/public/source/Essentials`
- Project meta / prjconf: `.../public/source/Essentials/_meta`, `.../public/source/Essentials/_config`
- Package file list (raw): `.../public/source/Essentials/<pkg>`; expanded through the link: `.../<pkg>?expand=1` (the `srcmd5` attribute is the expanded revision)
- File download: `.../public/source/Essentials/<pkg>/<file>?expand=1&rev=<srcmd5>`
- Web UI: `https://pmbs.links2linux.de/project/show/Essentials`
- `osc -A https://pmbs.links2linux.de` needs an account; the `public/` routes above do not. `tools/fetch_essentials.py` uses them.

## openSUSE OBS
- `https://api.opensuse.org/public/source/openSUSE:Factory/<pkg>` (file list with `srcmd5`), `.../<pkg>/<file>`
- Git mirror: `https://src.opensuse.org/pool/<pkg>` (branch `factory`)
- Tumbleweed repo: `https://download.opensuse.org/tumbleweed/repo/oss/`, snapshot id in `media.1/media`

## Mirrors of the published Packman repo
- `https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/Essentials/` (this one lags 4 h)
- `http://ftp.fau.de/packman/`, `http://ftp.halifax.rwth-aachen.de/packman/` (rsync available), `http://mirror.karneval.cz/pub/linux/packman/`
- Sub-directories: `x86_64 i586 aarch64 armv7hl noarch src repodata`, `packman-essentials.repo`
- `src/` holds every `.src.rpm`: the last-resort source of exact build inputs if PMBS disappears.

## Community
- Mailing list archive: `https://lists.links2linux.de/pipermail/packman/`
- Forum thread: `https://forums.opensuse.org/t/packman-discontinued-from-jan-1st-2027-but-heres-your-chance/195731`
- Packman website/mirror list: `http://packman.links2linux.org/mirrors`
