---
type: entity
title: "LibraryView"
entity: LibraryView
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/LibraryView.swift"
lines: "120-200"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LibraryModel]]"
  - "[[LibraryStore]]"
  - "[[CaptureMeta]]"
used_by:
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - library
  - view
related:
  - "[[LibraryModel]]"
  - "[[MainView]]"
---

# LibraryView

## Purpose

The SwiftUI **library** grid in the main window: a search bar with Auto-name, Make Guide and open-folder buttons, a grid of capture cards, and a status line.

## API (internal)

```swift
struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    let open: (UUID) -> Void
}
```

Private: `func card(_ m: CaptureMeta) -> some View` (`LibraryView.swift:163`).

## Behaviour

- The search field binds to `model.query`; Auto-name calls `model.autoTag()`, Make Guide calls `model.makeGuide()` and is disabled with no selection; the folder button opens `model.store.root` (`LibraryView.swift:126-137`).
- The grid is a `LazyVGrid` of adaptive 190 pt columns over `model.filtered`, with an empty-state message for no captures or no matches (`LibraryView.swift:140-153`).
- The status line shows `model.status`, or the capture and selection counts when it is empty (`LibraryView.swift:155-159`).
- Each card shows the cached thumbnail, the capture name, its created date and up to three `#tags`. A selected card gets an accent border and its selection number, which is its step order in a guide (`LibraryView.swift:163-184`).
- Double-click calls `open(id)`; a single click calls `model.toggle` with `extend` true when Command or Shift is held (`LibraryView.swift:186-187`).
- The context menu offers Open in Editor, Copy Image, Show in Finder and Move to Trash (the whole selection when the card is selected) (`LibraryView.swift:188-194`).
- Dragging a card provides the rendered image file if it exists, else the original (`LibraryView.swift:195-198`).

## Called by

- [[MainView]] shows it when the library tab is active, opening captures through `ws.open(id:)` (`Sources/Pinpoint/MainWindow.swift:62`).

## Related

[[LibraryModel]] · [[LibraryStore]] · [[MainView]] · [[Workspace]]

## Sources

- `Sources/Pinpoint/LibraryView.swift` (lines 120-200)
