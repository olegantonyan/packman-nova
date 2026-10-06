# packman-nova tool reference

Ruby CLI that syncs package sources into a pbuild project, builds them in a rootless podman container, and publishes a signed rpm-md repository.

## Setup

```
bundle install
cp .env.example .env                               # PACKMAN_NOVA_WORKDIR, GPG_PRIVATE_KEY_BASE64, ...; chmod 600
bundle exec exe/packman-nova image build           # builder image from container/Containerfile
bundle exec exe/packman-nova check
bundle exec rake                                   # unit tests + rubocop
PACKMAN_NOVA_INTEGRATION=1 PACKMAN_NOVA_SMOKE_ROOT=/big/disk bundle exec rake integration_test
```

Host needs ruby >= 4.0 (`.ruby-version` pins 4.0.7), bundler, podman (docker untested), tar, zstd. Every rpm/gpg/createrepo/pbuild step runs inside the builder image; `gpg` runs on the host when present.

## CLI

`packman-nova [global options] <command> [command options]`. Global options go before or after the command:

| option | effect |
|---|---|
| `-c, --config FILE` | config merged over `config/packman-nova.yml` (default `./packman-nova.yml` if present) |
| `-w, --workdir DIR` | overrides `PACKMAN_NOVA_WORKDIR` |
| `--offline` | no network: caches only |
| `-v, --verbose` / `-q, --quiet` | debug output and backtraces / warnings and errors only |
| `--[no-]log-file` | write `logs/<YYYYmmdd-HHMMSS>-<command>.log` (default yes; `gpg`, `site` never do) |
| `--version`, `-h, --help` | |

Errors print `Class: message` (backtrace with `-v`) and exit 1; Ctrl-C exits 130. `sync`, `update` (not `--check`), `build`, `publish`, `clean`, `state` take the workdir lock (`.lock`, non-blocking): a second one fails with `LockError` instead of waiting.

| command | options | behaviour, exit code |
|---|---|---|
| `check` | | doctor: config, workdir writable, free disk (warn < 30 GB), runtime, image present and built from the current Containerfile, manifests valid, gpg key decodes, network (`prjconf.base_url`, `distro.snapshot_url`; skipped with `--offline`). 0 ok / 1 any fail |
| `sync` | `--check`, `--package NAME` (repeatable), `--update-checksums`, `--[no-]prjconf` | materializes `project/`. `--check` writes nothing but caches and reports drift. 1 if any package failed, else 2 for `--check` with drift, else 0 |
| `update` | `--check`, `--package NAME` (repeatable), `--version V` | native packages with a `watch:`: probe upstream, then bump every outdated one (see **update** below). `--version` (one package) sets that version even if not newer; for branch watches it is a commit. Needs the network and `packager`. 1 if any package failed, else 2 for `--check` with a newer version, else 0 |
| `build` | `--package NAME`... (pbuild `--rebuild-pkg`), `--rebuild` (all), `--single NAME`, `--[no-]sync`, `--dry-run`, `--release STR`, `--buildjobs N`, `--jobs N`, `--[no-]checks`, `--debuginfo`, `--[no-]repo-refresh` | sync (unless `--no-sync`), allocate run and release, run pbuild for x86_64, then the i586 baselibs pass, write the build record. 0 if no package is failed/unresolvable/broken, else 1; `BuildError` if pbuild itself exits non-zero without a failed package. `--dry-run` prints the podman command |
| `publish` | `--provider localfs\|s3`, `--unsigned`, `--dry-run`, `--[no-]site`, `--arch A` | sign new rpms, createrepo, sign repomd, write state/site, provider sync. `--dry-run` prints add/replace/remove/re-sign lists. `--unsigned` refused for s3 while `signing.require_signature` |
| `status` | `--json`, `--live` | per package: kind, srcmd5, last code, release, rpm count, built_at, published release. `--live` asks pbuild in the container |
| `site` | `--output DIR` | re-renders `index.html` and `packages.json` from the repo `state.json` |
| `gpg generate` | `--name N` (default `project_name`), `--email E`, `--format base64\|armor` | prints a new RSA 4096 private key (one base64 line) on stdout, instructions on the log |
| `gpg info [FILE\|-]` | | key id, fingerprint, uids of FILE or the configured key |
| `gpg convert [FILE\|-]` | `--from`, `--to base64\|armor` | |
| `gpg export-public` | | prints the public key derived from `GPG_PRIVATE_KEY_BASE64` |
| `image build` / `image info` | `--[no-]cache`, `--tag T` | builds `container/Containerfile`, records `state/image.json` |
| `clean` | `--build-root`, `--results`, `--cache`, `--all`, `--yes` | build-root through the container runtime (subuid-owned files), results = `project/_build.*` (incl. `.pbuild/_base`), cache = `cache/` |
| `state push` / `state pull` | `--allow-missing` (pull) | s3 only: `tar --zstd` of `project/_build.<reponame>.<arch>/` (x86_64 and i586) and `state/` to `<path_in_bucket>/_state/state.tar.zst`; `--allow-missing` makes a first pull on an empty bucket a warning |
| `run` | `--[no-]publish`, `--[no-]fail-on-failed-packages` (default yes), `--provider P` | sync, `build --no-sync`, publish. Exit 2 if publish failed; else 1 if any package failed to sync or build (unless `--no-fail-on-failed-packages`), even though publish succeeded; else 0. Ends with `run summary: ...` |

## Configuration

Defaults: `config/packman-nova.yml`. Layers, later wins: defaults, user file, non-empty `PACKMAN_NOVA_{WORKDIR,CONTAINER_RUNTIME,PUBLIC_URL,REPO_PATH}`, CLI flags. `${VAR}` expands from the process env, then `./.env` (process env wins); unset variables become `""`. Unknown keys and wrong types raise `ConfigError` naming the dotted key. Relative paths (`prjconf/`, `container/`) resolve against the repository root.

| key | default | notes |
|---|---|---|
| `workdir` | `${PACKMAN_NOVA_WORKDIR}` | required |
| `project_name` | `packman-nova` | |
| `packager` | `Oleg Antonyan <...>` | author of `.changes` entries written by `update` |
| `distro.{id,name,suse_version,arches,repos,snapshot_url}` | `opensuse_tumbleweed`, `openSUSE Tumbleweed`, `1699`, `[x86_64]`, TW oss, TW `media.1/media` | first arch is built; `name` is the display name |
| `distro.baselibs.{arch,repos}` | `i586`, TW i586 port oss | second pbuild pass with `--baselibs`; `arch: ""` disables it |
| `release.template` | `%{suse_version}.%{run}.nova.1` | |
| `prjconf.{base_url,base_fallback,local}` | Factory `_config`, `prjconf/factory-base.conf`, `prjconf/packman-nova-macros.conf` | |
| `sources.obs_api` | OBS public API | |
| `sources.http.{timeout_sec,retries}` | `600`, `5` | |
| `container.{runtime,image,containerfile,privileged,extra_args}` | `auto`, `localhost/packman-nova-builder:latest`, `container/Containerfile`, `true`, `[]` | `auto` = podman, then docker |
| `pbuild.{reponame,buildjobs,jobs,checks,debuginfo,repo_refresh,timeout_sec,extra_args}` | `tumbleweed`, `2`, `8`, `true`, `false`, `true`, `43200`, `[]` | `timeout_sec` bounds each pbuild pass |
| `signing.{gpg_private_key_base64,require_signature}` | `${GPG_PRIVATE_KEY_BASE64}`, `true` | the public key is always derived from the private one |
| `repository.{slug,path,public_url,publish_srpms,publish_debuginfo,provider}` | `packman-nova-essentials`, `opensuse_tumbleweed/essentials`, `${PACKMAN_NOVA_PUBLIC_URL}`, `true`, `false`, `localfs` | `slug` = zypper repo alias; empty `public_url` = `file://<localfs root>` |
| `repository.localfs.path` | `${PACKMAN_NOVA_REPO_PATH}` | empty = `<workdir>/repo` |
| `repository.s3.{bucket,path_in_bucket,endpoint,access_key_id,secret_access_key,region,force_path_style,cloudflare_zone_id,cloudflare_api_token}` | `CLOUDFLARE_*` env, `""`, `auto`, `true` | |
| `site.{title,description,source_url}` | see file; `source_url` GitHub repo | `source_url` adds a nav and footer link; `""` hides them |

Secrets masked as `***` in logs: `signing.gpg_private_key_base64`, `repository.s3.secret_access_key`, `repository.s3.cloudflare_api_token`.

## Workdir layout

```
.lock                              flock for sync/update/build/publish/clean/state
project/                           pbuild project dir
  _config                          prjconf/packman-nova-macros.conf minus Release:
  _configs/tumbleweed.conf         Factory _config (fallback prjconf/factory-base.conf)
  <pkg>/                           materialized sources (hardlinks into cache/)
  _build.tumbleweed.x86_64/<pkg>/  *.rpm, _log, _meta, _meta.success|_meta.fail, _reason
  _build.tumbleweed.x86_64/.pbuild/_base/   downloaded TW rpms + hdrmd5s; keep it, or every run rebuilds all
  _build.tumbleweed.i586/<pkg>/    baselibs pass: i586 rpms (not published) + *-32bit*.x86_64.rpm
build-root/<n>/                    one build root per builder, subuid-owned
cache/blobs/{sha256,md5}/<hex>     content-addressed sources; cache/obs/, cache/prjconf/
cache/git/<pkg>.git                bare repos of git snapshot watches (only the watched ref)
state/sync.json                    per package kind, origin, srcmd5, files; distro_snapshot, base_prjconf_md5, local_config_md5, rebuild_all_required
state/run-counter.json             last run number and release
state/builds/<run>.json            build record; state/last-build.json = newest
state/image.json                   image tag, id, Containerfile sha256
logs/<ts>-<command>.log
tmp/                               0700 staging and gpg homes, removed after use
repo/                              localfs target
repo-mirror/                       local mirror of the s3 bucket
```

Published layout (localfs root or bucket prefix): `index.html`, `packages.json`, `packman-nova.key`, `opensuse_tumbleweed/essentials/{packman-nova.repo,state.json}`, `.../x86_64/*.rpm` (x86_64 + noarch) with `repodata/{repomd.xml,repomd.xml.asc,repomd.xml.key,...}`, `.../src/*.src.rpm` with its own `repodata/`, `.../logs/<pkg>.log` (full `_log` of each currently failing package, linked from the site).

Required state keys: `PackmanNova::State::Schemas`. Build record keys: `schema run release image_id started_at finished_at arch distro_snapshot pbuild_argv pbuild_exit built codes packages`; per package `code flavor reason rpms debuginfo_rpms srpm log built_at duration_sec details`. Repo `state.json` `files` entries carry `sha256 size package source_sha256 key_id`; `packages` entries carry `log` (relative path of the published build log, or null).

## How each step decides what to do

**sync** (`Sync#call`). Prjconf: fetch `prjconf.base_url` unless offline/`--no-prjconf`, write `_configs/<pbuild.reponame>.conf` and `_config`; a changed `_config` md5 sets `rebuild_all_required`, which stays set until a build with `--rebuild` succeeds. Snapshot id from `media.1/media`. Per enabled manifest:
- obs-link: `GET <obs_api>/source/<project>/<package>?expand=1[&rev=pin]`; unchanged when srcmd5, file list and every on-disk md5 equal `sync.json`. Otherwise files not in `link.delete` are fetched with `?rev=<srcmd5>` into `cache/blobs/md5/`, assembled in `project/.<pkg>.tmp/` and renamed into place.
- native: every file in `packages/<pkg>/` except `package.yml` plus each `sources[]` entry. Remote files come from the cache, else from `urls` in order, else from the source archive `<public_url>/_sources/sha256/<sha256>`; a source without `urls` is archive-only. `path:` copies a repo file; `generated: public-key` writes the public key derived from `GPG_PRIVATE_KEY_BASE64`. sha256 must match.
- A failing package keeps its previous `sync.json` entry and project dir; the others continue. Full runs prune project dirs without an enabled manifest.

Source endpoints verified 2026-09-29: OBS serves link packages' files with `?rev=<expanded srcmd5>`. Offline sync uses cached OBS listings, blobs, the existing prjconf copy (else `base_fallback`) and the recorded snapshot. `openSUSE:Factory/fdk-aac` does not exist; Factory scmsync packages (ffmpeg-4/7/8/9) carry `_scmsync.obsinfo` and `build.specials.obscpio`, which pbuild ignores.

**build** (`Build#call`). Sync, then lock. Run number = max(`run-counter.json`, repo `state.json` run, max run in result rpm names) + 1, persisted before pbuild starts; release from `release.template`. A run that builds nothing gives its number back. pbuild itself decides what to build: a package is rebuilt when its `_meta` (source md5 + hdrmd5 of every build dependency) changes, so a new Factory srcmd5 or a changed dependency rebuilds exactly the affected tree. Failed packages are retried only when their meta changes or with `--package`/`--rebuild`. Implicit `--rebuild all` when `rebuild_all_required` and no explicit selection. Afterwards results are collected with `pbuild --result-code all` (with details) and cross-checked with the files in `_build.*/<pkg>/`. Each failed/unresolvable/broken package is logged with its details and the last 100 lines of its `_log` (the i586 log when the baselibs pass failed), so the CI console shows why.

**-32bit** (as Packman). A second pass `pbuild --arch i586 --baselibs` against the TW i586 port, same release, builds only the `onlybuild` list in `prjconf/packman-nova-macros.conf` (the packages with a `baselibs.conf`). mkbaselibs turns their i586 libraries into `*-32bit*.x86_64.rpm`; the build record keeps them under `packages.<name>.baselibs` and publish puts them into `x86_64/`. i586 rpms are not published. A package whose i586 build fails counts as failed, so its previously published files are kept.

**publish** (`Publish#call`). Lock, decode and match the key. Desired set = binary rpms of `succeeded` packages in `last-build.json` (debuginfo only with `publish_debuginfo`, src.rpms with `publish_srpms`) + for enabled packages that did not succeed, their files from the current `state.json` (retention). Diff by file name and unsigned `source_sha256`: add, replace, remove, re-sign (key changed). Only changed files are staged, signed (`rpm --addsign`, verified with `rpm -Kv`) and moved; createrepo_c and repomd signing run only when an arch dir changed or its metadata/signature is missing. The `_log` of each failed package is copied to `logs/<pkg>.log` and logs of packages no longer failing are removed. `state.json` is rewritten only when its content changes, so a repeated publish is a no-op. s3: upload changed objects (rpms, repodata, then `repomd.xml*`, then `.repo`/state/site), delete stale managed keys last, purge Cloudflare, then upload every cached source file of the enabled native packages that `_sources/sha256/` lacks (the source archive: no Packman dependency once seeded; never deleted by publish).

**update** (`Upstream`). Per enabled native package with a `watch:` (others are `skip`):
- `url` + `pattern`: GET the page/feed, every regex match (group 1) is a candidate. `git` + `tags`: `git ls-remote --tags`, tag names matching the regex. `git` + `branch`: newer when the branch head differs from `watch.commit`.
- Candidates are ordered by rpmvercmp; newer than the spec `Version:` means outdated.
- Updating fetches everything before writing anything, so a failure leaves the package untouched. Sources whose `file`/`urls` contain the old version are renamed, downloaded and get new `sha256`/`size`. A `watch.file` source (git snapshot) is regenerated instead: fetch only the watched ref into `cache/git/`, `git archive` with `exclude` (unanchored, like tar `--exclude`), optional `xz -9 -T1`; branch versions come from `git log --format=<format>` with `%cd` = `%Y%m%d`. The tarball goes to the cache (publish seeds the source archive) and `watch.commit` is recorded.
- Spec: `Version:` (upstream `-` becomes `+`), plus the old version in `Source*`/`%define`/`%global` lines. `watch.sover` (file + regex in the snapshot) bumps `%define sover`, `baselibs.conf` and adds a `weakremover()` for the old sover when the spec has some. `.changes` gets `- Update to version X` by `packager`.
- `package.yml` is edited in place (format and comments kept). No build is triggered; review `git diff packages/`, then `build --package`.
- git.ffmpeg.org advertises broken all-zero refs, so a whole-repo fetch fails; fetching only the watched ref avoids them.

## Adding a package

1. `packages/<name>/package.yml` (model: `PackmanNova::Manifest`; copy a similar package). obs-link: `kind: obs-link`, `origin.project/package`, optional `pin`, `link.delete`. native: vendor spec, patches, changes next to `package.yml` (no `_service`); list remote files under `sources:` with upstream `urls`; a file with no upstream (git snapshot, vanished blob) gets `sha256`/`size` only and is served from the source archive after the next publish. Add a `watch:` when upstream is alive: `url`+`pattern`, or `git`+`tags`/`branch`, and for git snapshots `file` (`<name>-%{version}.tar[.xz]`), `format` (branch), `exclude`, `sover {path, pattern}`. Copy a similar package (fdk-aac, gstreamer-plugins-bad-codecs, libx264, x265).
2. `packman-nova sync --package <name> --update-checksums` fills `sha256`/`size` (rewrites the yml: comments and flow style are lost).
3. `packman-nova build --package <name>` (or `--single <name>` to build only it), check `project/_build.tumbleweed.x86_64/<name>/_log`.
4. `packman-nova publish`. Set `enabled: false` to drop a package: the next full sync removes its project dir, the next publish its rpms.

## Signing key

- Generate: `packman-nova gpg generate --name packman-nova --email <e>` prints one base64 line; put it into `.env` as `GPG_PRIVATE_KEY_BASE64=` without echoing it (`umask 077; k=$(packman-nova -q --no-log-file gpg generate ... | head -1)`).
- The public key is never stored in git. Publish derives it for `repomd.xml.key` and `/packman-nova.key`; sync derives it into `cache/public-key.asc` for `packages/packman-nova-keyring` (source `generated: public-key`), so syncing the keyring needs the private key. `gpg export-public` prints it.
- Current key (2026-09-29, uid changed 2026-10-04): RSA 4096, id `C2F2B2F52552208F`, fingerprint `41F4 A349 AA69 0BAA 70B1 FCC5 C2F2 B2F5 2552 208F`, uid `packman-nova <oleg.b.antonyan@gmail.com>`, no expiry. The private key exists only in `.env` (gitignored, 0600); back that file up offline (password manager or encrypted storage) and store the same line as the CI secret.
- Rotate: generate a new key, replace `.env` and the CI secret, bump the keyring package (`Version`, changes), `sync`, `build --package packman-nova-keyring`, `publish`. Publish sees the new key id in `state.json` and re-signs every published rpm; users must import the new key (`zypper ref` asks, the keyring update imports it).

## Troubleshooting

- **pbuild quirks** (verified in `/usr/lib/build`): `_configs/<dist>.conf` lookup is broken, so the tool passes `--dist /project/_configs/tumbleweed.conf --reponame tumbleweed`. `--rebuild` is passed as `--rebuild all` because it swallows a following bare word. `--no-repo-refresh` still downloads metadata on the first run. The `[ 1:N 2:M ]` progress uses `\r`, so logs contain long lines. Results: `_meta.fail` means failed even if a stale `_meta.success` exists.
- **Build roots in a container lose `/dev/fd`** (fixed in the image): obs-build bind-mounts `/dev/null` etc. when `/run/.containerenv` exists and never unmounts them, so from the second build in a root `create_devs` is skipped and the `/dev/fd` symlinks deleted by `--clean` are not recreated. brp scripts using `< <(...)` then fail with `/dev/fd/63: No such file or directory`. `container/Containerfile` patches `init_buildsystem` to recreate `fd`, `stdin`, `stdout`, `stderr` links; the image build fails if the patched line disappears upstream. The `rm: cannot remove '/build-root/N/dev/null': Device or resource busy` lines at the start of each `_log` are harmless.
- **Local results shadow Tumbleweed**: pbuild puts the result repo first and freezes names seen there, so our `ffmpeg-8`, `libfdk-aac2`, `libheif*`, `ffmpeg-N-mini-*` win in build roots. Check with `podman run --rm -v <workdir>/project:/project --entrypoint pbuild <image> --dist /project/_configs/tumbleweed.conf --reponame tumbleweed --arch x86_64 --repo https://download.opensuse.org/tumbleweed/repo/oss/ --repoquery <binary> /project`. On users' systems our release `1699.N.nova.1` beats Factory's and vendor stickiness keeps them after `zypper dup --from packman-nova-essentials --allow-vendor-change`.
- **Unresolvable on a first run**: packages depending on not-yet-built local packages show `unresolvable: nothing provides ...` in intermediate results; pbuild re-checks after every build, so only the final table matters.
- **Failed rebuilds**: a failed rebuild deletes the package's old rpms in `_build.*`. Publish keeps the previously published files of every enabled package that did not succeed (the site marks them "kept from the last successful build").
- **Disk** (full run 2026-09-29): build roots 3.2 GB for two builders, `_build.tumbleweed.x86_64` 2.2 GB of which `.pbuild/_base` 1.6 GB, cache 356 MB, repo 339 MB. `check` warns under 30 GB.
- **Cleaning**: `clean --build-root --yes` is always safe (roots are recreated). `clean --results` forces a full rebuild and loses `.pbuild/_base`. Never `rm -rf build-root` directly: its content is subuid-owned; use `clean` or `podman unshare rm -rf`.
- **Stale lock**: `.lock` is an flock; it is released when the process dies, the file itself can stay.
- **Sync failures**: `sync` exit 1 lists the package and message; the previous sources stay in place, so a build still uses them.
- **pbuild internals** (`/usr/lib/build/PBuild/*.pm`): `_meta` = srcmd5 + hdrmd5 of every expanded build dep; hdrmd5 of a TW rpm is known only once it sits in `.pbuild/_base`, hence that dir must persist (`state push/pull` carries it). `.pbuild/_result` is Perl Storable: parse `--result-code all` text instead. pbuild never fetches `Source:` URLs and runs only `mode="buildtime"` services, so sync must materialize every file. obs-build ignores the prjconf `Release:` line (the OBS scheduler evaluates it), hence `--release`.
- **Rootless podman**: uid 0 in the container is the host user, so `_build.*` is host-owned and only `build-root/` is subuid-owned. `--userns=keep-id` breaks pbuild's chroot. Docker (rootful) leaves root-owned results: untested.
- **Half-initialised build root**: obs-build asks an interactive question and fails; `clean --build-root --yes`.
- **Cold full run**: ffmpeg-8 and libheif depend on each other, so ffmpeg-8 builds twice.

## Risks

- Packman shuts down 2026-12-31. Archive-only sources (git snapshots, dead hosts) exist only on PMBS and in our `_sources/sha256/`; confirm the archive holds all of them before then.
- Factory sources move fast (srcmd5 can change between fetch and build); sync fetches listing and files at one `rev`. No upstream webhooks: the nightly run is the change detector for obs-link packages; native packages change only through `update` (`update --check` reports).
- GitHub-hosted runners guarantee only 14 GB of disk; the warm workdir (see Disk) must stay under it.
- Proprietary blobs are tagged `proprietary`; legal exposure is controlled per package with `enabled`.

## GitHub Actions

- `.github/workflows/ci.yml`: on push and pull request, Ruby from `.ruby-version`, `bundle exec rake`.
- `.github/workflows/build-publish.yml`: nightly at 01:17 UTC plus manual `workflow_dispatch`, ubuntu-26.04. Installs podman and zstd, writes `.env` from secret `PACKMAN_NOVA_DOTENV` (the full local `.env`; the job sets `PACKMAN_NOVA_WORKDIR`, which wins over `.env`), then `image build`, `state pull --allow-missing`, `run --provider s3`, `state push` (also after a failed run). Logs are in the job console. pbuild uses the config defaults (2 builders x 8 jobs). Concurrency group without cancel; timeout 350 min.
- Before the first dispatch: set the secret, seed `_state/` with `state push` from a local full build (a cold full build does not fit 350 min on a 4-core runner), verify `state pull` + `run` on a dispatch.

## Code map

`lib/packman_nova/`: `cli/*` (one class per command), `config*`, `workdir.rb`, `logging/`, `utils/`, `container/` (runtime, runner, image), `manifest/`, `sources/` (OBS, downloads, source archive), `sync/`, `upstream/` (probes, git snapshots, package rewrite), `pbuild/` (command, executor, results, run allocation), `build.rb`, `state/`, `gpg/`, `repo/` (layout, diff, signer, createrepo, providers localfs/s3, state archive), `publish.rb`, `site/` (ERB page). Tests: `test/unit/**` mirror the tree; `test/integration/test_smoke.rb` (fdk-aac end to end, `PACKMAN_NOVA_INTEGRATION=1`, optional `PACKMAN_NOVA_SMOKE_ROOT`).
