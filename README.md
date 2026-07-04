# Wispr

A local, push-to-talk dictation tool for macOS — a small [Wispr Flow](https://wisprflow.ai)–style
clone. Hold a key, speak, and your words are transcribed **on-device** and typed
into whatever app you're focused on. No cloud, no account; audio never leaves your Mac.

- **Engine:** [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) (OpenAI Whisper running on the Apple Neural Engine via Core ML)
- **UI:** menu-bar only (no Dock icon)
- **Push-to-talk key:** hold **Right Option (⌥)**, release to transcribe

## Requirements

- Apple Silicon Mac, macOS 14+
- Xcode / Swift toolchain (`swift --version`)
- Internet **once** — the first launch downloads the `base.en` model (~150 MB) and caches it.

## Build & run

```bash
./build.sh          # compiles + assembles Wispr.app (ad-hoc signed)
open ./Wispr.app    # launches into the menu bar
```

To see logs, run the binary directly instead:

```bash
./Wispr.app/Contents/MacOS/Wispr
```

## First-run setup (two permissions)

1. **Accessibility** — needed to detect the global hotkey and paste text.
   On first launch macOS prompts you; or add it manually under
   *System Settings ▸ Privacy & Security ▸ Accessibility* and toggle **Wispr** on.
   After granting, quit and relaunch.
2. **Microphone** — prompted the first time you record. Allow it.

The menu-bar icon shows status: ⏳ loading model · 🎙️ ready · 🎙️(filled) listening · 〜 transcribing.

## How to use

1. Focus any text field (Slack, Notes, your editor, a browser…).
2. **Hold Right Option**, speak, then **release**.
3. A moment later the transcript is pasted at the cursor.

## How it works

| File | Responsibility |
|------|----------------|
| `App.swift` | `@main` entry; sets up a menu-bar-only `NSApplication`. |
| `AppDelegate.swift` | Wires everything together; menu bar + state machine. |
| `HotkeyMonitor.swift` | Global monitor for the Right-Option push-to-talk key. |
| `AudioRecorder.swift` | `AVAudioEngine` mic capture, resampled to 16 kHz mono. |
| `Transcriber.swift` | WhisperKit wrapper; loads the model, transcribes the audio. |
| `TextInjector.swift` | Pastes the result into the focused app via the clipboard + ⌘V. |

## Customizing

- **Model** — in `AppDelegate.swift`, change `Transcriber(model: "base.en")` to
  `"tiny.en"` (faster), `"small.en"`, or `"large-v3"` (most accurate, slower).
- **Hotkey** — in `HotkeyMonitor.swift`, change `pushToTalkKeyCode` (61 = Right ⌥,
  58 = Left ⌥, 54 = Right ⌘).

## Notes / known rough edges

- Ad-hoc signing changes the app's signature on each rebuild, so macOS may ask you
  to re-grant Accessibility after a rebuild. For a stable identity, sign with a
  self-signed certificate.
- Text is inserted by pasting (clipboard is saved and restored ~0.3 s later).
- The mic tap mutates the sample buffer under a lock; fine for dictation lengths.
