#!/usr/bin/env bash
# Export SVG di branding/ -> PNG yg dipakai flutter_launcher_icons & app.
#   ./branding/export_icons.sh
# Butuh Chrome headless. Default: chrome-headless-shell yang diunduh Remotion di
# ../campusflow-booth-video; bisa diganti: CHROME=/path/ke/chrome ./export_icons.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../mobile/assets/icon"
CHROME="${CHROME:-$(ls "$HERE"/../../campusflow-booth-video/node_modules/.remotion/chrome-headless-shell/*/*/chrome-headless-shell 2>/dev/null | head -1)}"
if [[ -z "$CHROME" || ! -x "$CHROME" ]]; then
  echo "Chrome headless tidak ketemu. Set CHROME=/path/ke/chrome-headless-shell" >&2
  exit 1
fi
mkdir -p "$OUT"

# render <svg> <png> <lebar> <tinggi>; latar transparan kecuali SVG-nya punya latar
render() {
  "$CHROME" --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --window-size="$3,$4" \
    --screenshot="$2" "file://$1" >/dev/null 2>&1
  echo "  $(basename "$2")"
}

echo "Export ke mobile/assets/icon/:"
render "$HERE/logo.svg" "$OUT/app_icon.png" 1024 1024
render "$HERE/icon-android-foreground.svg" "$OUT/android_foreground.png" 1024 1024
render "$HERE/icon-android-monochrome.svg" "$OUT/android_monochrome.png" 1024 1024
echo "Export ke branding/:"
read -r W H < <(sed -n 's/.*viewBox="0 0 \([0-9]*\) \([0-9]*\)".*/\1 \2/p' "$HERE/logo-wordmark.svg" | head -1)
render "$HERE/logo-wordmark.svg" "$HERE/logo-wordmark.png" "$W" "$H"
