---
type: entity
title: "Workspace"
entity: Workspace
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/MainWindow.swift"
lines: "5-50"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LibraryStore]]"
  - "[[LibraryModel]]"
  - "[[EditorModel]]"
  - "[[CaptureMeta]]"
used_by:
  - "[[AppDelegate]]"
  - "[[MainWindowController]]"
  - "[[MainView]]"
  - "[[TrayView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - window
related:
  - "[[EditorModel]]"
  - "[[LibraryModel]]"
  - "[[MainView]]"
---

# Workspace

## Purpose

State for the single Pinpoint window: editor, **library** and recent-captures tray. One capture is open at a time (`Sources/Pinpoint/MainWindow.swift:5`).

## API (internal)

```swift
@MainActor
final class Workspace: ObservableObject {
    enum Mode { case editor, library }
    let store: LibraryStore
    let library: LibraryModel
    @Published var editor: EditorModel?
    @Published var mode: Mode = .editor
    @Published var sidebarTab = 0   // 0 = Properties, 1 = Assistant

    init(store: LibraryStore)
    func open(meta: CaptureMeta, image: CGImage)
    func open(id: UUID)
    func saveCurrent()
    func closeIfDeleted()
}
```

## Behaviour

- `open(meta:image:)` switches to the editor; if a different capture is open it saves it first and creates a new [[EditorModel]] (`MainWindow.swift:25-30`).
- `open(id:)` loads meta and original from [[LibraryStore]] (`MainWindow.swift:32-35`).
- `saveCurrent()` does a full save when there are unsaved markup or crop changes, otherwise only rewrites `meta.json` (name and tags may have changed) and posts `pinpointLibraryChanged`; a failed `writeMeta` is shown in an `NSAlert` (`MainWindow.swift:37-44`).
- Listens for `pinpointLibraryChanged` and closes the editor if its capture was deleted (`MainWindow.swift:20-22`, `:47-49`).

## Called by

- [[AppDelegate]] owns it (`workspace`), calls `open`, `saveCurrent`, sets `mode` (`Sources/Pinpoint/AppDelegate.swift:14`, `:38`, `:239-252`).
- [[MainWindowController]] `windowWillClose` saves (`MainWindow.swift:438`); [[MainView]] and [[TrayView]] read and switch it.

## Related

[[EditorModel]] · [[LibraryModel]] · [[LibraryStore]] · [[MainView]] · [[MainWindowController]] · [[AppDelegate]]

## Sources

- `Sources/Pinpoint/MainWindow.swift` (lines 5-50)
