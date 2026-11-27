# PRD-001e: Library and guides *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

### Storage

`LibraryStore` keeps one folder per capture under `~/Pictures/Pinpoint/<uuid>/` (`Sources/PinpointCore/Library.swift:30-49`; [ADR-1](../../../knowledge/private/architecture/ADR-1-library-folder-per-capture.md)):

| File | Written when | Source |
|---|---|---|
| `original.png` | on capture, never changed | `Library.swift:57-64` |
| `rendered.png` | on save, with markup and crop baked in | `Library.swift:67-76` |
| `thumb.jpg` | on capture and save; long edge at most 480 px, JPEG quality 0.8 | `Library.swift:83-86` |
| `meta.json` | on every change to `CaptureMeta`; written atomically under a lock | `Library.swift:78-81` |

- `loadAll` reads every folder whose name is a UUID, newest first (`Library.swift:93-97`).
- `bestImage` returns `rendered.png` if it exists, else the original (`Library.swift:101-104`).
- Delete moves the folder to the Trash, so it can be recovered (`Library.swift:106-108`).
- The root path is fixed; changing it would orphan users' captures ([ADR-2](../../../knowledge/private/architecture/ADR-2-stored-data-identifiers.md)).

### Background naming and OCR

After each capture or import, a background task (`Sources/Pinpoint/AppDelegate.swift:196-224`):

1. Runs OCR without face detection and saves the text as `ocrText`.
2. Sets an offline name from the first meaningful OCR line (`Analyzer.suggestedName`, see [prd-001c](./prd-001c-pinpoint-v0-1-auto-redact-analysis.md)).
3. If **Name & tag with AI** is on (default on, `Sources/Pinpoint/AppSettings.swift:48`) and a provider is set up, asks the fast model for a name and tags and sets `aiNamed`.
4. If the capture is open in the editor, it does not overwrite a name or tags the user already changed (`AppDelegate.swift:211-217`).

### Library view

The **Editor / Library** switch shows every capture as a grid of cards (`Sources/Pinpoint/LibraryView.swift:156`); ⌃⇧L opens it. A recent-captures tray with search runs along the bottom of the editor (`Sources/Pinpoint/MainWindow.swift:354`).

- **Search**: every word in the query must appear in the name, tags (also matched as `#tag`), source app, summary or OCR text, case-insensitive (`Library.swift:110-119`, `LibraryView.swift:24`).
- **Selection**: ⌘-click adds captures in order (`LibraryView.swift:41-44`).
- **Copy** and **Delete** (`LibraryView.swift:46-57`).
- **Auto-tag**: AI name and tags for the selected captures, or for all captures not yet AI-named, one at a time with progress (`LibraryView.swift:59-80`).

### Guides

**Make Guide** (`LibraryView.swift:82-109`, button at `126`) builds a step-by-step document from the selected captures in the order they were selected:

1. Each step uses the capture's best image, name and OCR text.
2. If AI is set up, `Assistants.writeGuide` asks for Markdown with a `# ` title, an intro, one `## Step N:` section per screenshot and `{{image N}}` placeholders (`Sources/PinpointCore/Assistants.swift:37-52`). If AI is not set up or fails, `GuideBuilder.fallbackMarkdown` writes one heading and image per step, titled "How to: <first capture name>" (`Assistants.swift:65-70`).
3. `GuideBuilder.write` creates `~/Pictures/Pinpoint/Guides/<title> <timestamp>/` with `images/step-N.png`, `guide.md` and `guide.html`. Placeholders become image links, and any screenshot the model left out is appended at the end (`Assistants.swift:72-103`).
4. The HTML comes from a small built-in Markdown converter covering headings, paragraphs, lists, images, links, bold, italics and code, with HTML escaping (`Assistants.swift:106-151`).
5. Pinpoint opens `guide.html` and reveals `guide.md` in Finder (`LibraryView.swift:104-105`).

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | a new capture | it is saved | `~/Pictures/Pinpoint/<uuid>/` holds `original.png`, `thumb.jpg` and `meta.json` |
| AC-2 | captures named "Billing page" and "Login" | the user searches "billing" | only "Billing page" is shown |
| AC-3 | a capture is deleted | the user opens the Trash | its folder is there |
| AC-4 | three captures selected in order and no AI provider | the user clicks **Make Guide** | a guide folder with 3 images, `guide.md` and `guide.html` is written and opened |
| AC-5 | the AI guide leaves out `{{image 2}}` | the guide is written | image 2 is appended at the end of `guide.md` |

## Tests

`LibraryTests` and `GuideTests` in `Tests/PinpointCoreTests/CoreTests.swift` (lines 96, 251).

## Related

- [Glossary: library, original / rendered / thumbnail, guide](../../../knowledge/private/glossary/glossary.md)
- [ADR-1](../../../knowledge/private/architecture/ADR-1-library-folder-per-capture.md), [ADR-2](../../../knowledge/private/architecture/ADR-2-stored-data-identifiers.md)
