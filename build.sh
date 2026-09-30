#!/bin/bash
# Builds Wispr and assembles a runnable Wispr.app menu-bar bundle.
set -euo pipefail

cd "$(dirname "$0")"
./scripts/check-toolchain.sh

CONFIG="release"
APP="justwisper.app"
BIN_NAME="Wispr"   # internal SwiftPM executable name (invisible to users)

echo "==> Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "==> Assembling ${APP}..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"

cp "${BIN_DIR}/${BIN_NAME}" "${APP}/Contents/MacOS/${BIN_NAME}"
cp "Resources/Info.plist" "${APP}/Contents/Info.plist"

# App icon (Finder / Dock / ⌘-Tab).
if [ -f "Resources/justwisper.icns" ]; then
    cp "Resources/justwisper.icns" "${APP}/Contents/Resources/justwisper.icns"
fi

# Bundle the custom fonts (Hanken Grotesk + JetBrains Mono).
if [ -d "Resources/Fonts" ]; then
    mkdir -p "${APP}/Contents/Resources/Fonts"
    cp Resources/Fonts/*.ttf "${APP}/Contents/Resources/Fonts/" 2>/dev/null || true
    cp Resources/Fonts/*OFL.txt "${APP}/Contents/Resources/Fonts/"
fi

# SwiftPM emits resource bundles (e.g. WhisperKit_WhisperKit.bundle) next to the
# binary. In an .app, Bundle.module resolves them from Contents/Resources.
if compgen -G "${BIN_DIR}/"*.bundle > /dev/null; then
    cp -R "${BIN_DIR}/"*.bundle "${APP}/Contents/Resources/"
fi

# Prefer the stable self-signed identity (so macOS keeps Accessibility/Mic grants
# across rebuilds). Fall back to ad-hoc if it hasn't been set up yet.
IDENTITY="Wispr Dev"
KEYCHAIN="${HOME}/Library/Keychains/wispr-codesign.keychain-db"
PASSWORD_FILE="${PWD}/.signing/keychain-password"
if [ -f "${KEYCHAIN}" ] && [ -f "${PASSWORD_FILE}" ]; then
    security unlock-keychain -p "$(cat "${PASSWORD_FILE}")" "${KEYCHAIN}"
fi
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${IDENTITY}"; then
    SIGN_ID="${IDENTITY}"
    echo "==> Code signing with stable identity \"${IDENTITY}\"..."
elif [ -f "${KEYCHAIN}" ]; then
    echo 'A development keychain exists but its identity is unavailable.' >&2
    echo 'Unlock/review it in Keychain Access. Refusing to change to ad-hoc signing.' >&2
    exit 1
else
    SIGN_ID="-"
    echo "==> Ad-hoc signing (optional: ./setup-signing.sh for a stable local identity)..."
fi

# Sign nested resource bundles first, then the app (avoids --deep choking on
# resource bundles that have no Info.plist).
for b in "${APP}/Contents/Resources/"*.bundle; do
    [ -e "$b" ] && codesign --force --sign "${SIGN_ID}" "$b" >/dev/null 2>&1 || true
done
codesign --force --sign "${SIGN_ID}" "${APP}"

# Guard: if we meant to use the stable identity but ended up ad-hoc, the keychain
# was unreachable. Fail loudly instead of shipping a build that will silently lose
# its permissions — better to stop here than to re-prompt for Accessibility later.
if [ "${SIGN_ID}" != "-" ]; then
    if codesign -dvv "${APP}" 2>&1 | grep -q 'flags=.*adhoc'; then
        echo "!! Signing FELL BACK TO AD-HOC despite the \"${IDENTITY}\" identity." >&2
        echo "   The '${KEYCHAIN}' keychain is locked or its key ACL is wrong." >&2
        echo "   Unlock the Wispr development keychain in Keychain Access, then retry." >&2
        exit 1
    fi
    echo "==> Verified: signed with \"${IDENTITY}\" (stable identity, permissions will persist)."
fi

echo "==> Built ${APP}"
echo
echo "Run it:   open ./${APP}"
echo "Logs:     ./${APP}/Contents/MacOS/${BIN_NAME}"
