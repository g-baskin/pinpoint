# Pinpoint

Your own screenshot and markup tool for macOS, with a built-in AI agent. Native Swift, so it's fast and small. No subscription.

## Build & run

Requires macOS 14 or later and Swift 5.10 or later (Xcode, or Apple's Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/g-baskin/pinpoint.git
cd pinpoint
scripts/build-app.sh            # -> build/Pinpoint.app
open build/Pinpoint.app
scripts/build-app.sh --install  # optional: copies it to ~/Applications
swift test                      # core test suite
```

On first launch, macOS asks for **Screen Recording** permission (System Settings → Privacy & Security → Screen & System Audio Recording). Turn on Pinpoint, then quit and reopen it.
Ad-hoc signed builds can lose this permission when you rebuild. If captures stop working after a rebuild, toggle Pinpoint off and on again in that same settings pane.
To avoid that, run `scripts/setup-signing.sh` once: it creates a local signing certificate that `build-app.sh` then uses for every build.

## Using it

Pinpoint is one app with one window, like Snagit's editor. A Capture button sits at the top left, with the tools next to it. On the right is a sidebar with **Properties** (Quick Styles, colour, fill, width, size, shadow) and **Assistant** (AI) tabs. Along the bottom is a tray of recent captures with search and zoom (Fit / 100% / pinch). The **Editor / Library** switch at the top swaps the canvas for the full library grid.
Close the window and Pinpoint stays in the menu bar (camera icon), ready for the shortcuts.

| Shortcut | Action |
|---|---|
| ⌃⇧1 | Capture: drag an area, or click a window (Return = whole screen, Esc = cancel) |
| ⌃⇧2 | Capture a window cleanly (includes parts hidden behind other windows) |
| ⌃⇧3 | Capture the full screen under the mouse |
| ⌃⇧4 | Capture all screens |
| ⌃⇧L | Library |

**Editor tools** (press the letter key): V select/move, A arrow, L line, R rectangle, E ellipse, T text, O callout, H highlight, N numbered step, B blur, X black-box redact, C crop.
Hold Shift for squares and 45° lines. Drag the round handles to resize. Arrow keys nudge the selected item, Delete removes it, and double-click edits text.
⌘Z / ⇧⌘Z undo and redo, ⌘C copies the image, ⌘S saves to the library, ⇧⌘E exports PNG/JPEG/HEIC.

**Assistant panel**
- *Auto-redact*: finds emails, API keys, phone and card numbers, IPs, SSNs and faces on-device, then blurs or black-boxes them. No AI or internet needed.
- *Copy text*: on-device OCR copied to the clipboard.
- *Summarize* and *Name & tag*: uses your chosen AI.
- Prompt box: plain-English edits like "point an arrow at the Save button", "number the steps in the sidebar", "crop to the dialog" or "blur the faces". The agent sees the screenshot and the OCR text, then edits the image with tools. Each run can be undone in one step.

**Library**: every capture is saved in `~/Pictures/Pinpoint/<id>/` (original, annotated render, thumbnail, metadata).
You can search names, tags and the text inside screenshots. ⌘-click captures in order, then **Make Guide** writes a step-by-step guide (`guide.md` + `guide.html` + images) to `~/Pictures/Pinpoint/Guides/`.
**Auto-name** gives un-named captures AI names and tags.

## AI providers (Settings → AI provider)

ChatGPT (sign in with your plan, no API key), ChatGPT via the Codex CLI, Anthropic (Claude), OpenAI API, OpenRouter, Google Gemini, Ollama (local/offline, no key) or any other OpenAI-compatible server (LM Studio…).
Keys are stored in the macOS Keychain. Use **Fetch models** to pick from the provider's current list, and **Test connection** to check it works.
For agent edits, use a model that supports both images and tool calling.

## Architecture

```
Sources/PinpointCore  (no UI, unit-tested)
  Annotation.swift    markup model (image-pixel coords, top-left origin)
  Renderer.swift      draws markup for both the live canvas and exports
  Analyzer.swift      Apple Vision OCR, sensitive-text boxes, face detection
  Sensitive.swift     PII / secret patterns
  Library.swift       folder-per-capture store + search
  LLM.swift           provider-neutral chat + Anthropic and OpenAI-compatible clients
  Agent.swift         tool definitions, AgentToolbox (pure), EditAgent loop
  Assistants.swift    summarize / name & tag / guide writing, guide export, Keychain
Sources/Pinpoint      (AppKit + SwiftUI app)
  AppDelegate         menu bar, hotkeys, capture flow, windows
  CaptureService      ScreenCaptureKit screen/window capture
  SelectionOverlay    frozen-screen area/window picker
  CanvasView          drawing surface and editing interactions
  EditorModel/View    editor state, undo, assistant panel
  LibraryView, SettingsView
```

**Adding an agent tool:** add a `ToolSpec` to `AgentToolbox.tools`, handle it in `execute`, and add a test in `Tests/PinpointCoreTests`.
**Adding a markup kind:** add a case to `AnnotationKind`, draw it in `Renderer.draw`, and add a `Tool` case in `EditorModel.swift`.

Built from scratch on public Apple frameworks. It contains no TechSmith code or assets.

## License

Copyright 2026 AutomationGod. Licensed under the [Apache License 2.0](LICENSE).

If you redistribute Pinpoint or build on it, keep the [`NOTICE`](NOTICE) file crediting the original author, and mark the files you changed. Contributions are welcome: anything you submit is accepted under the same license (Apache 2.0, section 5).
