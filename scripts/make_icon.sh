#!/bin/bash
# Regenerate AppIcon.icns from the source square PNG (dailySutra.png).
# Usage: ./scripts/make_icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="dailySutra.png"
OUT="Sources/DailySutra/Resources/AppIcon.icns"
TMP="$(mktemp -d)/AppIcon.iconset"

[ -f "$SRC" ] || { echo "missing $SRC"; exit 1; }
mkdir -p "$TMP"
for spec in "16:16" "32:32" "128:128" "256:256" "512:512"; do
  px="${spec%%:*}"; name="icon_${px}x${px}.png"
  sips -z "$px" "$px" "$SRC" --out "$TMP/$name" >/dev/null
  sips -z "$((px*2))" "$((px*2))" "$SRC" --out "$TMP/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$TMP" -o "$OUT"
echo ">> wrote $OUT"