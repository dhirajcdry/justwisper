#!/bin/bash
# Builds a distributable justwisper.app and wraps it in a .dmg for GitHub Releases.
#
# This is the OPEN-SOURCE / no-Apple-Developer-ID path: the app is ad-hoc signed,
# so on first launch a downloader must clear the quarantine flag (macOS blocks
# unsigned downloads). The printed instructions + README cover this.
#
#   ./package.sh            # arm64 (Apple Silicon) — default
#   ./package.sh universal  # arm64 + x86_64 (also runs on Intel; slower build)
set -euo pipefail
cd "$(dirname "$0")"
./scripts/check-toolchain.sh

DIST="dist"
mkdir -p "$DIST"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/justwisper-package.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT
APP="$STAGING/justwisper.app"
BIN_NAME="Wispr"
CONFIG="release"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)"

ARCHS="--arch arm64"
LABEL="arm64 (Apple Silicon)"
if [ "${1:-}" = "universal" ]; then
    ARCHS="--arch arm64 --arch x86_64"
    LABEL="universal (Apple Silicon + Intel)"
fi
DMG="$DIST/justwisper-${VERSION}.dmg"

echo "==> Building ${CONFIG} — ${LABEL}..."
swift build -c "$CONFIG" $ARCHS
BIN_DIR="$(swift build -c "$CONFIG" $ARCHS --show-bin-path)"

echo "==> Assembling ${APP}..."
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/justwisper.icns ] && cp Resources/justwisper.icns "$APP/Contents/Resources/"
if [ -d Resources/Fonts ]; then
    mkdir -p "$APP/Contents/Resources/Fonts"
    cp Resources/Fonts/*.ttf "$APP/Contents/Resources/Fonts/" 2>/dev/null || true
    cp Resources/Fonts/*OFL.txt "$APP/Contents/Resources/Fonts/"
fi
if compgen -G "$BIN_DIR/"*.bundle > /dev/null; then
    cp -R "$BIN_DIR/"*.bundle "$APP/Contents/Resources/"
fi

echo "==> Ad-hoc signing (no Developer ID; users clear quarantine on first open)..."
for b in "$APP/Contents/Resources/"*.bundle; do
    [ -e "$b" ] && codesign --force --sign - "$b" >/dev/null 2>&1 || true
done
codesign --force --sign - "$APP"

echo "==> Building ${DMG}..."
DMG_STAGING="$(mktemp -d "${TMPDIR:-/tmp}/justwisper-dmg.XXXXXX")"
trap 'rm -rf "$STAGING" "$DMG_STAGING"' EXIT
cp -R "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "justwisper" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG" >/dev/null

echo
echo "==> Done → ${DMG} ($(du -h "$DMG" | cut -f1))"
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > SHA256SUMS)
cat "$DIST/SHA256SUMS"
echo
echo "First-launch instructions for downloaders (unsigned build):"
echo "  1. Open the .dmg and drag justwisper into Applications."
echo "  2. If blocked, use System Settings > Privacy & Security > Open Anyway."
echo "     See docs/TROUBLESHOOTING.md for first-launch details."
echo "  3. Launch it, then grant Microphone + Accessibility when asked."
