---
type: entity
title: "LibraryModel"
entity: LibraryModel
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/LibraryView.swift"
lines: "5-118"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LibraryStore]]"
  - "[[CaptureMeta]]"
  - "[[ImageFiles]]"
  - "[[AppSettings]]"
  - "[[LLMClient]]"
  - "[[Assistants]]"
  - "[[GuideBuilder]]"
used_by:
  - "[[Workspace]]"
  - "[[LibraryView]]"
  - "[[TrayView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - library
related:
  - "[[LibraryStore]]"
  - "[[LibraryView]]"
  - "[[GuideBuilder]]"
---

# LibraryModel

## Purpose

The observable state behind the **library** grid: every **capture**'s meta, the search query, the ordered selection (which becomes the **step** order of a **guide**), a status line and a thumbnail cache. It also runs the library-level actions: copy, move to Trash, AI name and tag, and make a guide.

## API (internal)

```swift
@MainActor
final class LibraryModel: ObservableObject {
    let store: LibraryStore
    @Published var all: [CaptureMeta] = []
    @Published var query = ""
    @Published var selection: [UUID] = []
    @Published var status = ""
    @Published var busy = false
    let thumbs = NSCache<NSUUID, NSImage>()

    init(store: LibraryStore)

    var filtered: [CaptureMeta]
    func reload()
    func thumb(_ id: UUID) -> NSImage?
    func toggle(_ id: UUID, extend: Bool)
    func copy(_ id: UUID)
    func delete(_ ids: [UUID])
    func autoTag()
    func makeGuide()
}
```

## Behaviour

- `init` loads the library and observes `pinpointLibraryChanged`, clearing the thumbnail cache and reloading on each post (`LibraryView.swift:16-22`).
- `filtered` is `LibraryStore.search(all, query: query)` (`LibraryView.swift:24`).
- `reload()` calls `store.loadAll()` off the main actor, then drops selected IDs that no longer exist (`LibraryView.swift:26-32`).
- `thumb(_:)` reads `thumbURL` once and caches the `NSImage` (`LibraryView.swift:34-39`).
- `toggle(_:extend:)` appends or removes an ID when extending (Command or Shift click), otherwise selects only that capture or clears it (`LibraryView.swift:41-44`).
- `copy(_:)` puts the PNG of `bestImage` on the clipboard (`LibraryView.swift:46-50`). `copyPath(_:)` copies `bestURL`'s path as text, for pasting into a terminal agent.
- `delete(_:)` moves each capture to the Trash through `store.delete`, counting failures instead of ignoring them, updates the selection and posts `pinpointLibraryChanged`. The status reads "Moved N to Trash.", or "Moved N to Trash; M couldn't be moved: <reason>" with the first failure's message when any move fails (`LibraryView.swift:52-62`).
- `autoTag()` names and tags the selection, or every capture with `aiNamed == false` when nothing is selected, using `AppSettings.shared.makeClient(fast: true)` and `Assistants.nameAndTags`, then writes each meta and reloads (`LibraryView.swift:65-87`). An AI or `writeMeta` error on one capture is caught and skipped; the final status "Named X of Y." gets " Last error: <message>" appended when any item failed (`:78-84`).
- `makeGuide()` builds one `GuideStep` per selected capture in selection order. With AI configured it asks `Assistants.writeGuide`; otherwise, or if AI fails, it uses `GuideBuilder.fallbackMarkdown`. `GuideBuilder.write` saves under `<library root>/Guides`, then the guide opens as `guide.html` and `guide.md` is revealed in Finder (`LibraryView.swift:89-117`).

## Called by

- [[Workspace]] creates it with the shared [[LibraryStore]] (`Sources/Pinpoint/MainWindow.swift:19`).
- [[LibraryView]] renders it; [[TrayView]] observes it (`Sources/Pinpoint/MainWindow.swift:360`).

## Related

[[LibraryStore]] · [[LibraryView]] · [[CaptureMeta]] · [[Assistants]] · [[GuideBuilder]] · [[Workspace]] · [[EditorModel]]

## Sources

- `Sources/Pinpoint/LibraryView.swift` (lines 5-118)
