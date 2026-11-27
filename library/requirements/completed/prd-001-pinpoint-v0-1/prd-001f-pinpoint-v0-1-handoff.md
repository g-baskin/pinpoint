# PRD-001f: Handoff *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

A handoff turns one capture's notes and markup into text that a coding agent or a teammate can act on without seeing the editor (`Sources/PinpointCore/Handoff.swift:4`).

### Handoff text

`Handoff.markdown` (`Handoff.swift:45-66`) writes:

1. `## Screenshot: <name>`, the image path, the size in pixels and the source app.
2. `### Notes (numbers match the badges on the image)`: every item with a note, in badge order, as `N. <description>` followed by the note text, or "(no note)". If there are no notes it says "(No notes added.)".
3. `Other markup:` a one-line list of items without notes, leaving out blur and redact.
4. `Summary:` if the capture has one.

Each item is described by `Handoff.describe` (`Handoff.swift:7-28`): its kind ("Arrow pointing at", "Pin at", "Outlined area around", "Hidden area" and so on), the on-screen text it points at, its centre in pixels and, for boxes, its size. Callout and text labels are included.

The on-screen text comes from OCR (`Handoff.nearbyText`, `Handoff.swift:31-43`): up to 3 lines inside a box larger than 8×8 px, else the closest line within 120 px of the target point, each cut to 80 characters. The target is the arrow head for arrows, the pin for notes, steps and text, and the box for everything else (`Sources/PinpointCore/Annotation.swift:80-87`).

### Entry points

From the **Handoff** menu in the toolbar (`Sources/Pinpoint/MainWindow.swift:141-145`) and the notes list (`MainWindow.swift:457`):

- **Copy for AI agent (notes + image path)**: saves the capture first, so `rendered.png` exists, then copies the text with that file's path (`Sources/Pinpoint/EditorModel.swift:92-103`).
- **Export handoff folder…**: saves, asks for a parent folder, and writes `<name> handoff/` containing (`EditorModel.swift:106-126`):
  - `screenshot.png`: the flattened image
  - `screenshot-with-notes.png`: the same image with a notes panel underneath
  - `notes.md`: the handoff text with `screenshot.png` as a relative path and embedded at the end

  It then reveals `notes.md` in Finder. Characters that are unsafe in file names are replaced with `-`, and the name is cut to 60 characters.

### Notes panel image

`Renderer.withNotesPanel` adds a panel under the image listing each numbered note, so a pasted image explains itself. With no notes it returns the image unchanged (`Sources/PinpointCore/Renderer.swift:238-240`). It is also used by ⌘C copy (see [prd-001b](./prd-001b-pinpoint-v0-1-markup-editor.md)).

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | an arrow with note "this should be blue" points at a "Save" label | the user copies the handoff | the text has `1. Arrow pointing at "Save" (x ..., y ...)` and the note on the next line |
| AC-2 | a capture with no notes | the user copies the handoff | the text says "(No notes added.)" |
| AC-3 | a capture with blur items | the handoff is built | blur and redact items are not listed under "Other markup" |
| AC-4 | the user exports a handoff | they choose a folder | `<name> handoff/` holds `screenshot.png`, `screenshot-with-notes.png` and `notes.md` |

## Tests

`HandoffTests` and `NotesPanelTests` in `Tests/PinpointCoreTests/ProviderTests.swift` (lines 175, 208).

## Related

- [Glossary: handoff, note](../../../knowledge/private/glossary/glossary.md)
