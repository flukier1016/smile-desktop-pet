<div align="center">

<img src="docs/media/hero.png" alt="Smile Desktop Pet" width="100%">

<img src="docs/media/app-icon.png" alt="Smile Desktop Pet character app icon" width="112">

# Smile Desktop Pet

**A playful, context-aware desktop companion that grows with you on macOS.**

[Download](../../releases/latest) · [Chinese README](README.md) · [User guide](MANUAL.md) · [Contributing](CONTRIBUTING.md)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&logo=apple)
![Universal](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-c4473d?style=flat-square)
![Offline](https://img.shields.io/badge/privacy-100%25%20local-2f8f78?style=flat-square)

</div>

Smile lives above your desktop without taking a Dock slot. She reacts to clicks,
remembers her position and size, and automatically switches between 23 scenes
such as coding, debugging, tests passing, spreadsheets, markets, meetings,
reading, entertainment, breaks, and late-night work. Four small daily care
actions build experience, a companion streak, and five relationship levels.

## Highlights

- Native Swift/AppKit app for macOS 13 and later.
- Universal binary for Apple Silicon and Intel.
- Companion-first control center with daily care, XP, streaks, and direct interactions.
- Separate settings page for size, awareness, local OCR, refresh cadence, and privacy state.
- Foreground-app awareness works without screen-recording permission.
- Optional OCR examines only the frontmost window using Apple Vision.
- No accounts, ads, analytics, telemetry, screenshot storage, or network requests.
- Keyboard navigation, VoiceOver semantics, and Reduce Motion support.
- Includes an optional warm cream/red Codex theme and 88-frame custom Codex pet.

## Install

Download `SmilePet-v1.4.1-macos-universal.dmg` from the
[latest release](../../releases/latest), drag the app to Applications, then
Control-click it and choose **Open** on first launch.

The current release is ad-hoc signed and not notarized. Download only from this
repository and verify the files with `SHA256SUMS.txt`.

## Build

```bash
xcode-select --install
git clone https://github.com/flukier1016/smile-desktop-pet.git
cd smile-desktop-pet
./scripts/security-check.sh
./scripts/test.sh
./build.sh
```

## Privacy

The default classifier reads only the frontmost application name and bundle
identifier. Optional OCR captures one frontmost window, recognizes text in
memory, and immediately discards the image and text. Companion progress is
stored only in local macOS preferences. See [PRIVACY.md](PRIVACY.md).

## Codex skin

The optional skin applies an 88-frame Smile mascot, matching light and dark
chrome colors, and Rosé Pine code themes through Codex's supported custom
configuration. It does not modify or re-sign the official Codex app.

```bash
./scripts/install-codex-skin.sh
```

The installer validates the format and creates a restorable configuration
backup. See [CodexSkin/README.md](CodexSkin/README.md).

## License

Source code, documentation, and build tools are MIT licensed. Character art,
icons, the Codex sprite sheet, and derivatives are separately reserved; see
[ASSET_NOTICE.md](ASSET_NOTICE.md). Replace the artwork, bundle identifier, and
product name when creating a code-based fork.

Bug reports and feature ideas are welcome through [Issues](../../issues).
Please report vulnerabilities privately through
[GitHub Security Advisories](../../security/advisories/new).
