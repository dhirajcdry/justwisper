# Screenshots and visual assets

The public images render the actual SwiftUI interface with fictional sample content. They are not images generated to imitate the app, user testimonials, or performance benchmarks.

## What's included

| Asset | Purpose |
| --- | --- |
| `site/assets/social-card.png` | 2400 × 1260 README header and social preview |
| `site/assets/screenshots/home.png` | Workspace with fictional dictation history |
| `site/assets/screenshots/dictionary.png` | Sample custom vocabulary |
| `site/assets/screenshots/history.png`, `insights.png`, `settings.png` | More native app views in the automatic tour |
| `site/assets/screenshots/snippets.png` | Sample phrase expansions |
| `site/assets/screenshots/overlay-*.png` | All four real floating overlay views |
| `site/assets/walkthrough.gif` | Three-step illustrated shortcut loop for GitHub |
| `site/assets/walkthrough.mp4` | The same silent walkthrough in a smaller video format |

The walkthrough uses a simplified note editor and the actual overlay image. Its step durations are editorial pacing, not measured transcription latency.

## Render the native screenshots

On macOS with the project's Swift toolchain installed:

```bash
WISPR_SCREENSHOT_DIR="$PWD/site/assets/screenshots" \
  swift test --filter ScreenshotTests
```

The renderer instantiates `AppModel(preview: true)`. That path starts with empty collections, uses a separate preferences suite, skips persisted dictation reads/writes, and does not start hotkeys, microphone capture, or model preparation. Fixtures live in `Tests/WisprTests/ScreenshotTests.swift`. It renders real SwiftUI views through an AppKit hosting window at 4× resolution and exports lossless PNGs. Full app screenshots are 4480 × 2960 pixels; overlays use the same 4× scale. The renderer sets the SwiftUI display scale and cached text drawing layers to 4× before capture, so text is rasterized at the target resolution rather than enlarging a finished image. Pixel dimensions are asserted during capture.

Normal `swift test` skips screenshot generation unless the environment variable is set.

## Preview and capture the website

The site is plain HTML/CSS/JavaScript. No application framework, analytics, external font service, or build step is needed.

From the repository root:

```bash
python3 -m http.server 8765 --bind 127.0.0.1
# Open http://127.0.0.1:8765/site/
```

For browser captures, install Playwright in a temporary tools folder rather than the app repository:

```bash
npm install --prefix /tmp/justwisper-web-tools playwright
PLAYWRIGHT_MODULE=file:///tmp/justwisper-web-tools/node_modules/playwright/index.mjs \
PLAYWRIGHT_CHANNEL=chrome node scripts/capture-site.mjs
```

This example uses an installed Google Chrome. Alternatively install Playwright's Chromium and omit `PLAYWRIGHT_CHANNEL`. Keep the local server running while capturing. The script checks mobile overflow, image loading, browser errors, the four overlay selectors, the FAQ, and automatic walkthrough looping, six selectable app views, and reduced-motion behavior. Desktop/mobile review screenshots and the check report are written to `/tmp/`.

Browser captures use a 2× device scale, including the social card and walkthrough frames. The social card is rendered from `scripts/visuals.html`. Walkthrough frames are captured from the interactive demo on the actual site.

## Make the short walkthrough

After capturing, with FFmpeg installed:

```bash
./scripts/make-walkthrough.sh
```

Review every public image after generation. Keep the fictional-content captions. Don't replace fixtures with private history or publish unreviewed screen recordings. Fonts and their OFL notices are bundled in both the app and site.
