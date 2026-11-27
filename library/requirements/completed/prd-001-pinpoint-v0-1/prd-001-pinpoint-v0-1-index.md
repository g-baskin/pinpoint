# PRD-001: Pinpoint v0.1 *(Retroactive)*

> **Status:** Shipped
> **Priority:** - *(retroactive, work is done)*
> **Effort:** - *(retroactive)*
> **Schema changes:** None *(documents the existing `meta.json` format)*
> **Written:** November 2026
> **Retroactive:** Yes. This PRD was written after implementation, by reading the source at commit `66349de41a4f434dabe6063cce8822e494594709`. "Shipped" means the code exists on `dev`; no release date or download numbers are recorded here.

---

## What was built

Pinpoint is a native macOS app (Swift Package Manager, macOS 14+, `Package.swift`) that captures the screen, lets the user mark up the capture, hides sensitive information on-device, and can ask an AI model to do the markup from a plain-English request. Every capture is kept in a local library, can be turned into a step-by-step guide, and can be handed to a coding agent or a teammate as text plus image.

The version string is `0.1.0` (`CFBundleShortVersionString` in `Resources/Info.plist`).

The code is split into two targets (`Package.swift`):

- `PinpointCore` (`Sources/PinpointCore/`): data model, rendering, on-device analysis, AI clients and the agent. Unit-tested in `Tests/PinpointCoreTests/`.
- `Pinpoint` (`Sources/Pinpoint/`): the AppKit and SwiftUI app: capture, overlay, editor window, library view, settings, dictation. No tests.

The app runs from the menu bar and shows in the Dock only while a window is open (`AppDelegate.updateActivationPolicy`, `Sources/Pinpoint/AppDelegate.swift:287-296`). One main window holds the editor, the library and a recent-captures tray (`Sources/Pinpoint/MainWindow.swift:5`).

---

## Goals (as built)

- Capture an area, a window, the screen under the mouse, or all screens from global shortcuts.
- Mark up a capture with 11 markup kinds plus select and crop, with undo.
- Find and hide emails, keys, IDs, phone and card numbers, IPs, SSNs, faces and user-chosen words without any network call.
- Let an AI model edit the capture by calling a fixed set of tools, using any of 8 provider types.
- Keep every capture searchable on disk, and build guides from several captures.
- Turn one capture's notes into text a coding agent can act on.

## Non-Goals (not present in the code)

- No cloud sync, accounts or sharing service of Pinpoint's own. Data stays in `~/Pictures/Pinpoint/` (`Sources/PinpointCore/Library.swift:36-38`); sharing uses the macOS share sheet (`Sources/Pinpoint/MainWindow.swift:156`).
- No screen video recording. Capture produces still images only (`Sources/Pinpoint/CaptureService.swift`).
- No user-configurable shortcuts. The five global shortcuts are fixed in code (`Sources/Pinpoint/AppDelegate.swift:26-30`).
- No tests for the app target.

---

## Sub-features

| Sub-PRD | Scope | Status |
|---|---|---|
| [`prd-001a-pinpoint-v0-1-capture`](./prd-001a-pinpoint-v0-1-capture.md) | Shortcuts, capture modes, selection overlay, smart panel selection, permission handling | Shipped |
| [`prd-001b-pinpoint-v0-1-markup-editor`](./prd-001b-pinpoint-v0-1-markup-editor.md) | Tools, markup kinds, styles, voice notes, undo, save, copy, export | Shipped |
| [`prd-001c-pinpoint-v0-1-auto-redact-analysis`](./prd-001c-pinpoint-v0-1-auto-redact-analysis.md) | On-device OCR, sensitive-text patterns, face detection, auto-redact | Shipped |
| [`prd-001d-pinpoint-v0-1-ai-agent-providers`](./prd-001d-pinpoint-v0-1-ai-agent-providers.md) | Provider catalogue, ChatGPT sign-in, Codex CLI, assistants, the edit agent | Shipped |
| [`prd-001e-pinpoint-v0-1-library-guides`](./prd-001e-pinpoint-v0-1-library-guides.md) | Folder-per-capture storage, search, background naming, guides | Shipped |
| [`prd-001f-pinpoint-v0-1-handoff`](./prd-001f-pinpoint-v0-1-handoff.md) | Handoff text, handoff folder export, notes panel image | Shipped |

---

## Source workflow and evidence

**Reader and outcome:** contributors who need to know what v0.1 does before changing it.
**Template origin:** `~/.gg/skills/library-stinger/templates/prd-template.md` with the backwards-PRD header from `guides/05-backwards-prd.md`.
**Source identity:** this repository, commit `66349de41a4f434dabe6063cce8822e494594709`. `Sources/` and `Tests/` had no uncommitted changes when read.
**Adaptations and assumptions:** acceptance criteria describe behaviour read from the code. They were not run by hand.
**Maintenance owner and review triggers:** repository owner. Review when a capture mode, markup kind, provider, agent tool or stored-data format changes.

| Claim or criterion | Status | Source or result locator | Subject revision | Observed date | Verification owner |
|---|---|---|---|---|---|
| Behaviour in this PRD and its sub-PRDs | SOURCE_OBSERVED | file paths cited in each section | `66349de` | 2026-11-27 | owner |
| Unit tests cover the `PinpointCore` parts | SOURCE_OBSERVED (test classes exist); EXECUTION NOT_RUN for this PRD | `Tests/PinpointCoreTests/*.swift` | `66349de` | NOT_RUN | owner |
| App-target behaviour (overlay, editor, settings) works end to end | NOT_RUN | no automated tests for `Sources/Pinpoint` | `66349de` | NOT_RUN | owner |

---

## Acceptance criteria

Module-level. Each sub-PRD has its own.

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | Pinpoint is running with Screen Recording permission | the user presses ⌃⇧1 to ⌃⇧4 | a capture is saved to the library and, by default, opened in the editor and copied to the clipboard (`Sources/Pinpoint/AppDelegate.swift:174-188`, defaults in `Sources/Pinpoint/AppSettings.swift:49-50`) |
| AC-2 | a capture is open | the user draws markup and saves | `meta.json`, `rendered.png` and `thumb.jpg` are written in the capture's folder (`Sources/PinpointCore/Library.swift:67-76`) |
| AC-3 | no AI provider is set up | the user runs auto-redact or copy text | it works, because analysis uses Apple Vision on the Mac (`Sources/PinpointCore/Analyzer.swift:18-54`) |
| AC-4 | an AI provider is set up | the user types an instruction for the agent | the model's tool calls change the markup, and the whole run undoes in one step (`Sources/Pinpoint/EditorModel.swift:331-358`) |
| AC-5 | a capture has notes | the user chooses Handoff | Markdown with numbered notes and the image path is copied or exported (`Sources/Pinpoint/EditorModel.swift:97-127`) |

---

## Definition of Done checklist

- Inherits [Definition of Done revision 1](../../../knowledge/private/standards/definition-of-done.md) (Draft until the owner approves it). For this retroactive PRD the items describe the bar future changes to these features must meet.
- Any change to the stored formats in prd-001e follows [ADR-1](../../../knowledge/private/architecture/ADR-1-library-folder-per-capture.md) and [ADR-2](../../../knowledge/private/architecture/ADR-2-stored-data-identifiers.md).

---

## Data model (as built)

`CaptureMeta` (`Sources/PinpointCore/Library.swift:6-28`), saved as pretty-printed, key-sorted JSON with ISO 8601 dates (`Library.swift:51-54`): `id`, `created`, `modified`, `name`, `tags`, `ocrText`, `summary`, `sourceApp`, `width`, `height`, `annotations`, `crop`, `aiNamed`.

`Annotation` (`Sources/PinpointCore/Annotation.swift:44-66`): `id`, `kind`, `start`, `end`, `color` (`RGBA`), `lineWidth`, `text`, `fontSize`, `fillColor`, `shadow`, `note`. Coordinates are image pixels, origin top-left.

## Interfaces (as built)

No network API of its own. Outbound calls go only to the AI provider the user picks (see prd-001d). The internal seam between the app and AI providers is the `LLMClient` protocol (`Sources/PinpointCore/LLM.swift:51-53`).

---

## Contract dependencies

- None; no shared boundary identified. Pinpoint is one repository with no separate service.

---

## Open questions

Points the code leaves unclear. None of them block anything.

- [ ] `ChatGPTPlanClient` sends `User-Agent: Pinpoint/0.3 (macOS)` (`Sources/PinpointCore/ChatGPTPlan.swift:468`), but `Resources/Info.plist` says version `0.1.0`. Which is intended?
- [ ] Agent changes to name and tags are applied outside the single undo checkpoint (`Sources/Pinpoint/EditorModel.swift:353-355`; the checkpoint is at line 349). Undo restores markup and crop but not the name. Is that intended?

---

## Related

- [Glossary](../../../knowledge/private/glossary/glossary.md)
- [ADR index](../../../knowledge/private/architecture/README.md): ADR-1 library layout, ADR-2 stored-data identifiers, ADR-3 ChatGPT registration name, ADR-4 licence, ADR-5 branches
- [Definition of Done](../../../knowledge/private/standards/definition-of-done.md)
