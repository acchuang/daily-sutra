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

echo ">> built $BUNDLE"
echo "   open with: open $BUNDLE"