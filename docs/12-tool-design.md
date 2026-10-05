# packman-nova tool: design (approved 2026-09-29)

Ruby CLI that materializes package sources, runs `pbuild` inside a rootless podman container, and publishes a signed rpm-md repo (localfs first, R2 later). This document is the contract for the implementation work packages. Style and conventions: `~/projects/omnipackage/omnipackage-agent-ruby` (plain OptionParser CLI, `# frozen_string_literal: true`, `::Const` everywhere, one class per file mirroring the namespace, keyword args, private attr_readers, minitest `describe` blocks, rubocop config copied, no code comments).

## 0. Verified facts that shape the design (pbuild = `/usr/bin/pbuild`, `/usr/lib/build/PBuild/*.pm`)

| Fact | Where | Consequence |
|---|---|---|
| Repo precedence: `PBuild::Expand::configure_repos` walks repos in order and freezes every binary name seen in an earlier repo; within one repo the highest EVR wins. The local results repo is pushed first (`pbuild` ~line 419, `addlocalrepo` before any `--repo`). | `Expand.pm:31-80`, `pbuild:419-428` | Our `ffmpeg-8`, `libfdk-aac2`, `libheif*`, `ffmpeg-N-mini-*` stubs shadow Tumbleweed's same-named binaries. No flag needed. There is no `--repo <dir>` for plain directories; fallback would be `Prefer:` lines in `_config`. Diagnose with `pbuild --repoquery <name>` and `--debugflags expansion`. |
| `_configs/<dist>.conf` lookup is broken (`pbuild:185` interpolates an array ref). | `pbuild:185` | Pass `--dist /project/_configs/tumbleweed.conf` (a path) and always `--reponame tumbleweed`. Results land in `<dir>/_build.tumbleweed.<arch>/`. |
| `<dir>/_config` is combined on top of the base dist config; pbuild prepends `%define _repository <reponame>`. | `pbuild:197-202` | `_config` = our macro block only, without any `Release:` line. |
| `_meta` = srcmd5 line + hdrmd5 of every expanded build dep. hdrmd5 of remote binaries is known only after the rpm was downloaded into `_build.*/.pbuild/_base/<repoid>/`; carried across metadata refreshes. | `RemoteRepo.pm:250-335,470-500`, `Checker.pm:346-413,620-680` | `.pbuild/_base` must survive between runs, otherwise every run is a "meta change" rebuild. CI state caching must include it. |
| A rebuild first deletes old files in `_build.*/<pkg>/` except `_meta*`, `_log*`, `_repository`; on failure `_meta.fail`, on success `_meta.success`; `_reason` XML written. | `BuildResult.pm:110-186` | A failed rebuild leaves no rpms. Publish keeps the last published rpms of a package whose status is not `succeeded`. Status from files: `_meta.success` identical to `_meta` = succeeded; `_meta.fail` = failed. |
| `pbuild --reponame X --arch A --result-code all --terse <dir>` prints `code:  N` lines followed by indented package names. Codes: `broken succeeded failed unresolvable blocked scheduled waiting building excluded disabled locked`. `.pbuild/_result` is Perl Storable. | `Result.pm:27-70` | Parse the text; never read Storable. |
| `--release STR` passed verbatim to every `build`; `--jobs`, `--no-checks`, `--debuginfo`, `--baselibs`, `--buildjobs N` (root becomes `<root>/<n>` when N>1), `--no-repo-refresh`, `--rebuild-pkg`, `--rebuild [code|pkg]`, `--single`. Each package build starts with `--clean`. | `Job.pm:325-352`, `pbuild:484-497` | Exact invocation in section 7. |
| Packages = every subdir not starting with `.` or `_`. `_link` expanded only within the project; `_multibuild` flavors become `<pkg>:<flavor>`; `_service` `mode="buildtime"` runs at build time, other services ignored (files must exist). Plain `Source: https://` lines are not fetched. | `Source.pm`, `Link.pm`, `Multibuild.pm`, `Service.pm`, `RemoteAssets.pm` | `sync` downloads tarballs and materializes the project dir; `package.yml` stays in git only. Atomic swap via `project/.<pkg>.tmp` then rename. |
| Factory public API serves the expanded file list with `srcmd5` and files; fetch files with `?rev=<srcmd5>`. Factory `_config` at `.../openSUSE:Factory/_config`. TW snapshot id from `media.1/media`. | curl | Sync source of truth for links. |
| Factory prjconf: `Prefer: ffmpeg-N-mini-libs/-devel`; ffmpeg-8 spec `Requires: (libavcodec62 = %version-%release or ffmpeg-8-mini-libs = %version-%release)`. | `prjconf/factory-base.conf` | Our `ffmpeg-mini` stub must cover ffmpeg 5, 6, 7, 8 and 9. |
| Rootless podman: uid 0 inside = host user, so `_build.*` results are owned by the host user; only build-root contents map to subuids. `--userns=keep-id` is not usable (pbuild needs uid 0 for chroot). | `/etc/subuid` | No chown for results; `clean --build-root` via `podman unshare rm -rf` or a throwaway container. |
| Host: Ruby 4.0.6, podman 6.0.2, gems dotenv, aws-sdk-s3, minitest, rubocop, rexml. System liquid 2.5.1 is too old: gemspec requires `liquid ~> 5`. Workdir parent exists with 3.1 TB free. | shell | |

## 1. Architecture

```
git: packages/<pkg>/{package.yml, spec, patches, _service, changes}   prjconf/   container/
        | sync  (api.opensuse.org public, upstream URLs, PMBS, mirror src, sha-addressed cache)
workdir/project/<pkg>/...  + _config + _configs/tumbleweed.conf        state/sync.json
        | build  (podman --privileged  packman-nova-builder  pbuild ... /project)   state/run-counter.json, state/builds/<run>.json
workdir/project/_build.tumbleweed.x86_64/<pkg>/{*.rpm,_meta,_meta.success|_meta.fail,_log,_reason}
        | publish (diff vs repo state, sign new rpms, createrepo_c, sign repomd, site, provider sync)
workdir/repo/ (localfs)  ->  later R2 (same layout), served as https://packman.omnipackage.org/
```

One Ruby process orchestrates; every tool touching rpm/gpg/createrepo/pbuild runs inside the builder image. Host requirements: ruby, bundler, podman or docker, tar, flock.

## 2. Repository layout (git, `/home/oleg/projects/packman-nova`)

```
exe/packman-nova
lib/packman_nova.rb                          requires, ::PackmanNova::VERSION
lib/packman_nova/version.rb
lib/packman_nova/errors.rb                   Error, ConfigError, ManifestError, SyncError, DownloadError, BuildError, PublishError, GpgError, LockError, SubprocessError
lib/packman_nova/cli.rb                      global OptionParser + dispatch
lib/packman_nova/cli/{sync,build,publish,status,site,gpg,image,check,clean,run,state}.rb
lib/packman_nova/config.rb                   typed attributes like OmnipackageAgent::Config, nested sections
lib/packman_nova/config/env_expander.rb      ${VAR} expansion, .env via dotenv, process env wins
lib/packman_nova/workdir.rb                  all workdir paths, mkdirs, flock
lib/packman_nova/logging/{logger,formatter,multioutput}.rb
lib/packman_nova/utils/{subprocess,yaml,path,http,xml,digest,json_file}.rb
lib/packman_nova/manifest.rb                 package.yml model + validation
lib/packman_nova/manifest/{source,link_rules,loader}.rb
lib/packman_nova/sources/{obs_client,archive,download_cache,downloader}.rb
lib/packman_nova/sync.rb
lib/packman_nova/sync/{obs_link_materializer,native_materializer,prjconf,report,state}.rb
lib/packman_nova/container/{runtime,image,runner,mount}.rb
lib/packman_nova/pbuild/{command,result_parser,results,package_result,project_dir}.rb
lib/packman_nova/build.rb
lib/packman_nova/release.rb                  template + run counter -> string
lib/packman_nova/state/{run_counter,build_record,image_record}.rb
lib/packman_nova/gpg.rb                      generate/info/convert/import command builders (temp GNUPGHOME)
lib/packman_nova/repo/{layout,state,diff,rpm_query,signer,createrepo,repo_file,retention}.rb
lib/packman_nova/repo/providers/{base,localfs,s3}.rb
lib/packman_nova/publish.rb
lib/packman_nova/site/{generator,model}.rb
lib/packman_nova/site/templates/{index.html.liquid,packman-nova.repo.liquid,style.css}
config/packman-nova.yml                      committed defaults with ${VAR}
.env.example
packages/<pkg>/package.yml (+ vendored files; tarballs ignored by .gitignore)
packages/ffmpeg-mini/, packages/packman-nova-keyring/     authored by us
prjconf/{factory-base.conf,packman-nova-macros.conf}
container/Containerfile                      no entrypoint
test/test_helper.rb, test/unit/**/test_*.rb, test/fixtures/**, test/integration/test_smoke.rb
Gemfile, packman_nova.gemspec, Rakefile, .rubocop.yml, .gitignore
.github/workflows/{ci.yml,build-publish.yml}
docs/12-tool.md                              CLI reference, workdir layout, state files
tools/                                       legacy scripts from milestones 1-3
```

Gemspec runtime deps: `dotenv`, `liquid ~> 5`, `aws-sdk-s3 ~> 1`, `rexml`, `base64`, `logger`; `required_ruby_version >= 4.0`. Gemfile: `gemspec` + minitest, minitest-fail-fast, rake, rubocop, rubocop-minitest, rubocop-rake, pry. Rakefile tasks: `test` (excludes test/integration), `integration_test`, `rubocop`, default `test rubocop`. `.rubocop.yml` copied from agent-ruby with `TargetRubyVersion: 4.0`, `Exclude: exe/packman-nova, vendor/**/*`.

## 3. Workdir layout (`/run/media/oleg/c3996ce0-a379-4403-9d64-7d4c0536463f/dev/packman-nova`)

```
.lock                              flock for sync/build/publish (mutually exclusive)
project/                           pbuild project dir
  _config                          macro block (prjconf/packman-nova-macros.conf minus Release:)
  _configs/tumbleweed.conf         Factory _config (fetched, cached; fallback prjconf/factory-base.conf)
  <pkg>/                           materialized sources
  _build.tumbleweed.x86_64/        pbuild results + .pbuild/{_base/<repoid>/*.rpm cache,_result,_lastcheck,_metadata,lastopts}
  .pbuild/lastdata
build-root/                        pbuild --root (subdirs 1..N per builder); subuid-owned content
cache/blobs/sha256/<hex>           downloaded tarballs, content-addressed
cache/blobs/md5/<hex>              OBS files (listing gives md5)
cache/obs/<project>/<pkg>/<srcmd5>.xml   cached directory listings
cache/prjconf/factory-<md5>.conf
state/run-counter.json             {"run":3,"updated_at":"...","last_release":"1699.3.nova.1"}
state/sync.json                    per package: kind, origin, srcmd5, files{name:md5}, synced_at; plus tumbleweed_snapshot, factory_prjconf_md5, local_config_md5, rebuild_all_required
state/builds/<run>.json            release, image id, tw snapshot, started/finished, per-package code/rpms/time/reason
state/last-build.json              copy of the newest builds/<run>.json
state/image.json                   image tag, id, containerfile sha256, built_at
logs/<YYYYmmdd-HHMMSS>-<command>.log
tmp/                               gpg key temp files (0700), staging for signing
repo/                              localfs provider target (default)
repo-mirror/                       local mirror when provider is s3
```

## 4. Configuration

### 4.1 `config/packman-nova.yml`

Loaded first; optional user override via `-c FILE` or `./packman-nova.yml`. `${VAR}` expanded on the raw text before YAML parse; `.env` loaded with `Dotenv.load` (process env wins; missing vars become empty strings). Precedence: CLI flag > env `PACKMAN_NOVA_*` > user file > defaults.

```yaml
workdir: ${PACKMAN_NOVA_WORKDIR}
project_name: packman-nova
vendor: packman-nova
distro:
  id: opensuse_tumbleweed
  suse_version: 1699
  arches: [x86_64]
  repos:
    - https://download.opensuse.org/tumbleweed/repo/oss/
  snapshot_url: https://download.opensuse.org/tumbleweed/repo/oss/media.1/media
release:
  template: "%{suse_version}.%{run}.nova.1"
prjconf:
  base_url: https://api.opensuse.org/public/source/openSUSE:Factory/_config
  base_fallback: prjconf/factory-base.conf
  local: prjconf/packman-nova-macros.conf
sources:
  obs_api: https://api.opensuse.org/public
  http: { timeout_sec: 600, retries: 5 }
container:
  runtime: auto
  image: localhost/packman-nova-builder:latest
  containerfile: container/Containerfile
  privileged: true
  extra_args: []
pbuild:
  reponame: tumbleweed
  buildjobs: 2
  jobs: 8
  checks: true
  debuginfo: false
  repo_refresh: true
  extra_args: []
signing:
  gpg_private_key_base64: ${GPG_PRIVATE_KEY_BASE64}
  require_signature: true
repository:
  slug: packman-nova-essentials
  path: opensuse_tumbleweed/essentials
  public_url: ${PACKMAN_NOVA_PUBLIC_URL}
  publish_srpms: true
  publish_debuginfo: false
  provider: localfs
  localfs:
    path: ${PACKMAN_NOVA_REPO_PATH}
  s3:
    bucket: ${CLOUDFLARE_R2_BUCKET}
    path_in_bucket: ""
    endpoint: ${CLOUDFLARE_R2_ENDPOINT}
    access_key_id: ${CLOUDFLARE_R2_ACCESS_KEY_ID}
    secret_access_key: ${CLOUDFLARE_R2_SECRET_ACCESS_KEY}
    region: auto
    force_path_style: true
    cloudflare_zone_id: ${CLOUDFLARE_ZONE_ID}
    cloudflare_api_token: ${CLOUDFLARE_API_TOKEN}
site:
  title: packman-nova Essentials for openSUSE Tumbleweed
  description: Independent rebuild of the Packman Essentials repository from public sources.
```

`.env.example` keys: `PACKMAN_NOVA_WORKDIR`, `PACKMAN_NOVA_CONTAINER_RUNTIME`, `PACKMAN_NOVA_PUBLIC_URL`, `PACKMAN_NOVA_REPO_PATH`, `GPG_PRIVATE_KEY_BASE64`, `CLOUDFLARE_R2_BUCKET`, `CLOUDFLARE_R2_ENDPOINT`, `CLOUDFLARE_R2_ACCESS_KEY_ID`, `CLOUDFLARE_R2_SECRET_ACCESS_KEY`, `CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_API_TOKEN`. Secrets (`gpg_private_key_base64`, `secret_access_key`, `cloudflare_api_token`) are registered as logger filters at config load. Empty `public_url` means `file://<localfs path>`; empty `localfs.path` means `<workdir>/repo`.

`::PackmanNova::Config` follows `OmnipackageAgent::Config`: `ATTRIBUTES` hash with types, nested hashes become nested config objects, `ConfigError` on mismatch, frozen. `Config.load(path:, overrides:)`; `Config#workdir` returns a `::PackmanNova::Workdir`.

### 4.2 `packages/<pkg>/package.yml`

```yaml
name: ffmpeg-8
kind: obs-link                       # obs-link | native
enabled: true
tier: 2                              # documentation only
tags: [codec]                        # free-form; "proprietary" marks blobs
origin:                              # obs-link only
  project: openSUSE:Factory          # default
  package: ffmpeg-8                  # default = name
  pin: null                          # srcmd5 to freeze at, null = follow head
link:                                # obs-link only
  delete: [_multibuild, ffmpeg-8.changes]
notes: "link deletes Factory's mini flavor; ffmpeg-mini stub covers the solver"
```

```yaml
name: gstreamer-plugins-bad-codecs
kind: native
enabled: true
tier: 3
sources:                             # files not in git; everything else in the dir is copied verbatim (except package.yml)
  - file: _service:download_files:gst-plugins-bad-1.28.7.tar.xz
    urls:
      - https://gstreamer.freedesktop.org/src/gst-plugins-bad/gst-plugins-bad-1.28.7.tar.xz
    sha256: <hex>
    size: 8347976
  - file: packman-nova.key            # derived from GPG_PRIVATE_KEY_BASE64 at sync time
    generated: public-key
```

Rules: `urls` tried in order; `sha256` mandatory unless `sync --update-checksums` runs (fills sha256/size from the first successful download and rewrites the yml; the only command writing git-tracked files). Validation: exactly one `<name>.spec` (or `spec:` override), `enabled: false` packages are removed from the project dir. `::PackmanNova::Manifest::Loader.new(packages_dir:)` returns `Manifest` objects with API: `name`, `kind`, `enabled?`, `obs_link?`, `native?`, `origin` (project, package, pin), `link_rules` (delete list), `sources` (file, urls, sha256, size, path), `spec_name`, `dir`, `tags`, `tier`.

### 4.3 Package inventory

| package | kind | origin / sources | notes |
|---|---|---|---|
| ffmpeg-4, ffmpeg-7, ffmpeg-8, ffmpeg-9 | obs-link | openSUSE:Factory | `link.delete: [_multibuild, ffmpeg-N.changes]` |
| vlc, libquicktime, libheif | obs-link | openSUSE:Factory | libheif: delete `_multibuild` (only flavor is `test`); vlc/libquicktime no rules |
| xine-lib | obs-link | multimedia:xine/xine-lib | PMBS `openSUSE.org:multimedia:xine` maps to api project `multimedia:xine` |
| shairplay | obs-link | multimedia:libs/shairplay | |
| libx264 (`:x264` flavor), x265, libde265, kvazaar, fdk-aac, faac, vo-aacenc, amrnb, amrwb, dcadec, l-smash, gpac, libopenaptx, pipewire-aptx, rtmpdump, libaacs, libbdplus, libdvdcss2, gstreamer-plugins-bad-codecs, gstreamer-plugins-ugly-codecs | native | vendored from reference/pmbs/essentials-src-snapshot + tarball URLs from spec `Source:`; files without upstream (faac obscpio, git snapshots) archive-only | libdvdcss2 tarball from download.videolan.org |
| ffmpeg-6 | native (frozen Factory copy) | archive-only | |
| SVT-AV1 | native, `enabled: false` | gitlab tarball | check Factory's SVT-AV1 version; keep disabled if Factory >= 3.0.1 |
| r8168 | native | Realtek/GitHub tarball | KMP against TW `kernel-syms` from oss |
| broadcom-wl | native, `enabled: false` | blob only on PMBS/mirror | phase 2; tag `proprietary` |
| b43legacy-firmware, rtl8761b-firmware | native | b43legacy from OpenWrt sources; rtl8761b archive-only | tag `proprietary` |
| libfprint-tod-broadcom, libfprint-tod-goodix | native | `_service:download_url:*.orig.tar.gz` from dell.archive.canonical.com | tag `proprietary` |
| chromium-plugin-widevinecdm | native | Google blob URL from spec | 117 MB; tag `proprietary` |
| ffmpeg-mini | native, authored | PMBS spec plus `ffmpeg-9-mini-devel/libs` subpackages | `Version: %suse_version` |
| packman-nova-keyring | native, authored | `packman-nova.repo` + public key via `generated: public-key` source | installs key and `/etc/zypp/repos.d/packman-nova.repo`; `%post` runs `rpmkeys --import` |

Excluded (no manifest): flash-player, lightspark, gpg-offline, ffmpeg-3, preinstallimage-base, psi+-iconsets, A_tw-cmake, python-Cython, python-docutils, rpmkey-packman.

## 5. CLI contract (`exe/packman-nova`, plain OptionParser, one `::PackmanNova::Cli::<Command>` class per subcommand)

Global: `-c/--config FILE`, `-w/--workdir DIR`, `--offline`, `-v/--verbose`, `-q/--quiet`, `--no-log-file`, `--version`, `-h`.

| command | options | behaviour / exit code |
|---|---|---|
| `check` | | doctor: config validity, runtime detected, image present, workdir writable and free space (warn < 30 GB), gpg key decodes, manifests valid, network reachability (skipped with `--offline`). 0/1 |
| `sync` | `--check`, `--package NAME` (repeatable), `--update-checksums`, `--no-prjconf` | materializes the project dir; `--check` only reports drift (Factory srcmd5, TW snapshot, prjconf md5) and exits 2 when anything changed, 0 when nothing, 1 on error |
| `build` | `--package NAME`... (pbuild `--rebuild-pkg`), `--rebuild` (all), `--single NAME`, `--buildjobs N`, `--jobs N`, `--no-checks`, `--debuginfo`, `--no-repo-refresh`, `--release STR`, `--no-sync`, `--dry-run` | runs `sync` first unless `--no-sync`; bumps run counter; runs pbuild; parses results; writes `state/builds/<run>.json`. Exit 0 if no package failed/unresolvable/broken, else 1 |
| `publish` | `--provider localfs|s3`, `--unsigned`, `--dry-run`, `--no-site`, `--arch A` | section 8; `--dry-run` prints add/remove/sign lists |
| `status` | `--json`, `--live` (runs `pbuild --result-code all --terse` in the container) | table: package, kind, srcmd5 (short), last code, release, rpm count, built_at, published release |
| `site` | `--output DIR` | regenerates `index.html`, `.repo`, `packages.json` from repo `state.json` |
| `gpg generate --name N --email E [--format base64|armor]` / `gpg info` / `gpg convert --from --to` / `gpg export-public` | | omnipackage-rs semantics; `export-public` prints the public key derived from `GPG_PRIVATE_KEY_BASE64` |
| `image build [--no-cache] [--tag T]`, `image info` | | builds container/Containerfile, records `state/image.json` |
| `clean --build-root | --results | --cache | --all [--yes]` | | build-root via `podman unshare rm -rf` (or a throwaway container) |
| `state push` / `state pull` | (s3 only, later) | tar.zst of `_build.tumbleweed.<arch>/` incl. `.pbuild/_base` plus `state/` to `<path_in_bucket>/_state/` |
| `run` | `--publish/--no-publish`, `--fail-on-failed-packages` | `sync` -> `build` -> `publish`; CI entry point |

The exe rescues `::PackmanNova::Error` and `::StandardError` (prints `Class: message`, backtrace only with `-v`, exit 1) and `::Interrupt` (exit 130).

## 6. Sync algorithm (`::PackmanNova::Sync#call(packages: nil, check_only:, update_checksums:)`)

1. Acquire `.lock` (non-blocking; `LockError` if a build/publish runs). `--check` runs without the lock.
2. Load manifests; validate.
3. Prjconf: unless `--offline`/`--no-prjconf`, GET `prjconf.base_url` (cache by md5); write `project/_configs/tumbleweed.conf` atomically; write `project/_config` from `prjconf.local` with any `Release:` line removed. Record both md5s. If `local_config_md5` changed since the last build, set `sync.json: rebuild_all_required: true`.
4. TW snapshot: GET `snapshot_url`, record.
5. For each enabled manifest:
   - obs-link: `ObsClient#directory(project:, package:, expand: true, rev: pin)` -> `{srcmd5, entries[{name,md5,size}]}` (REXML). Compare with `state/sync.json[pkg].srcmd5` and on-disk md5s; skip if identical and link rules unchanged. Else for each entry not in `link.delete`: ensure `cache/blobs/md5/<md5>` (download `<obs_api>/source/<proj>/<pkg>/<name>?rev=<srcmd5>` to temp, verify md5, rename), assemble `project/.<pkg>.tmp/` via hardlink or copy, swap into place. Record srcmd5, files, `synced_at`.
   - native: copy every regular file from `packages/<pkg>/` except `package.yml`, `provenance.yaml`; for each `sources[]` entry: if `cache/blobs/sha256/<sha>` missing, try `urls` in order, then the source archive `<public_url>/_sources/sha256/<sha>`; verify sha256 (or record with `--update-checksums`); link into tmp dir; swap.
   - Removed/disabled packages: delete `project/<pkg>`.
6. Write `state/sync.json`; print report (changed / unchanged / removed, TW snapshot, prjconf changes). `--check` returns 2 on any change.

`Downloader`: Net::HTTP streaming to `<target>.part`, follows redirects, retries with backoff on 5xx/timeouts, `--offline` = cache only. `DownloadCache` content-addressed, shared across packages.

## 7. Build (`::PackmanNova::Build#call(...)`)

1. Lock; unless `--no-sync`, run Sync.
2. Ensure image (`Container::Image#ensure!`). Record image id.
3. Run counter: `RunCounter#next!` = max(local `state/run-counter.json`, `repo state.json.run` if readable, max run parsed from published rpm releases) + 1, persisted before pbuild starts. Release = `Release.new(template:, suse_version:, run:).to_s` -> `1699.4.nova.1`. `--release STR` overrides (no bump).
4. If `sync.json.rebuild_all_required` and no explicit rebuild flags: add `--rebuild`; clear the flag on success.
5. Container command (`Container::Runner#run(image:, args:, mounts:, env:, privileged:, name:)` -> `Process::Status`, streaming lines to the logger with progname `container`):

```
podman run --rm --privileged --name packman-nova-build-<pid> \
  --mount type=bind,source=<workdir>/project,target=/project \
  --mount type=bind,source=<workdir>/build-root,target=/build-root \
  -e LANG=C.UTF-8 -e HOME=/root \
  localhost/packman-nova-builder:latest \
  pbuild --dist /project/_configs/tumbleweed.conf --reponame tumbleweed --arch x86_64 \
         --repo https://download.opensuse.org/tumbleweed/repo/oss/ \
         --root /build-root --buildjobs 2 --jobs 8 \
         --release 1699.4.nova.1 \
         [--no-checks] [--debuginfo] [--baselibs] [--no-repo-refresh] \
         [--rebuild-pkg NAME]... | [--rebuild] | [--single NAME] \
         [extra_args...] /project
```
`Pbuild::Command` builds the argv; unit-tested. Timeout 12 h (configurable).
6. Result collection: `pbuild --reponame tumbleweed --arch x86_64 --result-code all --terse /project` in the container, parsed by `Pbuild::ResultParser`. Cross-check with `Pbuild::Results.scan(dir)`: per `_build.tumbleweed.x86_64/<pkg>/`: rpm list (split `*.src.rpm`/`*.nosrc.rpm`, `-debuginfo`/`-debugsource`), `_meta.success` == `_meta` (succeeded), `_meta.fail` (failed), `_reason` explain, `_log` path, mtime. Multibuild flavors appear as `libx264:x264`.
7. Write `state/builds/<run>.json` and `state/last-build.json`; print summary; exit 1 if any failure code.

Containerfile: base `registry.opensuse.org/opensuse/tumbleweed`; `zypper -n in build build-mkbaselibs rpm-build createrepo_c gpg2 hostname perl-libwww-perl perl-LWP-Protocol-https perl-XML-Parser perl-YAML-LibYAML zstd xz gzip bzip2 cpio tar` (pbuild ships in `build`); no ENTRYPOINT. Tag `localhost/packman-nova-builder:latest`.

Runtime detection (`Container::Runtime.detect`): env `PACKMAN_NOVA_CONTAINER_RUNTIME` > config > `podman --version` then `docker --version`.

## 8. Publish (`::PackmanNova::Publish#call(provider:, unsigned:, dry_run:)`)

Repo layout (provider root):
```
index.html
packages.json
packman-nova.key
opensuse_tumbleweed/essentials/packman-nova.repo
opensuse_tumbleweed/essentials/state.json
opensuse_tumbleweed/essentials/x86_64/*.rpm (x86_64 + noarch), repodata/{*.xml.*, repomd.xml, repomd.xml.asc, repomd.xml.key}
opensuse_tumbleweed/essentials/src/*.src.rpm (+ repodata)
```
`.repo` file:
```
[packman-nova-essentials]
name=packman-nova Essentials (openSUSE Tumbleweed)
type=rpm-md
baseurl=https://packman.omnipackage.org/opensuse_tumbleweed/essentials/$basearch
gpgcheck=1
gpgkey=https://packman.omnipackage.org/packman-nova.key
enabled=1
autorefresh=1
```

Algorithm (rpm/gpg/createrepo steps run inside the builder container with the repo dir mounted rw and a 0700 `tmp/gpg-<rand>/` mounted ro containing `key.priv`, deleted in `ensure`):
1. Lock. Decode `GPG_PRIVATE_KEY_BASE64`, `gpg --show-keys --with-colons` for key id + fingerprint, derive the public key with `gpg --export --armor` (unless `--unsigned`, refused when `require_signature` and provider is s3).
2. Working copy: localfs -> the repo dir itself; s3 -> `repo-mirror/` reconciled with `provider.list`.
3. Desired set (`Repo::Diff`): for every package with code `succeeded` in `last-build.json`: binary rpms (minus debuginfo unless enabled) to `<arch>/`, `*.src.rpm` to `src/`. For every enabled package not succeeded: retain the files listed under that package in the current `state.json` (`Repo::Retention`). Disabled packages: nothing retained.
4. Diff by filename + sha256: `to_add`, `to_replace`, `to_remove`.
5. Stage new files in `tmp/stage-<run>/`, `rpm -qp --qf '%{NAME}\t%{EVR}\t%{ARCH}\t%{SOURCERPM}\t%{SIGPGP:pgpsig}\t%{SUMMARY}\n'` (Repo::RpmQuery); detect unsigned already-published rpms (re-sign).
6. Sign: `gpg --batch --import /gpgtmp/key.priv`; `rpm --define '_signature gpg' --define '_gpg_name <KEYID>' --addsign <files>`; verify `rpm -Kv`. Move into place; delete `to_remove`.
7. `createrepo_c --update --retain-old-md=0 --compatibility <arch dir>` (and `src/`); `gpg --batch --no-tty --detach-sign --armor --yes --always-trust -o repodata/repomd.xml.asc repodata/repomd.xml`; write `repodata/repomd.xml.key` and `<root>/packman-nova.key`.
8. Write `state.json`, `.repo`, `index.html`, `packages.json` (Site::Generator).
9. Provider sync: localfs done; s3 uploads rpms, `repodata/*` except `repomd.xml*`, then `repomd.xml`, `.asc`, `.key`, then `.repo`, `state.json`, `index.html`, `packages.json`, `packman-nova.key`; deletes last; optional Cloudflare purge. Client: `Aws::S3::Client.new(endpoint:, region: 'auto', force_path_style: true, credentials:, retry_mode: 'adaptive', max_attempts: 10, request_checksum_calculation: 'when_required', response_checksum_validation: 'when_required')`.

`state.json` schema (v1):
```json
{"schema":1,"generated_at":"...","run":7,"release":"1699.7.nova.1","tumbleweed_snapshot":"20260924",
 "key":{"id":"...","fingerprint":"..."},
 "files":{"x86_64/libavcodec62-8.1.2-1699.6.nova.1.x86_64.rpm":{"sha256":"...","size":1,"package":"ffmpeg-8"},"src/...":{}},
 "packages":{"ffmpeg-8":{"kind":"obs-link","origin":"openSUSE:Factory/ffmpeg-8","srcmd5":"...","version":"8.1.2","release":"1699.6.nova.1",
   "status":"succeeded","last_run":6,"built_at":"...","reason":"source change","rpms":[],"srpm":"..."}}}
```

## 9. Static site

`Site::Model` from `state.json` + config; `index.html.liquid` (light/dark CSS variables, code-block/copy-button styling borrowed from `omnipackage-rs/src/publish/repo_files/install.html.liquid`, content rendered at publish time): what this is (independent rebuild of Packman Essentials, not affiliated with Packman or openSUSE), install block (`zypper ar -f -p 80 <public_url>/opensuse_tumbleweed/essentials/packman-nova.repo`, `zypper --gpg-auto-import-keys ref`, `zypper dup --from packman-nova-essentials --allow-vendor-change`), key id + fingerprint + link, TW snapshot, run and generation time, package table (name, version-release, kind/origin with link to build.opensuse.org for links, status, built date, rpm list in a full-width row toggled per package; native packages link to their src.rpm), footer. `packman-nova.repo.liquid` renders the `.repo` file (also used once to generate the file committed into `packages/packman-nova-keyring/`). Liquid `strict_variables: true`.

## 10. GPG (`::PackmanNova::Gpg`)

Every call in a fresh `Dir.mktmpdir` (0700) with `GNUPGHOME` set. Commands as in omnipackage-rs `gpg.rs`: batch file (`Key-Type: RSA`, `Key-Length: 4096`, `Expire-Date: 0`, `%no-protection`), `--export --armor`, `--export-secret-keys --armor`, `--show-keys --with-fingerprint --with-colons` (parse `fpr:`/`pub:`), `--import` + sign test. `generate` prints the one-line base64 private key; `export-public` prints the derived public key; no key file is kept in git. Run on host if `gpg` exists, else in the container.

## 11. Logging, subprocesses, errors

- `Logging::Formatter`: `HH:MM:SS [I] msg` (`[D]/[W]/[E]`), progname `container` lines pass through raw, `$ <cmd>` echo for every subprocess, filters replace secret substrings with `***`; `Logger.new(outputs: [$stdout, logfile])`, `add_filters`, `add_outputs`.
- `Utils::Subprocess#execute(argv, env: {}, chdir: nil, timeout_sec: 43_200, &line)` uses `Open3.popen2e` with an argv array (no shell), TERM then KILL on timeout, returns `Process::Status`; `#capture(argv)` returns stdout, raises `SubprocessError` on non-zero.
- Errors carry context (`DownloadError#url`, `BuildError#failed_packages`); library code never calls `exit`.
- Per-command log file `logs/<ts>-<cmd>.log`.

## 12. Test plan

Unit (minitest `describe` blocks, fixtures under `test/fixtures/`): config (`${VAR}` expansion, env precedence, type errors, defaults, filter list); manifest (valid obs-link/native, missing sha256, unknown kind, url scheme parsing, link rules); obs_client (directory XML parse, rev URL); sync report (changed/unchanged/removed, exit 2); release + run_counter (template, max-of-three recovery, monotonic, corrupted file); pbuild command (exact argv for default, `--rebuild-pkg`, `--single`, `--no-checks`, extra args); result_parser (fixture text); results (fixture `_build` tree); repo diff + retention; repo state round trip; repo_file rendering (public vs file URL); site generator; gpg (skipped without gpg); container runtime detection (stubbed).

Integration (`rake integration_test`, env `PACKMAN_NOVA_INTEGRATION=1`, temp workdir): `image build` (skip if present) -> `sync --package fdk-aac` -> `build --single fdk-aac` -> `publish --provider localfs` with a throwaway key -> assert `repodata/repomd.xml{,.asc,.key}` exist, `state.json` lists `libfdk-aac2-*.rpm`, rpm signature mentions the key id, and in the builder container `zypper --root /tmp/r --gpg-auto-import-keys ar file:///repo/opensuse_tumbleweed/essentials/x86_64 nova && zypper --root /tmp/r ref && zypper --root /tmp/r se -s -r nova fdk-aac` succeeds. Second `publish` is a no-op diff.

## 13. Work packages

| WP | scope | depends on |
|---|---|---|
| WP0 skeleton | Gemfile, gemspec, Rakefile, .rubocop.yml, .gitignore, exe dispatch, `lib/packman_nova.rb`, errors, `Config` + `EnvExpander` + `config/packman-nova.yml` + `.env.example`, `Workdir`, `Logging`, `Utils`, `Container::{Runtime,Runner,Image,Mount}`, `Manifest` model + loader, JSON schema constants, `test_helper`, `docs/12-tool.md` skeleton | none |
| WP1a sync | `Sources::*`, `Sync::*`, `Cli::{Sync,Check}`, unit tests | WP0 |
| WP1b package data | `package.yml` for all packages, vendor remaining natives, author `ffmpeg-mini` and `packman-nova-keyring`, drop `provenance.yaml` and tarballs from the tree | schema only |
| WP2 build | Containerfile, `Pbuild::*`, `Release`, `State::*`, `Build`, `Cli::{Build,Status,Image,Clean}`, tests | WP0 |
| WP3 gpg + publish | `Gpg`, `Repo::*`, providers localfs and s3, `Publish`, `Cli::{Publish,Gpg,State}`, tests | WP0 |
| WP4 site | `Site::*`, templates, `Cli::Site` | WP0 |
| WP5 integration | `Cli::Run`, smoke test, real full run, docs, `.github/workflows` | WP1-4 |

Interfaces frozen by WP0: `Config` attribute names (4.1), `Workdir` path methods (`project_dir`, `configs_dir`, `results_dir(arch)`, `build_root`, `cache_blob(sha256:|md5:)`, `obs_cache_dir`, `state_file(name)`, `builds_dir`, `repo_dir`, `repo_mirror_dir`, `logs_dir`, `tmp_dir`, `lock_file`, `with_lock`), `Logging::Logger`, `Utils::Subprocess`, `Container::Runner#run`, `Manifest` API, and the three JSON schemas.

## 14. Risks and mitigations

1. pbuild local-repo precedence: verified in code; WP5 confirms empirically (`pbuild --repoquery libfdk-aac2`; vlc `_log` shows `ffmpeg-8-libavcodec-devel-8.1.2-1699.*`).
2. pbuild `_configs/` bug: use the `--dist <path>` form; unit test pins the argv.
3. Subuid ownership only under `build-root/`; `clean --build-root` uses `podman unshare`. Docker gives real-root results: documented as unsupported locally.
4. Disk: 5-10 GB per builder root, `.pbuild/_base` 2-4 GB, results 1-2 GB; `check` warns under 30 GB.
5. Factory srcmd5 drift: listing and files fetched at one `rev`; `sync --check` in cron.
6. KMP: r8168 uses TW `kernel-syms`; broadcom-wl deferred.
7. Name clashes with Factory (`libfdk-aac2`, `libheif*`, `ffmpeg-N-*`): build side solved by local-first; runtime side by release `1699.N.nova.1` > Factory's plus vendor stickiness after `--allow-vendor-change`; `ffmpeg-mini` stub `Version: 1699` beats `8.x`.
8. rpmlint/post-build checks on by default (parity with PMBS); `pbuild.checks: false` disables.
9. Failed rebuilds wipe old rpms: publish retains via `state.json`.
10. GitHub Actions: rootless podman `--privileged` expected to work on ubuntu-26.04 (unverified); 14 GB runner disk forces `buildjobs: 1`; state must include `.pbuild/_base` (`state push/pull` to R2 `_state/`); run counter recovers from published `state.json`; concurrency group without cancel.
11. PMBS shutdown: no runtime dependency on Packman. Upstream URLs first, then our content-addressed source archive in R2 (`_sources/sha256/`), which publish fills from the local cache; it must be seeded by a publish before Packman shuts down.
12. Legal: proprietary blobs tagged; `enabled` per package.
13. Upstream change detection has no webhooks (OBS/src.opensuse.org Gitea webhooks need repo admin); cron `sync --check` (exit 2 triggers a build); per-package Atom feeds optional.
