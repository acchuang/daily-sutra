#!/bin/bash
# Build the Daily Sutra menu bar app and assemble a .app bundle.
# Usage: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="DailySutra"
BUNDLE="build/$APP.app"

echo ">> swift build"
swift build -c release

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

BIN=$(swift build -c release --show-bin-path)/$APP
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP"
cp Info.plist "$BUNDLE/Contents/Info.plist"
cp Sources/DailySutra/Resources/verses.json "$BUNDLE/Contents/Resources/verses.json"
cp Sources/DailySutra/Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
cp Sources/DailySutra/Resources/MenubarIcon.png "$BUNDLE/Contents/Resources/MenubarIcon.png"

# A stable self-signed identity keeps the designated requirement the same across
# releases (ad-hoc pins it to the build's cdhash). Falls back to ad-hoc without it.
IDENTITY="Daily Sutra Self-Signed"
if ! security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  IDENTITY="-"
fi

echo ">> signing $BUNDLE ($([ "$IDENTITY" = "-" ] && echo ad-hoc || echo "$IDENTITY"))"
codesign -s "$IDENTITY" --force --deep "$BUNDLE" 2>/dev/null || codesign -s "$IDENTITY" --force "$BUNDLE"

# ditto keeps AppleDouble (._*) files out of the zip; plain zip/unzip would break the seal
echo ">> packaging build/$APP.zip"
rm -f "build/$APP.zip"
ditto -c -k --keepParent --norsrc --noextattr "$BUNDLE" "build/$APP.zip"

echo ">> built $BUNDLE"
echo "   open with: open $BUNDLE"