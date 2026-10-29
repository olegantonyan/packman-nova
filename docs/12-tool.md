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
| `-d, --distro ID` | distro to work on (overrides `PACKMAN_NOVA_DISTRO`; default: first of `distros`) |
| `-w, --workdir DIR` | overrides `PACKMAN_NOVA_WORKDIR` |
| `--offline` | no network: caches only |
| `-v, --verbose` / `-q, --quiet` | debug output and backtraces / warnings and errors only |
| `--[no-]log-file` | write `logs/<YYYYmmdd-HHMMSS>-<command>.log` (default yes; `gpg`, `site` never do) |
| `--version`, `-h, --help` | |

Errors print `Class: message` (backtrace with `-v`) and exit 1; Ctrl-C exits 130. `sync`, `update` (not `--check`), `build`, `publish`, `clean`, `state` take the workdir lock (`.lock`, non-blocking): a second one fails with `LockError` instead of waiting.

| command | options | behaviour, exit code |
|---|---|---|
| `check` | | doctor: config, workdir writable, free disk (warn < 30 GB), runtime, image present and built from the current Containerfile, manifests valid (and their `distros` known), gpg key decodes, network (`prjconf.base_url`, `distro.snapshot_url`, `distro.source_snapshot.repo` repomd; skipped with `--offline`). 0 ok / 1 any fail |
| `sync` | `--check`, `--package NAME` (repeatable), `--update-checksums`, `--[no-]prjconf` | materializes `project/`. `--check` writes nothing but caches and reports drift. 1 if any package failed, else 2 for `--check` with drift, else 0 |
| `update` | `--check`, `--package NAME` (repeatable), `--version V` | native packages with a `watch:`: probe upstream, then bump every outdated one (see **update** below). `--version` (one package) sets that version even if not newer; for branch watches it is a commit. Needs the network and `packager`. 1 if any package failed, else 2 for `--check` with a newer version, else 0 |
| `build` | `--package NAME`... (pbuild `--rebuild-pkg`), `--rebuild` (all), `--single NAME`, `--[no-]sync`, `--dry-run`, `--release STR`, `--buildjobs N`, `--jobs N`, `--[no-]checks`, `--debuginfo`, `--[no-]repo-refresh` | sync (unless `--no-sync`), allocate run and release, run pbuild for x86_64, then the i586 baselibs pass, write the build record. 0 if no package is failed/unresolvable/broken, else 1; `BuildError` if pbuild itself exits non-zero without a failed package. `--dry-run` prints the podman command |
| `publish` | `--provider localfs\|s3`, `--unsigned`, `--dry-run`, `--[no-]site`, `--arch A` | sign new rpms, createrepo, sign repomd, write state/site, provider sync. `--dry-run` prints add/replace/remove/re-sign lists. `--unsigned` refused for s3 while `signing.require_signature` |
| `status` | `--json`, `--live` | per package: kind, srcmd5, last code, release, rpm count, built_at, published release. `--live` asks pbuild in the container |
| `site` | `--provider localfs\|s3`, `--output DIR` | renders the site (`index.html`, `sitemap.xml`, `robots.txt`, `llms.txt`, `llms-full.txt`, `site.webmanifest`, plus the icons and `og-image.png` copied from `lib/packman_nova/site/assets/`) from the `state.json` of every distro. With `--provider`: reads the states from it and uploads only those files (s3: then purges Cloudflare). Without: reads the local repo root, writes only. `--output` writes there and never uploads |
| `gpg generate` | `--name N` (default `project_name`), `--email E`, `--format base64\|armor` | prints a new RSA 4096 private key (one base64 line) on stdout, instructions on the log |
| `gpg info [FILE\|-]` | | key id, fingerprint, uids of FILE or the configured key |
| `gpg convert [FILE\|-]` | `--from`, `--to base64\|armor` | |
| `gpg export-public` | | prints the public key derived from `GPG_PRIVATE_KEY_BASE64` |
| `image build` / `image info` | `--[no-]cache`, `--tag T` | builds `container/Containerfile`, records `state/image.json` |
| `clean` | `--build-root`, `--results`, `--cache`, `--all`, `--yes` | build-root through the container runtime (subuid-owned files), results = `project/_build.*` (incl. `.pbuild/_base`), cache = `cache/` |
| `state push` / `state pull` | `--allow-missing` (pull) | s3 only: `tar --zstd` of `project/_build.<reponame>.<arch>/` (x86_64 and, on TW, i586) and `state/` to `<path_in_bucket>/_state/<distro.id>.tar.zst`; `--allow-missing` makes a first pull on an empty bucket a warning |
| `run` | `--[no-]publish`, `--[no-]site`, `--[no-]fail-on-failed-packages` (default yes), `--provider P` | sync, `build --no-sync`, publish. Exit 2 if publish failed; else 1 if any package failed to sync or build (unless `--no-fail-on-failed-packages`), even though publish succeeded; else 0. Ends with `run summary: ...` |

## Configuration

Defaults: `config/packman-nova.yml`. Layers, later wins: defaults, distro overlay `config/distros/<id>.yml`, user file, non-empty `PACKMAN_NOVA_{WORKDIR,CONTAINER_RUNTIME,PUBLIC_URL,REPO_PATH}`, CLI flags. The distro is `--distro`, else `PACKMAN_NOVA_DISTRO`, else the first of `distros`; its overlay must set `distro.id` to the same id. `${VAR}` expands from the process env, then `./.env` (process env wins); unset variables become `""`. Unknown keys and wrong types raise `ConfigError` naming the dotted key. Relative paths (`prjconf/`, `container/`) resolve against the repository root.

| key | default | notes |
|---|---|---|
| `workdir` | `${PACKMAN_NOVA_WORKDIR}` | required; each distro works in `<workdir>/<distro.id>/` |
| `distros` | `[opensuse_tumbleweed, opensuse_leap_16.0, opensuse_leap_16.1]` | known distros: site tab order, first is the default |
| `project_name` | `packman-nova` | |
| `packager` | `Oleg Antonyan <...>` | author of `.changes` entries written by `update` |
| `distro.{id,name,suse_version,arches,repos,snapshot_url}` | overlay; TW: `opensuse_tumbleweed`, `openSUSE Tumbleweed`, `1699`, `[x86_64]`, TW oss, TW `media.1/media` | first arch is built; `name` is the display name; Leap: `repo/oss` of `distribution/leap/16.x` (it carries the updates too) |
| `distro.source_snapshot.{repo,project}` | TW: TW `src-oss`, `openSUSE:Factory`; Leap: `""` (off) | obs-link packages from `project` sync the revision the snapshot was built from |
| `distro.baselibs.{arch,repos}` | overlay; TW: `i586`, TW i586 port oss; Leap: `""` | second pbuild pass with `--baselibs`; `arch: ""` disables it |
| `release.template` | overlay; TW `%{suse_version}.%{run}.nova.1`, Leap `160000.%{run}.nova.1` / `160100.%{run}.nova.1` | Leap follows PMBS (`spec:160000.<CI>.pm.<B>`), above SLFO's `160000.N.M` and Backports' `bp160.*` |
| `prjconf.{base_url,base_fallback,base_prepend,local}` | overlay; TW: Factory `_config`, `prjconf/factory-base.conf`, `[]`, `[prjconf/packman-nova-macros.conf]`; Leap: obs-build `configs/leap-16.x.conf`, `prjconf/leap-16.x-base.conf`, `[prjconf/leap-base-fixup.conf]`, `[prjconf/packman-nova-macros-leap.conf]` | `base_prepend` files go before the base config, `local` files after it, each concatenated in order. 16.1 also lists `prjconf/leap-16.1-fixup.conf` first in `local` (obs-build's file says `suse_version 1600`, OBS uses 1610) |
| `sources.obs_api` | OBS public API | |
| `sources.http.{timeout_sec,retries}` | `600`, `5` | |
| `container.{runtime,image,containerfile,privileged,extra_args}` | `auto`, `localhost/packman-nova-builder:latest`, `container/Containerfile`, `true`, `[]` | `auto` = podman, then docker |
| `pbuild.{reponame,buildjobs,jobs,checks,debuginfo,repo_refresh,timeout_sec,extra_args}` | `tumbleweed` (Leap `leap-16.x`), `2`, `8`, `true`, `false`, `true`, `43200`, `[]` | `timeout_sec` bounds each pbuild pass |
| `signing.{gpg_private_key_base64,require_signature}` | `${GPG_PRIVATE_KEY_BASE64}`, `true` | the public key is always derived from the private one |
| `repository.{slug,path,public_url,publish_srpms,publish_debuginfo,provider}` | `packman-nova-essentials`, `<distro.id>/essentials` (overlay), `${PACKMAN_NOVA_PUBLIC_URL}`, `true`, `false`, `localfs` | `slug` = zypper repo alias; empty `public_url` = `file://<localfs root>` |
| `repository.localfs.path` | `${PACKMAN_NOVA_REPO_PATH}` | empty = `<workdir>/repo`, shared by all distros |
| `repository.installcheck.{enabled,allow_missing}` | `true`, overlay: TW known 32-bit gaps + `ffmpeg-mini`, Leap `ffmpeg-mini` | missing capabilities that do not fail publish |
| `repository.s3.{bucket,path_in_bucket,endpoint,access_key_id,secret_access_key,region,force_path_style,cloudflare_zone_id,cloudflare_api_token}` | `CLOUDFLARE_*` env, `""`, `auto`, `true` | |
| `site.{name,title,description,source_url}` | see file; `source_url` GitHub repo | `title`/`description` also feed the meta, Open Graph and JSON-LD tags; `source_url` adds a nav and footer link; `""` hides them |

Secrets masked as `***` in logs: `signing.gpg_private_key_base64`, `repository.s3.secret_access_key`, `repository.s3.cloudflare_api_token`.

## Workdir layout

Everything below lives in `<workdir>/<distro.id>/`, except the shared localfs repo `<workdir>/repo/`.

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
repo-mirror/                       local mirror of this distro's part of the s3 bucket (plus other distros' state.json for the site)
```

Published layout (localfs root or bucket prefix): `index.html` (all distros, one tab each), `sitemap.xml`, `robots.txt` (Cloudflare prepends its managed rules), `llms.txt` and `llms-full.txt` (llmstxt.org; the full one is the page as Markdown), `site.webmanifest`, `favicon.{svg,ico}`, `apple-touch-icon.png`, `icon-{192,512}.png`, `og-image.png` (static; regenerate by hand if the site title changes), `packman-nova.key`, per distro `<distro.id>/essentials/{packman-nova.repo,state.json,packages.json}`, `.../x86_64/*.rpm` (x86_64 + noarch) with `repodata/{repomd.xml,repomd.xml.asc,repomd.xml.key,...}`, `.../src/*.src.rpm` with its own `repodata/`, `.../logs/<pkg>.log` (per failing package, linked from the site: the full `_log` of a failed build, else pbuild's details, e.g. what is unresolvable).

Required state keys: `PackmanNova::State::Schemas`. Build record keys: `schema run release image_id started_at finished_at arch distro_snapshot pbuild_argv pbuild_exit built codes packages`; per package `code flavor reason rpms debuginfo_rpms srpm log built_at duration_sec details`. Repo `state.json` `files` entries carry `sha256 size package source_sha256 key_id`; `packages` entries carry `log` (relative path of the published build log, or null).

## How each step decides what to do

**sync** (`Sync#call`). Prjconf: fetch `prjconf.base_url` unless offline/`--no-prjconf`, write `_configs/<pbuild.reponame>.conf` (`prjconf.base_prepend` + base) and `_config` (the `prjconf.local` files concatenated, `Release:` lines dropped); a changed `_config` md5 sets `rebuild_all_required`, which stays set until a build with `--rebuild` succeeds. Snapshot id from `media.1/media`. Per enabled manifest whose `distros` include the selected distro (no `distros` = every distro):
- obs-link: `GET <obs_api>/source/<project>/<package>?expand=1[&rev=R]`. R is `pin`, else, when `project` is `distro.source_snapshot.project`, the srcmd5 in the DISTURL of the snapshot's src.rpm (`repo` primary gives its `rpm:header-range`; only the header is fetched; offline: the recorded srcmd5), else none (head). A package without a src.rpm in the snapshot fails. Unchanged when srcmd5, file list and every on-disk md5 equal `sync.json`. Otherwise files not in `link.delete` are fetched with `?rev=<srcmd5>` into `cache/blobs/md5/`, assembled in `project/.<pkg>.tmp/` and renamed into place. `link.patches` (files next to `package.yml`) are added and declared as `Patch<max+1>:` before the first `%prep`; the spec must apply patches with `%autosetup`/`%autopatch`. `link.add` files are copied as is.
- native: every file in `packages/<pkg>/` except `package.yml` plus each `sources[]` entry. Remote files come from the cache, else from `urls` in order, else from the source archive `<public_url>/_sources/sha256/<sha256>`; a source without `urls` is archive-only. `path:` copies a repo file; `generated: public-key` writes the public key derived from `GPG_PRIVATE_KEY_BASE64`. sha256 must match.
- A failing package keeps its previous `sync.json` entry and project dir; the others continue. Full runs prune project dirs without an enabled manifest.

Source endpoints verified 2026-09-29: OBS serves link packages' files with `?rev=<expanded srcmd5>`; 2026-10-21: TW src.rpm DISTURLs are `obs://build.opensuse.org/openSUSE:Factory/standard/<srcmd5>-<pkg>` and OBS serves older srcmd5s. Offline sync uses cached OBS listings, blobs, the existing prjconf copy (else `base_fallback`) and the recorded snapshot. `openSUSE:Factory/fdk-aac` does not exist; Factory scmsync packages (ffmpeg-4/7/8/9) carry `_scmsync.obsinfo` and `build.specials.obscpio`, which pbuild ignores.

**build** (`Build#call`). Sync, then lock. Run number = max(`run-counter.json`, repo `state.json` run, max run in result rpm names) + 1, persisted before pbuild starts; release from `release.template`. A run that builds nothing gives its number back. pbuild itself decides what to build: a package is rebuilt when its `_meta` (source md5 + hdrmd5 of every build dependency) changes, so a new Factory srcmd5 or a changed dependency rebuilds exactly the affected tree. Failed packages are retried only when their meta changes or with `--package`/`--rebuild`. Implicit `--rebuild all` when `rebuild_all_required` and no explicit selection. pbuild prefers our previous binaries over the distro's by name, so a package can deadlock on its own stale library (old ffmpeg-8 `libavcodec62` lacking a symbol version the distro's pipewire now needs, while ffmpeg-8's build root needs pipewire): after each pass, an unresolvable package whose details miss `libX.so.N` while its own results hold `libXN`, or name one of its own results after `needed by` (old i586 ffmpeg-8 `libavfilter11` needing a `libplacebo.so` the port dropped), gets its results removed and the pass reruns once (published rpms stay, publish retains them). A pass whose output shows `download of ... failed` (a mirror hiccup) reruns up to 3 times, 60 s × attempt apart; pbuild keeps what it already built. Afterwards results are collected with `pbuild --result-code all` (with details) and cross-checked with the files in `_build.*/<pkg>/`. Each failed/unresolvable/broken package is logged with its details and the last 100 lines of its `_log` (the i586 log when the baselibs pass failed), so the CI console shows why.

**-32bit** (as Packman; Tumbleweed only, Leap 16 has no 32-bit). A second pass `pbuild --arch i586 --baselibs` against the TW i586 port, same release, builds only the `onlybuild` list in `prjconf/packman-nova-macros.conf` (the packages with a `baselibs.conf`). mkbaselibs turns their i586 libraries into `*-32bit*.x86_64.rpm`; the build record keeps them under `packages.<name>.baselibs` and publish puts them into `x86_64/`. i586 rpms are not published. A package whose i586 build fails counts as failed, so its previously published files are kept.

**publish** (`Publish#call`). Works on the selected distro's `repository.path` only, plus the root site files and `packman-nova.key`; other distros' keys are never touched. Lock, decode and match the key. Desired set = binary rpms of `succeeded` packages in `last-build.json` (debuginfo only with `publish_debuginfo`, src.rpms with `publish_srpms`) + for enabled packages that did not succeed, their files from the current `state.json` (retention). Diff by file name and unsigned `source_sha256`: add, replace, remove, re-sign (key changed). Only changed files are staged, signed (`rpm --addsign`, verified with `rpm -Kv`) and moved; createrepo_c and repomd signing run only when an arch dir changed or its metadata/signature is missing. Then `installcheck` (libsolv) checks every rpm of the arch repo against `distro.repos`; a package whose rpms cannot be installed is recorded as `uninstallable` in `state.json`, flagged on the site and fails `publish`/`run` (exit 1), unless every missing capability is in `repository.installcheck.allow_missing` (known gaps PMBS ships too: 32-bit celt, libmad, libmng, libmodplug, libmpcdec; the `ffmpeg-mini` stubs). The check runs on every publish, so a distro change that breaks our rpms is caught too; a download failure only warns. Each failing package gets `logs/<pkg>.log` (its `_log` when the build ran, else pbuild's details; a leftover `_log` of an unresolvable package is ignored) and logs of packages no longer failing are removed. A failing package's `reason` is pbuild's details. `state.json` is rewritten only when its content changes, so a repeated publish is a no-op. `packages.json` is written next to it. Unless `--no-site`, the site is rendered from this state plus every other distro's `<path>/state.json` read from the provider. s3: upload changed objects (rpms, repodata, then `repomd.xml*`, then `.repo`/state/site), delete stale managed keys last, purge Cloudflare, then upload every cached source file of the enabled native packages that `_sources/sha256/` lacks (the source archive: no Packman dependency once seeded; never deleted by publish).

**update** (`Upstream`). Per enabled native package with a `watch:` (others are `skip`), for every distro (`--distro` does not filter):
- `url` + `pattern`: GET the page/feed, every regex match (group 1) is a candidate. `git` + `tags`: `git ls-remote --tags`, tag names matching the regex. `git` + `branch`: newer when the branch head differs from `watch.commit`.
- Candidates are ordered by rpmvercmp; newer than the spec `Version:` means outdated.
- Updating fetches everything before writing anything, so a failure leaves the package untouched. Sources whose `file`/`urls` contain the old version are renamed, downloaded and get new `sha256`/`size`. A `watch.file` source (git snapshot) is regenerated instead: fetch only the watched ref into `cache/git/`, `git archive` with `exclude` (unanchored, like tar `--exclude`), optional `xz -9 -T1`; branch versions come from `git log --format=<format>` with `%cd` = `%Y%m%d`. The tarball goes to the cache and `watch.commit` is recorded.
- Spec: `Version:` (upstream `-` becomes `+`), plus the old version in `Source*`/`%define`/`%global` lines. `watch.sover` (file + regex in the snapshot) bumps `%define sover`, `baselibs.conf` and adds a `weakremover()` for the old sover when the spec has some. `.changes` gets `- Update to version X` by `packager`.
- `package.yml` is edited in place (format and comments kept).
- With `repository.s3` configured, every run then uploads the cached sources of the selected packages missing from `_sources/sha256/` (so CI can fetch snapshots; a rerun retries a failed upload). Without it: a warning.
- No build is triggered; review `git diff packages/`, then `build --package`.
- git.ffmpeg.org advertises broken all-zero refs, so a whole-repo fetch fails; fetching only the watched ref avoids them.

## Adding a package

1. `packages/<name>/package.yml` (model: `PackmanNova::Manifest`; copy a similar package). `distros: [id, ...]` limits it to those distros; a distro-specific variant is its own directory (PMBS style: `ffmpeg-7-leap-16.0` links `SUSE:SLFO:1.2/ffmpeg-7`; `gstreamer-plugins-bad-codecs-leap-16.0` is a 1.26 copy with `spec: gstreamer-plugins-bad-codecs.spec`). obs-link: `kind: obs-link`, `origin.project/package`, optional `pin`, `link.delete`, `link.patches` (our patches on top of the origin, declared in `<origin.package>.spec` unless `spec:` is set), `link.add` (extra files, e.g. a `baselibs.conf`). native: vendor spec, patches, changes next to `package.yml` (no `_service`); list remote files under `sources:` with upstream `urls`; a file with no upstream (git snapshot, vanished blob) gets `sha256`/`size` only and is served from the source archive (`update` uploads it, as does publish). Add a `watch:` when upstream is alive: `url`+`pattern`, or `git`+`tags`/`branch`, and for git snapshots `file` (`<name>-%{version}.tar[.xz]`), `format` (branch), `exclude`, `sover {path, pattern}`. Copy a similar package (fdk-aac, gstreamer-plugins-bad-codecs, libx264, x265).
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
- Factory runs days ahead of the TW snapshot; building head linked libraries users don't have yet (openapv 1.1.3 `liboapv.so.11`, 2026-10-20), hence the snapshot pin. Sync fetches listing and files at one `rev`. No upstream webhooks: the nightly run is the change detector for obs-link packages; native packages change only through `update` (`update --check` reports).
- GitHub-hosted runners guarantee only 14 GB of disk; the warm workdir (see Disk) must stay under it.

## GitHub Actions

- `.github/workflows/ci.yml`: on push and pull request, Ruby from `.ruby-version`, `bundle exec rake`.
- `.github/workflows/build-publish.yml`: nightly at 19:17 UTC (GitHub starts it ~6 h late, ~01:20 UTC) plus manual `workflow_dispatch` (`bundle exec rake dispatch [REF=<branch>]`, via `gh`), ubuntu-26.04.
  - Job `build-publish` is a matrix over the distros (`fail-fast: false`): one runner per distro, in parallel, `PACKMAN_NOVA_DISTRO` from the matrix. Installs podman and zstd (apt `Acquire::Retries=5`), writes `.env` from secret `PACKMAN_NOVA_DOTENV` (the full local `.env`; the job sets `PACKMAN_NOVA_WORKDIR`, which wins over `.env`), then `image build` (up to 3 tries), `state pull --allow-missing`, `run --provider s3 --no-site`, `state push` (also after a failed run). pbuild uses the config defaults (2 builders x 8 jobs). Concurrency group per distro without cancel; timeout 350 min.
  - Job `site` runs after all of them (also when one failed): `site --provider s3` renders the site from every distro's `state.json` and uploads it. Only this job writes the site, so the parallel jobs never race on it.
- Before the first dispatch of a distro: set the secret, seed `_state/<distro.id>.tar.zst` with `--distro <id> state push` from a local full build (a cold full build does not fit 350 min on a 4-core runner), verify `state pull` + `run` on a dispatch.

## Code map

`lib/packman_nova/`: `cli/*` (one class per command), `config*`, `workdir.rb`, `logging/`, `utils/`, `container/` (runtime, runner, image), `manifest/`, `sources/` (OBS, downloads, source archive), `sync/`, `upstream/` (probes, git snapshots, package rewrite), `pbuild/` (command, executor, results, run allocation), `build.rb`, `state/`, `gpg/`, `repo/` (layout, diff, signer, createrepo, providers localfs/s3, state archive), `publish.rb`, `site/` (ERB page). Tests: `test/unit/**` mirror the tree; `test/integration/test_smoke.rb` (fdk-aac end to end, `PACKMAN_NOVA_INTEGRATION=1`, optional `PACKMAN_NOVA_SMOKE_ROOT`).
