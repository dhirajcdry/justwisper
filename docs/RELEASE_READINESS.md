# Public beta readiness

Review date: 2026-09-30. This file records evidence and remaining checks; it is not a claim that every supported Mac or app has been tested.

## Repository and privacy

- The old v0.1 DMG was inspected separately. It contains no runtime history/audio or signing-key files, but its executable embeds one local user-home build path. That legacy release is now a private draft; the rebuilt 0.2.0 package is the public beta download.
- The maintainer chose to retain the existing commit name and email attribution. GitHub links and the project attribution are intentional public information.
- The seven existing commits and the candidate public files were scanned with Gitleaks 8.30.1. No matches were found. This is one check, not proof that every possible sensitive string is absent.
- The public screenshots use isolated fictional fixtures. Their EXIF metadata contains image dimensions/resolution, not personal location data.
- Resume/job-search documents, real transcript history, audio recordings, developer keychains, private keys, and local build directories are not part of the candidate Git files.
- Current transcript logging records word counts/timings instead of intentionally logging the text. Older versions and old system logs can contain transcript text.
- Current development signing scripts no longer embed a shared password, grant all applications access to a key, or replace an existing keychain. Existing legacy signing setups need their own local password review; changing the script does not rotate an already-created keychain.

## Automated evidence

- The local Swift regression suite passes, including clipboard restoration and newer-copy protection.
- The opt-in cached-model test passes using the Base model.
- The opt-in speech test recognizes a phrase generated locally by macOS speech synthesis. It does not record the microphone or test cross-app insertion.
- The website was checked at desktop/mobile sizes for missing assets, horizontal overflow, browser errors, overlay selection, FAQ opening, and demo playback/replay.
- Local documentation and asset links pass `python3 scripts/check-site.py`.
- The package script produces an Apple Silicon DMG and SHA-256 checksum. A release needs fresh verification after any source change.

The [clean GitHub CI run](https://github.com/dhirajcdry/justwisper/actions/runs/36768423543) passed dependency resolution, Swift tests, a release build, and documentation/asset checks for commit `1a8f57e`. CI selects Xcode 26.2 explicitly because the locked dependencies need Swift 6.2+. This validates that toolchain; it does not validate all runtime OS versions or real-device interactions.

## Required human beta checks

Use a new installation on another Apple Silicon Mac if possible, with fictional text:

- [ ] Download the release DMG through a browser and complete the actual Gatekeeper flow.
- [ ] First-run microphone/Accessibility permissions, including deny → later grant.
- [ ] Initial model/tokenizer download and a later offline relaunch.
- [ ] Hold-to-talk, quick double-tap hands-free, stop tap, Esc, and Undo.
- [ ] Insertion into Notes, a browser text field, and another everyday app.
- [ ] Switch apps while transcription finishes; confirm the original destination is used or a safe failure is shown.
- [ ] Copy new text while a paste is finishing; confirm the newer clipboard is retained.
- [ ] Sleep/wake, microphone disconnect/reconnect, and at least one longer recording.
- [ ] A check on the oldest supported macOS version before presenting that range as broadly validated.

Record the Mac, OS, app/model version, and result. Until these are complete, describe the download as an **early public beta** and invite reproducible reports.

## Distribution and launch

The current community package is ad-hoc signed and not notarized. A Developer ID signing/notarization path is recommended before a broad nontechnical launch. It requires the maintainer's Apple Developer setup; a self-signed local identity is not a substitute. See [Apple's distribution guidance](https://developer.apple.com/developer-id/).

Before announcing:

- [x] The tested release branch is on `main`.
- [x] Published 0.2.0 as a prerelease with known limitations; downloaded the public asset without authentication and verified its checksum.
- [x] Made the repository public after the privacy review and enabled private vulnerability reporting.
- [x] Deployed Pages at https://dhirajcdry.github.io/justwisper/ and verified the live site, high-resolution images, mobile layout, and public download.
- [x] Set the repository description, topics, and website. The site includes its high-resolution social preview.
- [ ] Optionally upload `site/assets/social-card.png` as GitHub's repository social preview in Settings.
- [ ] Invite a small beta group, respond to their setup problems, then share more widely.

Support instructions, issue forms, contribution guidance, a roadmap, community conduct, licensing notices, and dependency update configuration are already in the repository. Popularity is not guaranteed; a reliable first experience and useful responses to early users are the next priorities.
