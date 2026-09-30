# Roadmap

The priority is a dictation loop people can trust. These are priorities, not delivery dates or claims that work is already complete.

## Before a broad launch

- Complete fresh-install testing on another Apple Silicon Mac, including download, permissions, hold/double-tap, cancellation, and insertion.
- Validate the oldest supported macOS version and the current release with real hardware.
- Add a Developer ID signing and Apple notarization path for downloads with less first-launch friction.
- Exercise sleep/wake, disconnected microphones, Bluetooth devices, and long dictations.

## Next reliability work

- Broader regression coverage for the recording/transcribing/inserting state transitions.
- Better recovery when model files or a tokenizer cache are incomplete.
- Clearer control over model download progress and retry/cancellation.
- Additional target-app and multilingual test cases.

## Improvements to evaluate with users

- Configurable shortcuts and an explicit microphone selector.
- A clearer first-run trial using non-sensitive sample text.
- Optional retention controls and export for local history.
- Measured latency/memory comparisons across models and Apple Silicon generations.

Small contributions with reproducible evidence are especially useful. See [Contributing](CONTRIBUTING.md). Request a feature by explaining the workflow it would improve; avoid assuming an item on this page will ship on a particular date.
