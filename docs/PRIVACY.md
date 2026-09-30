# Privacy and local storage

This describes the current implementation, not a guarantee about other applications or services on your Mac.

## Audio and transcription

Microphone audio is collected while recording, converted to 16 kHz mono samples, and held in memory. WhisperKit runs speech recognition locally through Core ML. The app does not intentionally write captured microphone audio to a recording file. A cancelled take can be held briefly in memory for Undo.

Live previews use a recent audio window to limit repeated inference work. Final transcription uses the complete captured take. Optional AI polish uses Apple's on-device Foundation Models when available; it is off by default.

## Network use

The first setup of a speech model downloads model files from the upstream WhisperKit model repository and tokenizer files from Hugging Face. Choosing another uncached model needs another download. Those requests expose ordinary network metadata to the hosting services. Audio is not uploaded by the dictation pipeline.

Cached models and tokenizer files are reused. After setup, speech recognition can run offline. The app has no account system, app analytics, or telemetry endpoint. External links opened from help/documentation use your browser.

## What stays on disk

Files under `~/Library/Application Support/Wispr/` include:

| File or folder | Contents |
| --- | --- |
| `history.json` | Completed transcripts, date, duration, latency, and destination app name; persisted history is capped at 5,000 entries |
| `dictionary.json` | Your spoken-to-written vocabulary mappings |
| `snippets.json` | Spoken triggers and their saved expansions |
| `appstyles.json` | Per-app formatting preferences |
| `Models/` | Downloaded speech models and the app-managed `Tokenizers/` cache |

Other preferences use macOS UserDefaults for `com.justwisper.app`. Core ML and dependency libraries may keep additional system-managed caches. An older version may have downloaded tokenizers under `~/Documents/huggingface/`; current builds use the app's Application Support folder.

History is ordinary local JSON, not app-level encrypted storage. Its protection depends on your macOS account, disk security, and backups. **Insights → Erase History** removes the app's persisted history; it does not erase text already inserted into other apps, system logs, clipboard-manager history, or backups. Quit before manually removing other local data.

## Permissions and insertion

- **Microphone:** captures audio for a dictation.
- **Accessibility:** supports the global shortcut and text insertion into another app.

The app tracks the most recently active external app to choose an insertion target. It first tries Accessibility insertion. The fallback temporarily puts the transcript on the system clipboard and posts a paste shortcut. The app snapshots readable clipboard items and their formats before replacing them, then restores them only if nothing else has been copied in the meantime. If it cannot safely snapshot the clipboard, insertion fails without replacing it. Clipboard managers may retain the transcript.

Once text is inserted, the destination app's storage, sync, and privacy behavior apply.

## Logs and reports

Current builds intentionally log word counts and timings rather than transcript text. Earlier builds logged completed transcripts. Errors, model names, and destination app names can still appear in diagnostics. Its in-app log is bounded, but macOS may also retain diagnostic output. Review and redact logs or screenshots before attaching them to a public issue.

Repository screenshots use fictional fixtures in an isolated preview model. They never read the author's dictation history. See [asset generation](ASSETS.md).
