#!/bin/bash
# Generates synthetic speech locally, then tests real transcription. No mic use.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v ffmpeg >/dev/null || { echo 'Install FFmpeg before this optional check.' >&2; exit 1; }
AUDIO_DIR="$(mktemp -d)"
trap 'rm -rf "$AUDIO_DIR"' EXIT
say -o "$AUDIO_DIR/sample.aiff" 'This is a local dictation test. My words should stay on this Mac.'
ffmpeg -hide_banner -loglevel error -i "$AUDIO_DIR/sample.aiff" -ar 16000 -ac 1 "$AUDIO_DIR/sample.wav"
WISPR_MODEL_SMOKE=1 WISPR_SMOKE_AUDIO="$AUDIO_DIR/sample.wav" \
    swift test --filter EngineSmokeTests
