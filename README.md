# packman-nova

Independent rebuild of Packman `Essentials` for openSUSE Tumbleweed: same packages, same sources, our build
infrastructure and signing key. Packman shuts down on 2026-12-31 unless a successor appears.
Published at https://packman.omnipackage.org.

## Install

```
sudo zypper ar -f https://packman.omnipackage.org/opensuse_tumbleweed/essentials/packman-nova.repo
sudo zypper --gpg-auto-import-keys ref
sudo zypper dup --from packman-nova-essentials --allow-vendor-change
```

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
- `packages/<name>/` package manifests and vendored specs (tarballs are downloaded by `sync`).
- `prjconf/` Factory config fallback and the Packman macro set.
- `container/` builder image (Tumbleweed + pbuild).
- `docs/` findings and tool docs; `reference/` raw evidence from PMBS, OBS and mirrors; `tools/` helper scripts.
- `.github/workflows/` tests, and build-publish (nightly, or manual trigger).

"Packman" is their name: never reuse it for the repo, vendor string or key.
