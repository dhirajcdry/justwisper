#!/bin/bash
# Optional stable LOCAL development identity. No Developer ID or notarization.
# Uses a random owner-only keychain password and doesn't replace an existing keychain.
set -euo pipefail
cd "$(dirname "$0")"
umask 077
IDENTITY="Wispr Dev"
KEYCHAIN="${HOME}/Library/Keychains/wispr-codesign.keychain-db"
PASSWORD_FILE="${PWD}/.signing/keychain-password"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "Identity '$IDENTITY' already exists. No keychain or trust settings changed."
    exit 0
fi
if [ -e "$KEYCHAIN" ]; then
    echo 'A Wispr development keychain already exists. Unlock it in Keychain Access and retry.' >&2
    echo 'This script will not delete or overwrite an existing keychain.' >&2
    exit 1
fi
mkdir -p .signing
chmod 700 .signing
openssl rand -base64 32 > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
KEYCHAIN_PW="$(cat "$PASSWORD_FILE")"
cat > "$WORK/cfg" <<'CONFIG'
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = Wispr Dev
[ v3 ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CONFIG
openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days 3650 -nodes -config "$WORK/cfg" >/dev/null 2>&1
export WISPR_PKCS12_PASSWORD="$KEYCHAIN_PW"
# OpenSSL 3 needs legacy PKCS#12 for Apple's import; Apple's LibreSSL does not.
if openssl version | grep -q '^OpenSSL 3'; then
    openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -out "$WORK/id.p12" -passout env:WISPR_PKCS12_PASSWORD -name "$IDENTITY" >/dev/null 2>&1
else
    openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
        -out "$WORK/id.p12" -passout env:WISPR_PKCS12_PASSWORD -name "$IDENTITY" >/dev/null 2>&1
fi
unset WISPR_PKCS12_PASSWORD
security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security import "$WORK/id.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PW" -T /usr/bin/codesign
EXISTING=()
while IFS= read -r line; do
    line="${line#*\"}"
    line="${line%\"*}"
    [ -n "$line" ] && EXISTING+=("$line")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$KEYCHAIN" "${EXISTING[@]}"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null 2>&1
# User-scoped trust; no sudo, global trust store, or 'all applications' key ACL.
security add-trusted-cert -r trustRoot -p codeSign "$WORK/cert.pem"
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo 'Identity created, but trust is incomplete. Review it in Keychain Access.' >&2
    exit 1
fi
echo 'Local identity ready. Keep .signing/ private and ignored; now run ./build.sh.'
