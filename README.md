# packman-nova

Full multimedia codecs for openSUSE Tumbleweed, Leap 16.0 and Leap 16.1. Website: https://packman.omnipackage.org.

openSUSE removes patent-encumbered codecs from ffmpeg, GStreamer and VLC. Packman `Essentials`
(http://packman.links2linux.org) added them back. Packman shuts down on 2026-12-31.

packman-nova is **not** a full copy of Packman Essentials. It builds only the codecs:

- full ffmpeg (every version the distro ships)
- x264, x265, libde265, fdk-aac, openapv
- libheif (HEIC images)
- codec plugins for GStreamer, VLC, xine-lib and libquicktime

No drivers, firmware, DVD or Blu-ray decryption, or command-line encoders. The sources are the same as Packman's,
but we use our own build system and signing key.

## Install

```
sudo zypper ar -f -p 80 https://packman.omnipackage.org/<distro>/essentials/packman-nova.repo
sudo zypper --gpg-auto-import-keys ref
sudo zypper dup --from packman-nova-essentials --allow-vendor-change
```

`<distro>` is `opensuse_tumbleweed`, `opensuse_leap_16.0` or `opensuse_leap_16.1`.

## How it works

A GitHub Actions workflow (`.github/workflows/build-publish.yml`) runs every night (cron 19:17 UTC; GitHub often starts
it about 6 hours late). Each distro builds in its own job, in parallel. A last job makes the website from all of them.
For each distro:

1. **Restore.** `state pull` downloads the last pbuild results and `state/` from the R2 bucket. pbuild then knows what
   is already built.
2. **Sync.** Get the sources of every enabled `packages/<name>/package.yml` for this distro:
   - `obs-link` packages: from the OBS API. Tumbleweed uses the Factory revision of the current snapshot. Leap uses
     the newest SLFO or Backports revision, like PMBS.
   - `native` packages: the spec in this repo, plus tarballs from upstream (or from our source archive in the bucket).

   All checksums are checked. The base prjconf and the distro snapshot id are saved too.
3. **Build.** pbuild runs in the builder container. It rebuilds only packages whose sources or build dependencies
   changed. On Tumbleweed, a second i586 pass makes the `-32bit` packages (Leap 16 has no 32-bit). The release
   `1699.<run>.nova.1` (Leap: `160000.` or `160100.<run>.nova.1`) is higher than the distro's, so our packages win.
4. **Publish.** Sign new rpms, make and sign repodata, upload changed files to R2, delete old ones, clear the
   Cloudflare cache. New source tarballs go to `_sources/`, so later builds do not need Packman or upstream.
5. **Save.** `state push` uploads the new pbuild state for the next night.

Then `site --provider s3` makes packman.omnipackage.org: one page, one tab per distro.

If nothing changed upstream, the run builds and publishes nothing. Users get updates with `zypper ref && zypper dup`.

If a package fails, the job fails. The log shows the pbuild result and the last 100 lines of the build log. The website
links the full build log (for an unresolvable package: what is missing). The old rpms of that package stay in the repo.

To change a package, edit `packages/<name>/` and push to `master`. CI runs the tests. The next nightly run (or a
manual run) builds and publishes it.

## Updating native packages

`obs-link` packages follow their origin by themselves. `native` packages change only when you bump them. `update` does
this for packages with a `watch:` block in `package.yml` (an upstream page, git tags or a git branch):

```
bundle exec exe/packman-nova update --check                         # list packages with a newer upstream version
bundle exec exe/packman-nova update --package x265                  # bump one (without --package: bump all)
bundle exec exe/packman-nova update --package x265 --version 4.1    # use an exact version
```

`update` changes the spec `Version:`, the sources and checksums in `package.yml`, and adds a `.changes` entry by
`packager` (config). Git snapshots (libx264, x265) are made with `git archive`; no osc or `_service`. New tarballs go
to the source archive, so CI can download them. `update` builds nothing: check `git diff packages/`, run
`build --package <name>`, then push. A new upstream version may still need new patches.

## Build and publish

```
bundle install
cp .env.example .env && chmod 600 .env       # workdir, GPG_PRIVATE_KEY_BASE64, Cloudflare R2 keys
bundle exec exe/packman-nova image build     # builder container
bundle exec exe/packman-nova check
bundle exec exe/packman-nova run --provider s3   # sync + build + sign + publish; the first build takes hours
bundle exec exe/packman-nova -d opensuse_leap_16.0 run --provider s3   # another distro (default: Tumbleweed)
```

Tests: `bundle exec rake`. CLI reference: `docs/12-tool.md`.

## Signing key

`GPG_PRIVATE_KEY_BASE64` is the ASCII-armored private key (RSA 4096, no passphrase), base64-encoded on one line.
The public key comes from it. Nothing about the key is in git.

Make a new key directly in `.env`:
```
umask 077
k=$(bundle exec exe/packman-nova -q gpg generate --name packman-nova --email you@example.org)
sed -i "s|^GPG_PRIVATE_KEY_BASE64=.*|GPG_PRIVATE_KEY_BASE64=$k|" .env
bundle exec exe/packman-nova gpg info       # key id, fingerprint, uid
```

Or encode an existing gpg key:
```
gpg --armor --export-secret-keys <fingerprint> | base64 -w0
```

To change the key: make a new key as above, update the `PACKMAN_NOVA_DOTENV` CI secret and your `.env` backup, bump
`Version` and `.changes` of `packages/packman-nova-keyring`, then `run --provider s3`. Publish signs every rpm again
with the new key. Users accept it on the next `zypper ref`.

## Layout

- `lib/`, `exe/`: the `packman-nova` CLI. `config/packman-nova.yml`: defaults. `config/distros/<id>.yml`: per distro. Secrets come from `.env`.
- `packages/<name>/`: package manifests and specs. `sync` downloads the tarballs, `update` bumps versions.
- `prjconf/`: base configs (Factory, obs-build's Leap configs) and our macros.
- `container/`: builder image (Tumbleweed + pbuild).
- `docs/`: notes on Packman's build config, the plan, the CLI reference.
- `.github/workflows/`: tests and build-publish (nightly or manual).

"Packman" is their name: never use it for the repo, vendor string or key.
