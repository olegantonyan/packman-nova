# packman-nova

Independent successor to the Packman `Essentials` repository for openSUSE Tumbleweed.
Packman shuts down on 2026-12-31 unless a successor appears. This project rebuilds the
same packages from the same sources on our own infrastructure (target: GitHub Actions
builders, Cloudflare R2 hosting, our own signing key).

Status (2026-09-29): milestones 1 to 4 done. The `packman-nova` CLI (milestone 4) syncs 38 source packages
(Factory links + vendored natives), builds them with pbuild in a rootless podman container using Factory's
prjconf plus the Packman macro set, and publishes a signed rpm-md repo with a static index page (localfs now,
Cloudflare R2 prepared). Next: GitHub Actions + R2 hosting (milestone 5). See `docs/07-replacement-plan.md`
for milestones, `docs/12-tool.md` for the tool and `docs/11-build-journal.md` for what was learned building.

## Quick start

```
bundle install
cp .env.example .env && chmod 600 .env     # PACKMAN_NOVA_WORKDIR, GPG_PRIVATE_KEY_BASE64 (see docs/12-tool.md "Signing key")
bundle exec exe/packman-nova image build   # builder image
bundle exec exe/packman-nova check         # doctor
bundle exec exe/packman-nova sync          # sources -> <workdir>/project
bundle exec exe/packman-nova build         # pbuild in the container (a full cold build takes hours)
bundle exec exe/packman-nova publish       # sign + createrepo into <workdir>/repo
bundle exec exe/packman-nova site          # re-render index.html from the repo state
sudo zypper ar -f file://<workdir>/repo/opensuse_tumbleweed/essentials/packman-nova.repo
```

`bundle exec exe/packman-nova run` does sync, build and publish in one go (CI entry point).

## Read in this order

| doc | what it answers |
|---|---|
| `docs/01-shutdown-context.md` | why Packman ends, who ran it, what infra exists, who offered to take over |
| `docs/02-current-architecture.md` | how Packman builds and ships today: PMBS, OBS remote links, prjconf, mirrors, signing |
| `docs/03-essentials-inventory.md` | every source package in Essentials/Tumbleweed: origin, type, versions, binaries |
| `docs/04-build-config.md` | the project config macros that turn Factory sources into codec-complete builds, with spec evidence |
| `docs/05-dependency-graph.md` | build tiers inside Essentials |
| `docs/06-sync-strategy.md` | how to track Factory source changes and Tumbleweed snapshots, release numbering rules |
| `docs/07-replacement-plan.md` | proposed pipeline, decisions taken, open questions |
| `docs/08-other-projects.md` | Multimedia, Extra, Games, KMP scope if we ever go beyond Essentials |
| `docs/09-data-access.md` | URLs and API routes for anonymous access to PMBS, openSUSE OBS and mirrors |
| `docs/10-omnipackage-alignment.md` | what to reuse from Oleg's omnipackage-rs (R2 layout, GH Actions shape, signing) and where it does not fit |
| `docs/11-build-journal.md` | how the container build works, exact commands, pitfalls hit, verification results |
| `docs/12-tool-design.md` | design contract of the `packman-nova` CLI |
| `docs/12-tool.md` | CLI reference, config, workdir layout, state files, adding packages, key handling, troubleshooting |

## Reference material (raw evidence, fetched 2026-09-28)

- `reference/pmbs/` PMBS project metas, project configs, package lists.
- `reference/pmbs/essentials-src-snapshot/` every Essentials package's expanded source tree minus tarballs (specs, patches, `_link`, `_service`, changes).
- `reference/opensuse-factory/` Factory specs for ffmpeg-8, vlc, libheif and the ffmpeg codec whitelists.
- `reference/repo-metadata/` the mirror's `primary.xml.gz`, `repomd.xml`, signing key, `.repo` file, src.rpm list.
- `reference/ANALYSIS-2026-09-28-draft.md` first-pass narrative; superseded by `docs/`.

## Project layout
- `exe/packman-nova` CLI entry point; `lib/packman_nova/` the implementation (one class per file, see `docs/12-tool.md` "Code map").
- `config/packman-nova.yml` defaults with `${VAR}` from `.env` (`.env.example` lists the keys; `.env` holds the private key and is gitignored).
- `packages/<name>/package.yml` + vendored spec, patches, changes. 40 packages, 38 enabled. Tarballs are not in git; `sync` downloads them.
- `prjconf/` `factory-base.conf` (Factory `_config` fallback) + `packman-nova-macros.conf` (becomes the project `_config`).
- `container/Containerfile` builder image: Tumbleweed + obs-build (pbuild), rpm-build, createrepo_c, gpg2; patches obs-build's `/dev/fd` handling.
- No public key in git: it is derived from `GPG_PRIVATE_KEY_BASE64` (`packman-nova gpg export-public` prints it).
- `test/unit/**` unit tests (`bundle exec rake`), `test/integration/test_smoke.rb` end-to-end fdk-aac run.
- `.github/workflows/` `ci.yml` (tests) and `build-publish.yml` (draft, disabled).
- `out/`, `.cache/` results of the milestone 1-3 scripts (not for git).

## Tools
- `tools/build-in-container.sh` legacy milestone 1-3 build script, superseded by `packman-nova build`; no longer works with the current image.
- `tools/verify-ffmpeg.sh N`, `tools/verify-tier3.sh` check the Packman-specific bits in built rpms.
- `tools/fetch_essentials.py` mirrors all Essentials sources from the PMBS public API. No account needed.
- `tools/repo_inventory.py` regenerates the tables in `docs/03` from a `primary.xml(.gz)`.

## Naming

"Packman" is their name; do not reuse it for the published repo, vendor string or key. Working name: `packman-nova`. Public name undecided.
