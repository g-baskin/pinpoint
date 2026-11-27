---
type: entity
title: "TrayView"
entity: TrayView
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/MainWindow.swift"
lines: "355-417"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Workspace]]"
  - "[[LibraryModel]]"
  - "[[EditorModel]]"
  - "[[ZoomController]]"
used_by:
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - view
related:
  - "[[LibraryModel]]"
  - "[[ZoomController]]"
---

# TrayView (and ZoomControls)

## Purpose

The strip along the bottom of the main window: recent captures from the **library**, a search field, and zoom controls (`Sources/Pinpoint/MainWindow.swift:357`).

## API (internal)

```swift
struct TrayView: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var library: LibraryModel
    let model: EditorModel?
}

struct ZoomControls: View {
    @ObservedObject var zoom: ZoomController
}
```

## Behaviour

- Shows up to 150 filtered thumbnails, outlining the open capture; click opens it; the context menu offers Copy Image, Show in Finder and Move to Trash (`MainWindow.swift:373-396`).
- `ZoomControls`: zoom out and in by 1.25, percent label, Fit and 100% (`MainWindow.swift:404-417`).

## Called by

- `EditorBody` and `EmptyEditor` in [[MainView]] (`MainWindow.swift:203`, `:220`).

## Related

[[LibraryModel]] · [[ZoomController]] · [[Workspace]] · [[MainView]]

## Sources

- `Sources/Pinpoint/MainWindow.swift` (lines 355-417)
