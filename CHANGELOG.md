# Changelog

All notable changes to Pinpoint are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions go up by the size of the release: small changes add 1 to the last number (0.2.1 → 0.2.2), medium ones jump it to 5 or on to the next 0.x.0 (0.2.3 → 0.2.5 → 0.3.0), and big ones go to the next 0.x.0 (0.3.0 → 0.4.0).

## [Unreleased]

### Changed

- Pinpoint's messages no longer name other apps. Copy File Path now says "Paste it into your coding CLI", its Handoff menu item reads **Copy file path (for a coding CLI)**, and the "port 1455 is busy" sign-in error says another app may have a sign-in open.

## [0.2.1] - 2026-11-27

Adds **Copy File Path**, so a coding CLI in the terminal can open a capture. Download `Pinpoint-0.2.1.zip` from the release page and install it over 0.2.0; your permission, settings, keys and captures carry over.

### Added

- **Copy File Path.** Right-click a capture in the Library or the recent-captures strip, or open the editor's **Handoff** menu, and choose **Copy File Path** to copy where the image is saved as text. Paste it into your coding CLI so it can open the image. The editor saves your markup first, so the path points at the marked-up version.

### Tests

- The library test now checks which file is shared: the marked-up image once saved, otherwise the original.

## [0.2.0] - 2026-11-27

Adds scrolling capture: grab a whole sidebar or long page in one image by scrolling through it. Errors that used to fail silently now tell you what went wrong. Requires macOS 14 or later; download `Pinpoint-0.2.0.zip` from the release page (Apple silicon and Intel). It is still not notarized, so the first launch needs **Open Anyway** in System Settings → Privacy & Security; installing over 0.1.0 keeps your Screen Recording permission, settings, keys and captures.

### Added

- **Scrolling capture.** Press ⌃⇧5 (or choose **Scrolling Capture** from the menu bar icon or the File menu, **Scrolling** from the Capture button's menu in the Pinpoint window, or press S or click **Scrolling (S)** in the capture overlay), pick the part that scrolls by clicking a panel such as a web page's sidebar or dragging an area, then scroll down through it from the top at your own pace. Pinpoint follows along and stitches it into one tall image, and headers and footers that stay put appear only once. Click **Done** (or press ⌃⇧5 again) to open it in the editor. No extra macOS permission is needed. If you scroll too fast, Pinpoint tells you; scroll back a little to carry on.

### Fixed

- **Errors no longer fail silently.** Deleting captures, saving an API key, signing in with ChatGPT, opening image files, sharing, saving name and tag changes, Auto-name and Restart Pinpoint now say when something goes wrong instead of carrying on or reporting success. Background naming and OCR failures are written to the system log.
- **Guides can't carry script links.** `guide.html` now escapes quotes and only turns relative, web and mailto addresses into links or images, so text from the AI can't add `javascript:` links or extra HTML attributes.

### Changed

- **Text in tall images is read in strips.** Very tall images, such as scrolling captures, are now read for text in overlapping strips, so search, naming and auto-redact still find small text near the bottom.
- The empty editor and the canvas now share one background colour constant, so their dark grey always matches.

### Removed

- Two unused properties: `JSONValue.objectValue` and `SpeechDictation.isAuthorized`.

### Tests

- Added tests for provider network calls and HTTP error messages, deleting a capture, the agent's step limit and error exits, and safe guide HTML.
- Added tests for stitching scrolled frames with a sticky header and footer, scrolling back, losing and regaining track, a single frame, the size limit and narrow regions, plus reading text in tall images without duplicates.

## [0.1.0] - 2026-11-27

The first public release of Pinpoint: a native macOS screenshot and markup app with a built-in AI agent. Requires macOS 14 or later. Download `Pinpoint-0.1.0.zip` from the release page (it runs on Apple silicon and Intel Macs). It is not notarized by Apple yet, so the first launch needs **Open Anyway** in System Settings → Privacy & Security; the README has the steps.

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
- A bullseye app icon, plus a README banner and a social preview image in `assets/`, all drawn by `scripts/make-icon.swift`.
- A downloadable universal app: `scripts/release.sh` builds it, zips it and writes a SHA-256 checksum for each release.
- `scripts/check.sh` runs every check in one go: a build that treats warnings as errors, the tests, shellcheck and a swift-format style report.

### Changed

- The app is named Pinpoint everywhere.
- Where your data lives is fixed so future updates find it: settings under the bundle id `app.pinpoint.Pinpoint`, saved keys and ChatGPT sign-in under the Keychain service `app.pinpoint.apikeys`, and captures in `~/Pictures/Pinpoint`.
- Pinpoint is licensed under the Apache License 2.0. If you redistribute or build on it, keep the `NOTICE` file and mark the files you changed.
- The README is rewritten around what Pinpoint does, how to install it, shortcuts, AI providers and how to contribute.
- Project docs live in one place, the [`library/`](library/) folder, including the glossary and the decision records.

### Fixed

- ChatGPT sign-in no longer shares state unsafely between threads while it waits for the browser callback or refreshes a token.
- Reading microphone names for built-in dictation no longer passes an unsafe pointer to CoreAudio.

[Unreleased]: https://github.com/g-baskin/pinpoint/compare/v0.2.1...dev
[0.2.1]: https://github.com/g-baskin/pinpoint/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/g-baskin/pinpoint/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/g-baskin/pinpoint/releases/tag/v0.1.0
