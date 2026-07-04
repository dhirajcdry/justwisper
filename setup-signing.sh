#!/bin/bash
# Creates a STABLE self-signed code-signing identity ("Wispr Dev") so macOS keeps
# remembering the Accessibility / Microphone permissions across rebuilds.
# (Ad-hoc signing changes identity every build, which is why macOS re-prompts.)
#
# Run this ONCE:  ./setup-signing.sh
# You'll be asked for your password once (to trust the local certificate).
set -euo pipefail

IDENTITY="Wispr Dev"
KEYCHAIN="wispr-codesign.keychain"
KEYCHAIN_PW="wispr"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "==> Identity \"$IDENTITY\" already valid. Nothing to do."
    exit 0
fi

echo "==> Generating self-signed code-signing certificate..."
cat > "$WORK/cfg" <<'EOF'
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
EOF

openssl req -x509 -newkey rsa:2048 -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
    -days 3650 -nodes -config "$WORK/cfg" >/dev/null 2>&1
# -legacy = old PKCS#12 format that Apple's keychain can import (OpenSSL 3 default cannot).
openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -out "$WORK/id.p12" -passout pass:"$KEYCHAIN_PW" -name "$IDENTITY" >/dev/null 2>&1

echo "==> Creating keychain and importing identity..."
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"            # no auto-lock timeout
security unlock-keychain -p "$KEYCHAIN_PW" "$KEYCHAIN"
security import "$WORK/id.p12" -k "$KEYCHAIN" -P "$KEYCHAIN_PW" -T /usr/bin/codesign -A

# Add our keychain to the user search list so codesign can find the identity.
EXISTING=$(security list-keychains -d user | sed -e 's/[\" ]//g' | tr '\n' ' ')
security list-keychains -d user -s "$KEYCHAIN" $EXISTING
# Let codesign use the private key without an interactive prompt every build.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PW" "$KEYCHAIN" >/dev/null 2>&1

echo "==> Trusting the certificate for code signing (needs your password once)..."
sudo security add-trusted-cert -d -r trustRoot -p codeSign \
    -k /Library/Keychains/System.keychain "$WORK/cert.pem"

echo
echo "==> Done. Valid code-signing identities:"
security find-identity -v -p codesigning | grep "$IDENTITY" || {
    echo "!! Identity still not valid — check the trust step above."; exit 1; }
echo
echo "Now run ./build.sh — it signs with \"$IDENTITY\" and permissions will persist."
