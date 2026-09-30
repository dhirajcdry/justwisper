# Contributing to justwisper

Thanks for helping make a small Mac tool better. Improvements to the everyday recording → transcription → insertion loop are especially useful.

## Build and run

Use an Apple Silicon Mac running macOS 14+ with **Swift 6.2+ / Xcode 26+**. The committed dependency lockfile is required; CI selects Xcode 26.2 explicitly. The first speech-model setup needs internet; cached models run locally.

```bash
git clone https://github.com/dhirajcdry/justwisper.git
cd justwisper
./setup-signing.sh  # optional, once: stable local signing across rebuilds
./build.sh
open ./justwisper.app
```

Without the local signing setup, builds fall back to ad-hoc signing and macOS may require you to re-enable Microphone/Accessibility after a rebuild. The local identity is not Apple Developer ID signing or notarization.

For diagnostic output, quit any running copy and launch the executable directly:

```bash
./justwisper.app/Contents/MacOS/Wispr
```

Older builds logged dictated text. Current builds log word counts/timings, but diagnostic errors can still include identifying context. Use non-sensitive examples and redact anything private before sharing output.

## Validation

```bash
swift test
swift build -c release
./scripts/smoke-dictation.sh # optional: local synthetic speech + cached Base model; needs FFmpeg
```

The default suite covers hotkey gestures, model-cache selection, and preview decoding settings. The hardware/model and screenshot tests are opt-in:

```bash
# Requires an already downloaded Base model. Uses synthetic silence, no microphone.
# Tokenizer files may download once if the new app-managed cache is empty.
WISPR_MODEL_SMOKE=1 swift test --filter EngineSmokeTests

# Render real SwiftUI views with fictional fixtures, isolated from your history.
WISPR_SCREENSHOT_DIR="$PWD/site/assets/screenshots" swift test --filter ScreenshotTests

# Check documentation and local site asset paths.
python3 scripts/check-site.py
```

For recording changes, also exercise a real hold-to-talk and hands-free take, Esc/Undo, and insertion into a normal text field. Automated synthetic events don't prove every physical keyboard, permission state, and microphone works.

## Where to look

| Area | Entry points |
| --- | --- |
| App lifecycle and state | `App.swift`, `AppModel.swift` |
| Right Option gestures | `HotkeyMonitor.swift` |
| Microphone/session queues | `AudioRecorder.swift` |
| Local speech pipeline | `WhisperEngine.swift`, `TranscriptionEngine.swift` |
| Cache discovery and preview options | `ModelCache.swift`, `TranscriptionTuning.swift` |
| Text insertion | `TextInjector.swift`, `FocusTracker.swift` |
| Cleanup and formatting | `TextFormatter.swift`, `TranscriptCleaner.swift`, `FormatMode.swift` |
| Floating bar | `FlowBar.swift`, `FlowBarStyle.swift`, `OverlayController.swift` |
| Visual system | `Theme.swift`, `Components.swift` |
| Local persistence | `Store.swift` |
| Static website | `site/index.html`, `site/style.css`, `site/app.js` |

Use the existing `Palette` and `F` typography helpers for native UI changes. Preserve the app's warm paper, dark ink, and orange accent. For screenshots and the website, see [asset generation](docs/ASSETS.md).

## Useful contributions

- Reproducible reliability reports with Mac, macOS, microphone, and target-app details.
- Tests for gesture or state transitions that previously broke.
- Accessibility and keyboard-navigation improvements.
- Language/model testing with non-sensitive examples.
- Clearer setup instructions when a real user gets stuck.

## Submit a change

1. Fork the repository and create a focused branch.
2. Describe the user-visible problem and the resulting behavior.
3. Run relevant tests and the release build. Add regression coverage for a behavioral fix.
4. Include screenshots or a short recording for UI changes. Use fictional content.
5. Open a pull request with the checks you actually ran and any remaining limitations.

Keep signing keys, credentials, personal history, and generated build products out of commits. Don't change unrelated settings or reformat the whole project for a small fix. Be kind and constructive in reviews.

For release packaging and deployment, see [Releasing](docs/RELEASING.md). For vulnerability reports, see [Security](SECURITY.md).
