---
type: entity
title: "LibraryStore"
entity: LibraryStore
kind: class
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Library.swift"
lines: "30-120"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[CaptureMeta]]"
  - "[[ImageFiles]]"
used_by:
  - "[[AppDelegate]]"
  - "[[Workspace]]"
  - "[[LibraryModel]]"
  - "[[EditorModel]]"
  - "[[SettingsView]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:96 LibraryTests"
tags:
  - entity
  - pinpointcore
  - library
  - storage
related:
  - "[[CaptureMeta]]"
  - "[[LibraryModel]]"
  - "[[Workspace]]"
---

# LibraryStore

## Purpose

The **library** on disk: one folder per capture, `<root>/<uuid>/{original.png, rendered.png, thumb.jpg, meta.json}` (`Sources/PinpointCore/Library.swift:30`). The three images are the **original**, **rendered** and **thumbnail**.

## API

```swift
public final class LibraryStore: @unchecked Sendable {
    public let root: URL
    public static var defaultRoot: URL
    public init(root: URL = LibraryStore.defaultRoot)

    public func folder(_ id: UUID) -> URL
    public func originalURL(_ id: UUID) -> URL
    public func renderedURL(_ id: UUID) -> URL
    public func thumbURL(_ id: UUID) -> URL
    public func metaURL(_ id: UUID) -> URL

    @discardableResult
    public func create(image: CGImage, name: String = "Capture", sourceApp: String? = nil) throws -> CaptureMeta
    public func save(_ meta: CaptureMeta, rendered: CGImage? = nil) throws
    public func writeMeta(_ meta: CaptureMeta) throws
    public func meta(_ id: UUID) -> CaptureMeta?
    public func loadAll() -> [CaptureMeta]
    public func original(_ id: UUID) -> CGImage?
    public func bestImage(_ id: UUID) -> CGImage?
    public func delete(_ id: UUID) throws
    public static func search(_ metas: [CaptureMeta], query: String) -> [CaptureMeta]
}
```

Internal: `func writeThumb(_ image: CGImage, id: UUID) throws` (480 px JPEG at quality 0.8, `Library.swift:83-86`) and shared ISO-8601 `encoder`/`decoder` (`:51-54`).

## Behaviour

- `defaultRoot` is `~/Pictures/Pinpoint` (`Library.swift:36-38`).
- `create` writes the original, a thumbnail and `meta.json` (`Library.swift:57-64`). `save` bumps `modified` and, if given, writes the rendered image and refreshes the thumbnail (`:67-76`).
- `writeMeta` is serialised with a lock and written atomically (`Library.swift:78-81`).
- `loadAll` reads every UUID-named folder, newest first (`Library.swift:93-97`). `bestImage` prefers the rendered image (`:102-104`). `delete` moves the folder to the Trash (`:106-108`).
- `search` requires every query word to appear in name, tags (also as `#tag`), app, summary or OCR text (`Library.swift:111-119`).

> [!warning] Stored-data identifier
> Changing `defaultRoot` orphans users' captures without a launch-time migration (project AGENTS.md; `library/knowledge/private/architecture/ADR-2-stored-data-identifiers.md`). The folder-per-capture layout is `ADR-1-library-folder-per-capture.md`.

## Called by

- [[AppDelegate]] owns the single instance (`library`) and calls `create`, `meta`, `writeMeta` (`Sources/Pinpoint/AppDelegate.swift:12`, `:178`, `:202-219`, `:261`).
- [[Workspace]] `open(id:)`, `saveCurrent()`, `closeIfDeleted()` (`Sources/Pinpoint/MainWindow.swift:33-46`).
- [[LibraryModel]] `loadAll`, `search`, `thumbURL`, `bestImage`, `delete`, `meta`, `original`, `writeMeta` (`Sources/Pinpoint/LibraryView.swift:24-103`).
- [[EditorModel]] `save`, `writeMeta`, `renderedURL` (`Sources/Pinpoint/EditorModel.swift:93`, `:251`, `:280`).
- [[SettingsView]] shows `defaultRoot.path` (`Sources/Pinpoint/SettingsView.swift:106`).

## Related

[[CaptureMeta]] · [[ImageFiles]] · [[LibraryModel]] · [[Workspace]] · [[EditorModel]] · [[AppDelegate]]

## Tested by

- `LibraryTests.testCreateSaveLoadSearch` (`Tests/PinpointCoreTests/CoreTests.swift:97`).

## Sources

- `Sources/PinpointCore/Library.swift` (lines 30-120)
