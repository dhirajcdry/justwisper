# Getting unstuck

## macOS won't open the downloaded app

The community DMG is ad-hoc signed and not Apple-notarized. Download only from this repository's Releases page and compare the SHA-256 checksum if you want to verify the asset.

Try opening the app once. Then use **System Settings → Privacy & Security → Open Anyway** if that option appears. [Apple explains the supported flow here](https://support.apple.com/en-us/102445).

If macOS reports an app as damaged, redownload it and verify the checksum first. If you have verified and trust this specific download, the existing command-line workaround is:

```bash
xattr -dr com.apple.quarantine /Applications/justwisper.app
```

This removes the quarantine attribute from that app. It does not sign or notarize it. Do not disable Gatekeeper globally.

## Right Option does nothing

1. Confirm the app is running in the menu bar and the model says **Ready**.
2. Grant **Microphone** and **Accessibility** in System Settings → Privacy & Security.
3. Use the **right-hand Option key**. The left Option key and right mouse button are not the trigger.
4. For hands-free mode, make two quick taps. A slower press can be interpreted as push-to-talk.
5. Test in a simple text field. Other shortcut utilities or secure input can affect global key monitoring.

If you rebuilt the app locally, an ad-hoc signature may invalidate the previous Accessibility grant. Run `./setup-signing.sh` once for a stable local identity, rebuild, and re-enable the app's permission if needed.

## The bar appears, then disappears

A single quick tap finishes automatically after the double-tap window. A very short take can be discarded. Hold the key while speaking, or make two quick taps for hands-free mode.

Recent source changes improve double-tap timing, microphone startup, and error reporting. Confirm you're running the version you just built rather than another copy in Applications. Quit the old process before reopening the new build.

If the whole process exits, include the matching macOS crash report when reporting the bug. Review it for private paths and other personal information first.

## The model takes time to load

First setup needs internet to download a model and tokenizer. Cached Tiny and Base models skip an extra prewarming pass; larger models retain it to limit peak memory during preparation. Core ML may rebuild its device-specific cache after system changes.

A full quit unloads the model. Closing the window keeps the menu-bar app running and the model in memory. The app log includes the measured model-load time. Performance varies by Mac and model.

## “Microphone unavailable” or no words appear

Check the Microphone permission and input device. The app prefers a built-in mic, then another non-Bluetooth input where possible. Reconnect a missing device and retry. A Bluetooth microphone can change the headset's audio mode while recording.

Speak for more than a brief tap, in a reasonably quiet environment. Silence can produce an empty result. If the recording still fails, note the microphone name, Mac model, macOS version, and error message.

## Text doesn't land in the other app

Focus a normal editable text field before recording. Accessibility must be enabled. Some secure fields or apps don't accept simulated insertion. You can copy the completed transcript from **History** and paste it yourself.

The clipboard fallback can interact with clipboard managers. “Landed” is used for confirmed Accessibility insertion. The clipboard fallback says “Paste sent” because the app cannot prove the destination accepted that shortcut. The destination app is captured when recording stops, so switching apps while transcription finishes does not silently change the target.

## AI polish is unavailable

Basic dictation and rule-based cleanup do not require Apple Intelligence. Optional AI polish needs macOS 26+, a compatible device, Apple Intelligence enabled, and the system model available. Leave it off for the shortest processing path.

## Report a reproducible issue

Include the app version, Mac model, macOS version, selected speech model, microphone, destination app, and exact steps. A short recording using non-sensitive sample text is useful. Please redact transcript text from diagnostics. [Open a bug report](https://github.com/dhirajcdry/justwisper/issues/new?template=bug_report.yml).
