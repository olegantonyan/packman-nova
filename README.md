# packman-nova

Independent rebuild of Packman `Essentials` for openSUSE Tumbleweed: same packages, same sources, our build
infrastructure and signing key. Packman shuts down on 2026-12-31 unless a successor appears.
Published at https://packman.omnipackage.org.

## Install

```
sudo zypper ar -f -p 80 https://packman.omnipackage.org/opensuse_tumbleweed/essentials/packman-nova.repo
sudo zypper --gpg-auto-import-keys ref
sudo zypper dup --from packman-nova-essentials --allow-vendor-change
```

## How it works

A GitHub Actions job (`.github/workflows/build-publish.yml`) runs every night at 01:17 UTC and normally needs no
attention:

1. **Restore.** `state pull` downloads yesterday's pbuild results and `state/` from the R2 bucket, so pbuild knows
   what is already built.
2. **Sync.** For every enabled `packages/<name>/package.yml`: `obs-link` packages take Factory's current sources
   from the OBS API; `native` packages use the spec in this repo plus tarballs from upstream (fallback: our source
   archive in the bucket). Checksums are verified. The current Factory prjconf and Tumbleweed snapshot id are recorded too.
3. **Build.** pbuild runs in the builder container and rebuilds only packages whose sources or build dependencies
   changed. An i586 pass then makes the `-32bit` packages. Release `1699.<run>.nova.1` is higher than Factory's,
   so our packages win on users' systems.
4. **Publish.** New rpms are signed, repodata is regenerated and signed, changed files are uploaded to R2, stale
   ones deleted, the Cloudflare cache purged, and the site at packman.omnipackage.org updated. New source tarballs
   are archived under `_sources/`, so a later build doesn't need Packman or a vanished upstream.
5. **Save.** `state push` uploads the updated pbuild state for the next night.

If nothing changed upstream, the night builds and publishes nothing. Users get updates with
`zypper ref && zypper dup`.

When a package fails, the job goes red. The log shows the pbuild result and the last 100 lines of that package's
build log. The previously published rpms of that package stay in the repo.

To change a package, edit `packages/<name>/` and push to `master`. CI runs the tests, and the next nightly run (or a
manual dispatch) builds and publishes it.

## Updating native packages

`obs-link` packages follow Factory by themselves. `native` packages change only when bumped, which `update` automates
for those with a `watch:` block in `package.yml` (an upstream page, git tags or a git branch):

```
bundle exec exe/packman-nova update --check                 # list packages with a newer upstream version
bundle exec exe/packman-nova update --package x265          # bump one (omit --package to bump all outdated)
bundle exec exe/packman-nova update --package faac --version 1.50   # pin an exact version
```

An update rewrites the spec `Version:`, the `package.yml` sources and checksums, and adds a `.changes` entry by
`packager` (config). Git snapshots (libx264, x265, faac, rtmpdump, ffmpeg-6) are regenerated with `git archive`, no
osc or `_service` involved. Nothing is built: review `git diff packages/`, run `build --package <name>`, then push.
A new upstream version may still need patch work.

## Build and publish

```
bundle install
cp .env.example .env && chmod 600 .env       # workdir, GPG_PRIVATE_KEY_BASE64, Cloudflare R2 keys
bundle exec exe/packman-nova image build     # builder container
bundle exec exe/packman-nova check
bundle exec exe/packman-nova run --provider s3   # sync + build + sign + publish; a cold build takes hours
```

Tests: `bundle exec rake`. CLI reference: `docs/12-tool.md`.

## Signing key

`GPG_PRIVATE_KEY_BASE64` is the ASCII-armored private key (RSA 4096, no passphrase) encoded as one base64 line.
The public key is derived from it; nothing key-related is in git.

Generate a new key straight into `.env`:
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

Rotate: generate a new key as above, update the `PACKMAN_NOVA_DOTENV` CI secret and your `.env` backup, bump
`Version` and `.changes` of `packages/packman-nova-keyring`, then `run --provider s3`. Publish re-signs every rpm
with the new key; users accept it on the next `zypper ref`.

## Layout

- `lib/`, `exe/` the `packman-nova` CLI; `config/packman-nova.yml` defaults, secrets from `.env`.
- `packages/<name>/` package manifests and vendored specs (tarballs are downloaded by `sync`, versions bumped by `update`).
- `prjconf/` Factory config fallback and the Packman macro set.
- `container/` builder image (Tumbleweed + pbuild).
- `docs/` Packman build config findings, replacement plan, CLI reference.
- `.github/workflows/` tests, and build-publish (nightly, or manual trigger).

"Packman" is their name: never reuse it for the repo, vendor string or key.
