#!/usr/bin/env bash
# Build the Release screen saver and install it into ~/Library/Screen Savers.
set -euo pipefail
cd "$(dirname "$0")"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild -project MatrixSaver.xcodeproj -scheme MatrixSaver -configuration Release \
  -derivedDataPath build build

SRC="build/Build/Products/Release/MatrixSaver.saver"
DEST="$HOME/Library/Screen Savers/MatrixSaver.saver"

mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

killall legacyScreenSaver 2>/dev/null || true
killall "legacyScreenSaver (Wallpaper)" 2>/dev/null || true

echo "Installed: $DEST"
