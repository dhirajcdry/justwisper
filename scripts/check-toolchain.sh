#!/bin/bash
# The locked transitive dependencies require Swift 6.2 or newer.
set -euo pipefail
VERSION="$(swift --version | sed -nE 's/.*Swift version ([0-9]+)\.([0-9]+).*/\1 \2/p' | head -1)"
read -r MAJOR MINOR <<< "$VERSION"
if [ -z "${MAJOR:-}" ] || [ "$MAJOR" -lt 6 ] || { [ "$MAJOR" -eq 6 ] && [ "$MINOR" -lt 2 ]; }; then
    echo 'justwisper requires Swift 6.2+ (Xcode 26+). Check swift --version and xcode-select -p.' >&2
    exit 1
fi
