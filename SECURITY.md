# Security

For a suspected vulnerability, use [GitHub's private vulnerability report](https://github.com/dhirajcdry/justwisper/security/advisories/new) when private reporting is enabled. Maintainers should enable it before the public launch.

If that option is unavailable, open an issue asking for a private reporting channel **without exploit details or sensitive data**. Don't publish credentials, signing keys, personal audio, transcript history, or unredacted diagnostics.

Include the affected version, impact, and minimal non-sensitive reproduction steps in the private report. Fixes focus on the current source and latest release; there is no guaranteed response time or supported older-version branch yet.

## Developer hygiene

- Keep `.signing/`, keychains, certificates with private keys, and local environment files out of Git.
- Never add a real transcript or microphone recording as a test fixture.
- Use the checked-in dependency lockfile; review version updates and their test results.
- Release checks should scan both Git history and the files being added. A scanner finding no matches does not prove an absence of all sensitive data.
- Commit names/emails are public metadata when the repository becomes public. Use your preferred attribution intentionally.

The optional local signing helper is for development only. It creates a self-signed identity, not an Apple Developer ID. Current setups use a random local password stored in the ignored `.signing/` directory and limit the private-key application ACL to codesign. Older helper versions used a shared development keychain password; rotate that local keychain's password in Keychain Access before relying on it, and store the updated password locally if using automatic unlock. Never post the password in an issue.
