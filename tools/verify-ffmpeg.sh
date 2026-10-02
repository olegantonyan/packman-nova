#!/usr/bin/env bash
# Verify a built ffmpeg-N against the Packman expectations: codec switches in configure, unrestricted provides.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); n=${1:-8}
log="$root/out/ffmpeg-$n.log"
echo "== configure flags of interest"
grep -oE -- '--enable-lib(x264|x265|fdk-aac-dlopen|xvid|opencore-amrnb|vo-amrwbenc|vidstab|smbclient)|--disable-decoder=[^ ]+|--enable-nonfree|--enable-gpl|--enable-version3' "$log" | sort -u
echo "== rpms"
ls "$root"/out/rpms/ | grep -E "^(ffmpeg-$n|libav|libsw|libpostproc)" || true
echo "== libavcodec provides"
rpm -qp --provides "$root"/out/rpms/libavcodec*.rpm | grep -E 'unrestricted|libavcodec-full' || echo "MISSING unrestricted provides"
echo "== libavcodec requires on our libs"
rpm -qp --requires "$root"/out/rpms/libavcodec*.rpm | grep -E 'libx264|libx265|libxvidcore|fdk' || echo "no direct x264/x265 requires (fdk is dlopen)"
echo "== enabled encoders/decoders count"
grep -cE '^\[.*\] Enabled (encoders|decoders)' "$log" || true
