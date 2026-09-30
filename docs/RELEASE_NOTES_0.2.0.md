# justwisper 0.2.0

Local voice dictation for macOS. Hold Right Option, speak, and release to insert your words. Double-tap for hands-free dictation.

This version also preserves rich clipboard contents, avoids overwriting newer copies, and keeps the intended destination fixed while transcription finishes. Diagnostics no longer intentionally include full transcript text.

This version focuses on the everyday loop: more reliable shortcut handling, microphone startup off the UI thread, visible capture/transcription errors, and serialized speech-engine work. Cached models load directly, the tokenizer cache lives in Application Support, and your selected model survives relaunches. Live previews use a bounded recent-audio window while final transcription still processes the full take.

The project also has a new screenshot-led README, an illustrated walkthrough, and detailed setup, privacy, and troubleshooting guides.

## Install

Requires an Apple Silicon Mac with macOS 14 or newer.

1. Download `justwisper-0.2.0.dmg` and drag the app into Applications.
2. Open the app. This community build is ad-hoc signed and not notarized. If blocked, use System Settings → Privacy & Security → Open Anyway after trying to open it. [Apple's instructions](https://support.apple.com/en-us/102445).
3. Grant Microphone and Accessibility. Allow the first model/tokenizer download to finish.
4. Focus a text field, hold **Right ⌥**, speak, and release.

To check the download, place the DMG and `SHA256SUMS` in the same folder and run `shasum -a 256 -c SHA256SUMS` there.

## Known limits

Recognition quality and latency depend on your model, language, microphone, and Mac. Secure fields and some apps can block automatic insertion; completed transcripts can be copied from History. Optional Apple Intelligence polish requires a supported macOS 26+ setup. Live previews show recent words rather than the entire take.

This is an early release. Please include your Mac, macOS version, model, and reproduction steps in bug reports, and remove personal transcript text from logs.
