#!/bin/bash
# Run capture-site.mjs first. Frames are illustrative, not timed inference.
set -euo pipefail
cd "$(dirname "$0")/.."
FRAMES="/tmp/justwisper-walkthrough"
cat > "$FRAMES/frames.txt" <<LIST
file '$FRAMES/step-0.png'
duration 3
file '$FRAMES/step-1.png'
duration 4
file '$FRAMES/step-2.png'
duration 3
file '$FRAMES/step-2.png'
LIST
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$FRAMES/frames.txt" \
  -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -r 24 -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p \
  -movflags +faststart site/assets/walkthrough.mp4
ffmpeg -hide_banner -loglevel error -y -i site/assets/walkthrough.mp4 \
  -filter_complex "fps=4,scale=1440:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  -loop 0 site/assets/walkthrough.gif
