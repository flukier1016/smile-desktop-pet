# Security Policy

## Supported versions

Only the latest published release receives security fixes.

| Version | Supported |
| --- | --- |
| 1.3.x | Yes |
| 1.2.x and earlier | No |

## Report a vulnerability privately

Do not open a public Issue for a suspected vulnerability, exposed credential,
private screenshot, or other sensitive material.

Use the repository's
[private vulnerability reporting form](../../security/advisories/new). Include:

- affected version and macOS version;
- clear reproduction steps;
- expected and observed behavior;
- impact and any suggested mitigation;
- only the minimum redacted evidence needed to reproduce.

The maintainer aims to acknowledge a report within 72 hours, provide an initial
assessment within 7 days, and coordinate a fix and disclosure timeline with the
reporter. These are best-effort targets for a volunteer project.

## Security and privacy model

Smile Desktop Pet is intentionally local-first:

- it contains no network client, analytics SDK, advertising SDK, or updater;
- default awareness reads only the frontmost app name and bundle identifier;
- optional local OCR requests macOS screen-recording permission only after the
  user enables it;
- OCR captures only the frontmost window, processes it in memory with Apple
  Vision, and does not save screenshots or recognized text;
- settings are stored locally in macOS `UserDefaults`.

The repository's security check fails if application sources add common network
APIs or if tracked files resemble credentials, private keys, provisioning
profiles, environment files, or source photographs. Any future networking,
telemetry, storage, or permission expansion must be reviewed, documented in
`PRIVACY.md`, and called out in release notes.

## Supply chain

GitHub Actions are pinned to full commit SHAs. Dependabot monitors action
updates, CodeQL analyzes Swift changes, and releases publish SHA-256 checksums.
The current app is ad-hoc signed and is not Apple-notarized; users should
download only from this repository's official Releases page.
