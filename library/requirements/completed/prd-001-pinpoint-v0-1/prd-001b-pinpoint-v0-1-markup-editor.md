# PRD-001b: Markup editor *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

One capture is open at a time in the main window: tools along the top, a Properties / Assistant sidebar on the right, recent captures along the bottom (`Sources/Pinpoint/MainWindow.swift:5`, `72`, `354`). Drawing happens in `CanvasView` (`Sources/Pinpoint/CanvasView.swift:6`). The editor state is `EditorModel` (`Sources/Pinpoint/EditorModel.swift:45`).

### Tools and markup kinds

`Tool` (`EditorModel.swift:6-30`) has 13 tools, each with a single-letter key. Eleven of them create a markup item of the matching `AnnotationKind` (`Sources/PinpointCore/Annotation.swift:35-41`).

| Key | Tool | What it draws |
|---|---|---|
| V | select | selects and moves items |
| A | arrow | arrow, tail to head |
| L | line | straight line |
| R | rectangle | outline, optional fill |
| E | ellipse | outline, optional fill |
| T | text | bold text label |
| O | callout | speech bubble with text, optional fill |
| H | highlight | translucent box drawn with multiply blend at 45% alpha (`Sources/PinpointCore/Renderer.swift:142-145`) |
| N | step | numbered badge; numbers are assigned automatically |
| M | note ("Voice note") | numbered comment pin |
| B | blur | pixelates the area: a pixelated copy of the capture, block size at least 10 px, is revealed through a clip (`Renderer.swift:20-31`, `150-157`) |
| X | redact | solid black box (`Renderer.swift:147-148`) |
| C | crop | sets the capture's crop rectangle |

Holding Shift while drawing constrains to squares and 45° lines (`CanvasView.swift:147`). Arrow keys nudge the selection by 1 px, or 10 px with Shift (`CanvasView.swift:261`).

### Styles

- Colour presets: red, orange, yellow, green, blue, purple, black, white (`Annotation.swift:9-17`). The agent also accepts `#rrggbb` (`Annotation.swift:24-32`).
- Default line width and font size scale with the image so markup looks the same on 1x and Retina captures (`Annotation.swift:145-147`).
- Drop shadow is on unless turned off (`Annotation.swift:55-56`, `89`).
- Quick style thumbnails per kind (`Sources/Pinpoint/QuickStyles.swift:4-30`). Selecting an item loads its style into Properties, and changing a style applies it to the selected item (`EditorModel.swift:60`, `176-188`).
- Bring to front, send to back, duplicate, delete (`EditorModel.swift:171-213`).

### Notes and voice notes

Any markup item can carry a `note`. Items with a note, and every note pin, get a number badge in drawing order (`Annotation.swift:57-58`, `68`; `Renderer.noteNumbers`, `Renderer.swift:51-57`).

After drawing an arrow, line, rectangle, ellipse or highlight, an "Add more context?" popover opens next to it if **askForContext** is on (default on) (`CanvasView.swift:194-198`, `Sources/Pinpoint/AppSettings.swift:52`). The user can type, say "yes" and talk, or say "no" / "skip" to dismiss (`Sources/Pinpoint/NotePrompt.swift:5`, `116-160`).

Dictation is either built in or external:

- Built-in: Apple Speech framework on the Mac, with a choice of microphone (`Sources/Pinpoint/SpeechDictation.swift:7`, `Sources/Pinpoint/DictationSources.swift:52-92`).
- External: if Wispr Flow, Superwhisper, Aqua Voice, VoiceInk or MacWhisper is running, Pinpoint keeps the note box focused so that app can type into it. For Wispr Flow it reads the push-to-talk key from Wispr Flow's settings file, read-only (`DictationSources.swift:5-50`). Setting `dictationSource` chooses auto, external or built-in (`AppSettings.swift:20-21`).

A notes list in the sidebar shows every note numbered like the badges (`MainWindow.swift:446-460`).

### Undo, save, copy, export

- Undo / redo: snapshots of markup and crop, up to 200 (`EditorModel.swift:132-167`). ⌘Z / ⇧⌘Z (`MainWindow.swift:442-443`).
- Save (⌘S): writes markup and crop to `meta.json` and the flattened image to `rendered.png` (`EditorModel.swift:247-255`; `Renderer.flatten`, `Renderer.swift:218-236`).
- Copy (⌘C): one PNG + TIFF image with markup, badges and, if there are notes, a notes panel underneath (`EditorModel.swift:227-245`).
- Export (⇧⌘E): PNG, JPEG or HEIC through a save panel (`EditorModel.swift:257-268`).
- Share: the macOS share sheet with the edited image (`MainWindow.swift:156-175`).

One drawing routine serves both the live canvas and exported images: `Renderer` draws in a flipped context in image pixels (`Renderer.swift:6-8`).

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | a capture is open | the user presses N three times and clicks | the steps show 1, 2, 3 |
| AC-2 | the user has drawn items | they press ⌘Z | the last change is undone; ⇧⌘Z redoes it |
| AC-3 | a blur item covers text | the user exports | the exported image shows pixelated blocks, not the text |
| AC-4 | **askForContext** is on | the user draws an arrow | the "Add more context?" prompt opens beside it |
| AC-5 | the capture has two notes | the user presses ⌘C | the clipboard image has badges 1 and 2 and a notes panel underneath |

## Tests

`RenderTests` (`Tests/PinpointCoreTests/CoreTests.swift:53`) and `NotesPanelTests` (`Tests/PinpointCoreTests/ProviderTests.swift:208`). The canvas, prompt and dictation are app-target code with no tests.

## Related

- [Glossary: markup item, tool, step, note, blur and redact](../../../knowledge/private/glossary/glossary.md)
