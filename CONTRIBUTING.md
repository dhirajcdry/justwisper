# Contributing to justwisper

Thanks for wanting to help! justwisper is a small, native macOS app and it's
built to be easy to hack on. This guide gets you from clone to running in a
couple of minutes.

## Prerequisites

- **Apple Silicon Mac, macOS 14+**
- **Xcode 15+** (or the Command Line Tools) — check with `swift --version`
- Internet **once** to download the Whisper model on first launch (~150 MB, cached)

## Build & run

```bash
git clone https://github.com/dhirajcdry/justwisper.git
cd justwisper
./setup-signing.sh   # one time: a stable local cert so macOS keeps your
                     # Accessibility/Mic grants across rebuilds
./build.sh           # compiles + assembles justwisper.app
open ./justwisper.app
```

Run the binary directly to watch logs:

```bash
./justwisper.app/Contents/MacOS/Wispr
```

On first launch, grant **Microphone** and **Accessibility** when prompted.

> Skipping `setup-signing.sh` falls back to ad-hoc signing, and macOS will make
> you re-grant Accessibility after every rebuild. Run it once and that goes away.

## Project layout

Everything is in `Sources/Wispr/`. A few good entry points:

| Area | Files |
|------|-------|
| App entry & menu bar | `App.swift`, `AppModel.swift` |
| Hotkey (hold / double-tap / Esc) | `HotkeyMonitor.swift` |
| Mic capture | `AudioRecorder.swift` |
| Transcription engine | `WhisperEngine.swift`, `TranscriptionEngine.swift` |
| Paste into other apps | `TextInjector.swift`, `FocusTracker.swift` |
| Formatting pipeline | `TextFormatter.swift`, `TranscriptCleaner.swift`, `FormatMode.swift` |
| The floating overlay | `FlowBar.swift`, `FlowBarStyle.swift`, `OverlayController.swift` |
| Screens | `HomeView.swift`, `HistoryView.swift`, `InsightsView.swift`, `SettingsView.swift`, … |
| Design tokens | `Theme.swift` (the "Press" palette + fonts) |

## Good first contributions

- **New overlay style** — add a case to `FlowBarStyle` and render it in `FlowBar`.
- **Formatting rules** — voice commands, filler/stutter handling in `TextFormatter`.
- **Language tuning** — dictionary defaults, model options in `ModelCatalog`.
- **Bug fixes & polish** — anything in the issues list.

## Submitting a change

1. Fork the repo and create a branch: `git checkout -b my-change`.
2. Make your change. **Match the surrounding code** — naming, comment density,
   and the SwiftUI idioms already in use. Keep the "Press" look consistent
   (use the `Palette`/`F` tokens in `Theme.swift`, not hardcoded colors/fonts).
3. Build and test the affected flow end-to-end (dictate → paste → confirm).
4. Open a pull request describing what changed and why. Screenshots/screen
   recordings are hugely appreciated for UI changes.

## Reporting bugs

Open an [issue](https://github.com/dhirajcdry/justwisper/issues) with your macOS
version, Mac model, steps to reproduce, and what you expected vs. what happened.
Log output (from running the binary directly) helps a lot.

## Code of conduct

Be kind and constructive. We're all here to make a nice tool.
