# Release and website guide

## Current prepared version

The working tree prepares **0.2.0** with the reliability/startup fixes and public project materials. The existing published tag is **v0.1**. A newly built local DMG does not update that release automatically.

## Validate and package

1. Check [release readiness](RELEASE_READINESS.md), then review changes, including the README, screenshots, privacy claims, and changelog. Confirm screenshots contain only the documented fixtures.
2. Run `swift test` and `swift build -c release` on macOS.
3. If the Base model is already cached, run `WISPR_MODEL_SMOKE=1 swift test --filter EngineSmokeTests` for real local model loading and inference. The smoke test uses synthetic silence, never the microphone.
4. Check a real hold-to-talk and hands-free dictation into a normal text field. Include a cancellation/undo and a failed-permission path. Automated tests do not replace this hardware check.
5. Set the version/build number in `Resources/Info.plist`, then run `./package.sh`.
6. Verify `dist/SHA256SUMS` with `cd dist && shasum -a 256 -c SHA256SUMS`. Inspect/mount the DMG and confirm it includes the app and Applications shortcut.

`package.sh` creates an Apple Silicon release in `dist/`, leaving the locally signed development app untouched. The output is ad-hoc signed, not notarized. `./package.sh universal` exists as an experimental build option, but the public supported target is Apple Silicon.

## Publish a version

Create a reviewed commit before tagging. Attach **both** `justwisper-0.2.0.dmg` and `SHA256SUMS` to a release tagged `v0.2.0`. Use [the prepared release notes](RELEASE_NOTES_0.2.0.md), adjusting the wording if validation or scope changes.

Keep the release as a draft until the files, version, first-launch guidance, and checksum have been checked. Don't replace an existing release asset silently.

## Make the repository public

Repository visibility is separate from a release or website deployment. Making this repository public exposes its reachable Git history and published release assets. Commit author/committer names and email addresses are part of that history.

Before switching visibility, review tracked files and history for credentials, personal data, and signing material. Keep local certificates, build products, and application data ignored. Private development signing material should never be committed. Review the old v0.1 release as well as the new release.

Suggested repository description:

> Local voice dictation for macOS. Hold Right Option, speak, and insert your words. Native SwiftUI, WhisperKit, no account. MIT licensed.

Suggested topics: `macos`, `swift`, `swiftui`, `dictation`, `speech-to-text`, `whisperkit`, `on-device-ai`, `privacy`, `accessibility`, `open-source`.

Use `site/assets/social-card.png` as the GitHub social preview. Enable Issues. Consider enabling private vulnerability reporting before linking people to it. These settings are not changed merely by committing these files.

## Deploy the website

The static site is in `site/`. The prepared workflow runs **only when manually requested**; it does not publish on every commit.

1. In GitHub repository Settings → Pages, select **GitHub Actions** as the source.
2. Run **Deploy Pages** from Actions on the reviewed branch.
3. Check the resulting deployment and the mobile layout. The expected project URL is `https://dhirajcdry.github.io/justwisper/`.
4. Set the repository's Website field to the confirmed live URL. If using another domain, update social image URLs in `site/index.html` and configure DNS separately.

The landing page's Download buttons lead to the latest GitHub Release. Publish the intended release before announcing the site.

## Share it

Start with a small, concrete announcement: what problem it solves, a short visual, the install link, and the current limitations. Invite reports with Mac/model details. Avoid unmeasured “fastest” claims or suggesting that an illustrative demo is a live benchmark.

Useful first destinations are the repository's own README, your portfolio project section, and communities where local Mac utilities or open-source speech tools are on topic. Check each community's current self-promotion rules before posting. No outreach is sent by this release workflow.
