---
type: entity
title: "CaptureMeta"
entity: CaptureMeta
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Library.swift"
lines: "5-28"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Annotation]]"
used_by:
  - "[[LibraryStore]]"
  - "[[Handoff]]"
  - "[[EditorModel]]"
  - "[[Workspace]]"
  - "[[LibraryModel]]"
  - "[[AppDelegate]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:96 LibraryTests"
  - "Tests/PinpointCoreTests/ProviderTests.swift:196 HandoffTests.testNotesRenderAndDecodeOldMeta"
tags:
  - entity
  - pinpointcore
  - library
related:
  - "[[LibraryStore]]"
  - "[[Annotation]]"
---

# CaptureMeta

## Purpose

Everything Pinpoint knows about one **capture**, stored as `meta.json` next to the images (`Sources/PinpointCore/Library.swift:5`): name, tags, OCR text, summary, source app, size, markup items, crop and whether AI named it.

## API

```swift
public struct CaptureMeta: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var created: Date
    public var modified: Date
    public var name: String
    public var tags: [String]
    public var ocrText: String
    public var summary: String?
    public var sourceApp: String?
    public var width: Int
    public var height: Int
    public var annotations: [Annotation]
    public var crop: CGRect?
    public var aiNamed: Bool

    public init(id: UUID = UUID(), created: Date = Date(), name: String, tags: [String] = [], ocrText: String = "",
                summary: String? = nil, sourceApp: String? = nil, width: Int, height: Int,
                annotations: [Annotation] = [], crop: CGRect? = nil, aiNamed: Bool = false)
}
```

## Behaviour

- `init` sets `modified` equal to `created` (`Library.swift:24`).

## Called by

- [[LibraryStore]] creates, saves, loads and searches it (`Library.swift:57-119`).
- [[Handoff]] `markdown(meta:...)` reads name, size, app and summary (`Handoff.swift:45-64`).
- [[EditorModel]] `meta`; [[Workspace]] `open(meta:image:)`; [[LibraryModel]] `all`; [[AppDelegate]] `finishCapture` and `postProcess`.

## Related

[[LibraryStore]] · [[Annotation]] · [[EditorModel]] · [[LibraryModel]] · [[Handoff]]

## Sources

- `Sources/PinpointCore/Library.swift` (lines 5-28)
