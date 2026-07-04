<h1>justwisper</h1>

**100% local, on-device voice dictation for macOS.** Hold a key, speak, and your
words are transcribed **on your Mac** and dropped into whatever app you're typing
in. No cloud. No account. Nothing ever leaves the device.

An open-source, privacy-first take on [Wispr Flow](https://wisprflow.ai).

- **Engine:** [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) — OpenAI Whisper on the Apple Neural Engine via Core ML
- **Trigger:** hold **Right Option (⌥)** to talk, **double-tap** for hands-free, **Esc** to cancel
- **Design:** native SwiftUI menu-bar app with an editorial "Press" look

---

## Download

1. Grab the latest **`justwisper-x.y.dmg`** from the [Releases](../../releases) page.
2. Open it and drag **justwisper** into **Applications**.
3. Because this is an open-source build without a paid Apple Developer ID, macOS
   quarantines it. Clear that once:

   ```bash
   xattr -dr com.apple.quarantine /Applications/justwisper.app
   ```

   (Or: right-click the app → **Open**, or approve it under *System Settings ▸
   Privacy & Security ▸ Open Anyway*.)
4. Launch it and grant **Microphone** + **Accessibility** when asked (see below).

## Requirements

- Apple Silicon Mac, **macOS 14+**
- Internet **once** — the first launch downloads a Whisper model (~150 MB for `base.en`) and caches it locally. After that it runs fully offline.

## First-run permissions

- **Microphone** — so it can hear you (prompted on first record).
- **Accessibility** — so it can detect the global hotkey and paste into other
  apps. Grant it under *System Settings ▸ Privacy & Security ▸ Accessibility*.

The app shows a banner and a "SETUP" badge until both are granted.

## Using it

1. Focus any text field (Slack, Mail, Notes, your editor, a browser…).
2. **Hold Right ⌥**, speak, then **release** — the transcript lands at your cursor.
   Or **double-tap Right ⌥** to latch hands-free (tap once to stop). **Esc** cancels.
3. Text is cleaned up on-device (fillers, stutters, casing, your dictionary,
   voice commands). An optional AI rewrite (Apple Foundation Models) is off by default.

## Build from source

```bash
./build.sh          # compiles + assembles justwisper.app (stable local signing)
open ./justwisper.app
```

Run the binary directly to watch logs:

```bash
./justwisper.app/Contents/MacOS/Wispr
```

**Stable local signing** (so macOS keeps your Accessibility/Mic grants across
rebuilds) is set up once with `./setup-signing.sh`. Without it, builds fall back
to ad-hoc signing and macOS will re-prompt for permissions on each rebuild.

## Packaging a release

```bash
./package.sh            # arm64 .dmg (Apple Silicon)
./package.sh universal  # arm64 + x86_64
```

Produces `justwisper-<version>.dmg`, ad-hoc signed, ready to attach to a GitHub Release.

## Privacy

Audio is captured, transcribed, and formatted entirely on your Mac. History and
settings live in `~/Library/Application Support` — no cloud, no sync, no
telemetry. You can erase all history from **Insights ▸ Erase History**.

## License

Open source. See [`LICENSE`](LICENSE).
