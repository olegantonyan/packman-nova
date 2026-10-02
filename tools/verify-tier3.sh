#!/usr/bin/env bash
# Verify tier 2/3 outputs carry the Packman-only bits.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); R="$root/out/rpms"
chk() { local rpm=$1 pat=$2; f=$(ls "$R"/$rpm 2>/dev/null | head -1); [ -n "$f" ] || { echo "MISSING rpm $rpm"; return; }; rpm -qpl "$f" | grep -E "$pat" | sed "s|^|  $(basename "$f"): |" || echo "  $(basename "$f"): NO MATCH for $pat"; }
echo "== libheif HEVC plugins"; chk 'libheif-HEIF-*.rpm' 'x265|de265'
echo "== vlc-codecs x264/x265 plugins"; chk 'vlc-codecs-*.rpm' 'x264|x265'; rpm -qp --requires "$R"/vlc-codecs-*.rpm 2>/dev/null | grep -E 'unrestricted|libavcodec' | sed 's/^/  requires: /'
echo "== gstreamer codecs"; chk 'gstreamer-plugins-ugly-codecs-*.rpm' 'libgstx264'; chk 'gstreamer-plugins-bad-codecs-*.rpm' 'libgst(x265|de265|faac|openaptx)'
echo "== x264 CLI"; chk 'x264-2*.rpm' 'bin/x264'
echo "== counts"; ls "$R" | wc -l
