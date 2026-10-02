#!/usr/bin/env bash
# LEGACY (milestones 1-3): superseded by `packman-nova build`. Kept for reference only; it relied on
# container/entrypoint.sh, which is gone, so it no longer works with the current builder image.
# Build one package spec with obs-build inside a rootless podman container.
# Usage: tools/build-in-container.sh <pkgdir-name> [extra build args...]
# Env: CI_CNT, B_CNT (release counters), SUSE_VERSION (default 1699), BUILD_FLAVOR (multibuild flavor)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
pkg=$1; shift
release="${SUSE_VERSION:-1699}.${CI_CNT:-1}.nova.${B_CNT:-1}"
mkdir -p "$root/out/rpms" "$root/out/srpms" "$root/.cache/build-root" "$root/.cache/rpms"
flavor_args=(); [ -n "${BUILD_FLAVOR:-}" ] && flavor_args=(--buildflavor "$BUILD_FLAVOR")
exec podman run --rm --privileged \
  -v "$root/packages/$pkg:/src:ro" \
  -v "$root/prjconf:/prjconf:ro" \
  -v "$root/out:/out" \
  -v "$root/.cache/build-root:/build-root" \
  -v "$root/.cache/rpms:/var/cache/build" \
  packman-nova-builder \
  --root /build-root \
  --dist /prjconf/tumbleweed.conf \
  --repo https://download.opensuse.org/tumbleweed/repo/oss/ \
  --rpms /out/rpms \
  --arch x86_64 \
  --jobs "$(nproc)" \
  --nosignature \
  --release "$release" \
  "${flavor_args[@]}" \
  "$@" \
  /src/"$pkg".spec
