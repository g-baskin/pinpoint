# Changelog

All notable changes to Pinpoint are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Project docs now live in one place, the [`library/`](library/) folder: the glossary is at `library/knowledge/private/glossary/glossary.md` and the decision records are in `library/knowledge/private/architecture/`. The app itself is unchanged.
- `scripts/check.sh` runs every check in one go: a build that treats warnings as errors, the tests, shellcheck and a swift-format style report.

### Fixed

- ChatGPT sign-in no longer shares state unsafely between threads while it waits for the browser callback or refreshes a token.
- Reading microphone names for built-in dictation no longer passes an unsafe pointer to CoreAudio.

## [0.1.0] - 2026-11-27

The first public release of Pinpoint: a native macOS screenshot and markup app with a built-in AI agent. Requires macOS 14 or later. There is no prebuilt download yet: build it from source with `scripts/build-app.sh`.

### Added

- **Four ways to capture:** an area or a clicked window (⌃⇧1), a clean window capture that includes parts hidden behind other windows (⌃⇧2), the screen under the mouse (⌃⇧3) or all screens at once (⌃⇧4).
- **Markup tools,** each on a single key: arrows, lines, rectangles, ellipses, text, callouts, highlights, numbered steps, voice-note pins, blur, black-box redaction and crop. Hold Shift for squares and 45° lines.
- **Auto-redact** finds emails, API keys and secrets, account IDs, phone numbers, card numbers, IP addresses, SSNs, faces and words you choose, then covers them for you. It runs entirely on your Mac, with no AI or internet needed.
- **AI agent:** type a request such as "point an arrow at the Save button" or "blur the faces" and the agent edits the image. It can add and remove markup, mark text, redact, crop, and name and tag the capture. Each agent run undoes in a single step.
- **Assistant panel** with auto-redact, copy text from the screenshot (on-device OCR), summarize, and name and tag.
- **Choice of AI provider:** ChatGPT (sign in with your plan, no API key), ChatGPT through the Codex CLI, Anthropic (Claude), OpenAI API, OpenRouter, Google Gemini, Ollama (local, no key) or any OpenAI-compatible server such as LM Studio. Keys are stored in the macOS Keychain, and **Fetch models** and **Test connection** help you pick a working model.
- **Library** of every capture in `~/Pictures/Pinpoint/`, searchable by name, tag and the text inside the screenshot.
- **Guides:** ⌘-click captures in order and choose **Make Guide** to get a step-by-step `guide.md` and `guide.html` with images.
- **Handoff:** copy or export a capture together with its notes, ready to paste to a coding agent or a teammate. Export as PNG, JPEG or HEIC.
- **One-window layout** with tools along the top, a Properties and Assistant sidebar, and recent captures along the bottom. Pinpoint keeps running in the menu bar when the window is closed.
- `scripts/setup-signing.sh` creates a local signing certificate so macOS keeps the Screen Recording permission across rebuilds.
- A project glossary and decision records explaining key choices, such as where your data is stored and why the licence is Apache 2.0.

### Changed

- The app is named Pinpoint everywhere.
- Where your data lives is fixed so future updates find it: settings under the bundle id `app.pinpoint.Pinpoint`, saved keys and ChatGPT sign-in under the Keychain service `app.pinpoint.apikeys`, and captures in `~/Pictures/Pinpoint`.
- Pinpoint is licensed under the Apache License 2.0. If you redistribute or build on it, keep the `NOTICE` file and mark the files you changed.
- The README is rewritten around what Pinpoint does, how to install it, shortcuts, AI providers and how to contribute.

<!-- No git tags exist yet. When v0.1.0 is tagged, link [0.1.0] to
     https://github.com/g-baskin/pinpoint/releases/tag/v0.1.0 and change
     [Unreleased] to compare/v0.1.0...dev. -->
[Unreleased]: https://github.com/g-baskin/pinpoint/compare/main...dev
[0.1.0]: https://github.com/g-baskin/pinpoint/tree/main
