# Changelog

## 0.2.0 — prepared for release

### Reliability

- Interpret Right Option using the right-hand modifier bit and physical event timestamps.
- Cover double-tap, hold, duplicate events, delayed timers, and reset/stop behavior with regression tests.
- Move microphone configuration off the main thread; surface startup and runtime capture errors.
- Keep stale capture callbacks out of later takes.
- Serialize shared WhisperKit pipeline work across asynchronous calls.

- Preserve rich clipboard contents and newer user copies during paste fallback.
- Capture the destination when recording stops and distinguish confirmed insertion from an unverified paste request.
- Stop intentionally writing complete transcripts to diagnostics.

### Startup and performance

- Load complete cached models directly instead of entering the download lookup on every launch.
- Store tokenizer files under Application Support rather than the default Documents cache.
- Persist the selected model and log its load time.
- Skip the extra prewarming pass for cached Tiny, Base, and Small models.
- Bound live preview work to recent audio, with cheaper preview decoding; preserve full-take final transcription.

- Default to Small and retain the user’s selected model across launches.
- Cache history word counts and avoid redraws for unchanged microphone permissions.
- Limit UI metering to about 17 updates per second without reducing recorded audio.
- Keep focus tracking and overlay dismissal on the main actor.

### Local installation

- Install builds into `/Applications/justwisper.app`, replacing the prior version after signing succeeds.
- Use password-free ad-hoc signing by default; stable signing remains an explicit option.
- Clean up temporary app bundles after builds and release packaging.

### Project and presentation

- New screenshot-led README and responsive static landing page.
- Actual SwiftUI screenshots with isolated fictional fixtures; an illustrated shortcut walkthrough.
- Privacy, troubleshooting, release, contribution, and asset-generation documentation.
- CI, issue forms, a PR template, and manual Pages deployment workflow.
- Bundled font attribution and license files.

## 0.1 — 2026-07-04

Initial packaged release with local dictation, Right Option gestures, transcript history, custom vocabulary, snippets, and four floating overlay styles.
