# Staying in sync with Tumbleweed

## Triggers
1. **Factory source change** for a linked package. Poll `https://api.opensuse.org/public/source/openSUSE:Factory/<pkg>` and compare `srcmd5` with the last built one. Alternative: `src.opensuse.org` git, `pool/<pkg>` branch `factory`. On change, rebuild the package and its dependents (docs/05).
2. **New Tumbleweed snapshot.** Snapshot id: `https://download.opensuse.org/tumbleweed/repo/oss/media.1/media`. Any ABI bump in the build environment (glibc, libva, dav1d, libvpx, gnutls ...) requires rebuilding dependents. Cheapest correct policy at Essentials scale: rebuild everything on every snapshot, then use build-compare semantics (skip publish if the binary rpms are identical modulo release) to avoid churn. OBS does exactly this.
3. **Upstream release for native packages.** Manual bump of the spec/tarball, or `_service` re-run. Track the Packman `.changes` history in `reference/pmbs/essentials-src-snapshot` to see cadence.

## Release numbering (must replicate)
- Factory: `Release: <CI_CNT>.<B_CNT>`. Packman: `%{suse_version}.<CI_CNT>.pm.<B_CNT>`, so `ffmpeg-8-8.1.2-1699.6.pm.18` > `ffmpeg-8-8.1.2-6.1`. If ours sorts lower, `zypper dup` with vendor change allowed reverts users to the codec-less Factory build.
- Keep the same version as Factory for linked packages (it is Factory's spec anyway) and only differ in Release.
- Distinct `Vendor:` gives vendor stickiness, so users who switched once stay on our repo.
- Keep `cicount="add"` semantics: our CI_CNT should start from Factory's and add ours.

## Freezing inputs
Record per build: Factory `srcmd5`, Tumbleweed snapshot id, the macro set, the build container digest. Store it next to the published repo so any rpm is reproducible and a later agent can answer "which Factory revision is this".

## Frequency
Packman publishes several times a week; the mirror timestamps show near-daily activity. Daily cron for both triggers is enough.
