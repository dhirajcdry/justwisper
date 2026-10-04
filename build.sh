#!/bin/bash
# Builds, signs, and installs Wispr into /Applications.
set -euo pipefail

cd "$(dirname "$0")"
./scripts/check-toolchain.sh

CONFIG="release"
APP="justwisper.app"
BIN_NAME="Wispr"   # internal SwiftPM executable name (invisible to users)
INSTALL_DIR="/Applications"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/justwisper-build.XXXXXX")"
cleanup() {
    if [ -e "${STAGING}/${APP}.previous" ]; then
        echo "Previous app preserved at ${STAGING}/${APP}.previous" >&2
    else
        rm -rf "${STAGING}"
    fi
}
trap cleanup EXIT
APP_PATH="${STAGING}/${APP}"

echo "==> Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "==> Assembling ${APP}..."
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

cp "${BIN_DIR}/${BIN_NAME}" "${APP_PATH}/Contents/MacOS/${BIN_NAME}"
cp "Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"

# App icon (Finder / Dock / ⌘-Tab).
if [ -f "Resources/justwisper.icns" ]; then
    cp "Resources/justwisper.icns" "${APP_PATH}/Contents/Resources/justwisper.icns"
fi

# Bundle the custom fonts (Hanken Grotesk + JetBrains Mono).
if [ -d "Resources/Fonts" ]; then
    mkdir -p "${APP_PATH}/Contents/Resources/Fonts"
    cp Resources/Fonts/*.ttf "${APP_PATH}/Contents/Resources/Fonts/" 2>/dev/null || true
    cp Resources/Fonts/*OFL.txt "${APP_PATH}/Contents/Resources/Fonts/"
fi

# SwiftPM emits resource bundles (e.g. WhisperKit_WhisperKit.bundle) next to the
# binary. In an .app, Bundle.module resolves them from Contents/Resources.
if compgen -G "${BIN_DIR}/"*.bundle > /dev/null; then
    cp -R "${BIN_DIR}/"*.bundle "${APP_PATH}/Contents/Resources/"
fi

# Local builds use ad-hoc signing so they never require a keychain password.
# Opt into an available stable identity with WISPR_SIGN_IDENTITY="Wispr Dev".
SIGN_ID="${WISPR_SIGN_IDENTITY:--}"
if [ "${SIGN_ID}" = "-" ]; then
    echo "==> Ad-hoc signing (no keychain password required)..."
else
    echo "==> Code signing with identity ${SIGN_ID}..."
fi

# Sign nested resource bundles first, then the app (avoids --deep choking on
# resource bundles that have no Info.plist).
for b in "${APP_PATH}/Contents/Resources/"*.bundle; do
    [ -e "$b" ] && codesign --force --sign "${SIGN_ID}" "$b" >/dev/null 2>&1 || true
done
codesign --force --sign "${SIGN_ID}" "${APP_PATH}"

# Explicit stable signing must not silently fall back to ad-hoc.
if [ "${SIGN_ID}" != "-" ]; then
    if codesign -dvv "${APP_PATH}" 2>&1 | grep -q 'flags=.*adhoc'; then
        echo "Requested signing identity was unavailable; refusing ad-hoc fallback." >&2
        exit 1
    fi
fi

codesign --verify --strict "${APP_PATH}"

echo "==> Stopping any running Wispr copy..."
RUNNING_PIDS="$(pgrep -f '/justwisper\.app/Contents/MacOS/Wispr$' 2>/dev/null || true)"
for pid in $RUNNING_PIDS; do
    kill -TERM "$pid" 2>/dev/null || true
done
for pid in $RUNNING_PIDS; do
    for attempt in {1..40}; do
        if ! kill -0 "$pid" 2>/dev/null; then break; fi
        sleep 0.25
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "Wispr (PID $pid) did not exit; installation cancelled." >&2
        exit 1
    fi
done

TARGET="${INSTALL_DIR}/${APP}"
BACKUP="${STAGING}/${APP}.previous"
if [ -e "${TARGET}" ]; then
    mv "${TARGET}" "${BACKUP}"
fi
if ! mv "${APP_PATH}" "${TARGET}"; then
    if [ -e "${BACKUP}" ]; then mv "${BACKUP}" "${TARGET}"; fi
    echo "!! Failed to install ${TARGET}; previous app was restored." >&2
    exit 1
fi
rm -rf "${BACKUP}"

echo "==> Installed ${TARGET}"
echo
echo "Run it:   open \"${TARGET}\""
echo "Logs:     \"${TARGET}/Contents/MacOS/${BIN_NAME}\""
