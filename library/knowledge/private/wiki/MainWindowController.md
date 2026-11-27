---
type: entity
title: "MainWindowController"
entity: MainWindowController
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/MainWindow.swift"
lines: "419-447"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Workspace]]"
  - "[[MainView]]"
  - "[[AppDelegate]]"
used_by:
  - "[[AppDelegate]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - window
related:
  - "[[Workspace]]"
  - "[[MainView]]"
---

# MainWindowController

## Purpose

Hosts the single main window (`Sources/Pinpoint/MainWindow.swift:419`), a 1280 by 820 titled, resizable window whose content is [[MainView]].

## API (internal)

```swift
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let ws: Workspace
    init(ws: Workspace)
    func windowWillClose(_ notification: Notification)
    @objc func saveDocument(_ sender: Any?)
    @objc func exportDocument(_ sender: Any?)
    @objc func undo(_ sender: Any?)
    @objc func redo(_ sender: Any?)
}
```

## Behaviour

- Remembers its frame under autosave name `PinpointMain` (`MainWindow.swift:430-431`).
- On close: saves the current capture and tells [[AppDelegate]] so it can drop back to a menu-bar-only app (`MainWindow.swift:437-440`).
- Responder actions forward menu shortcuts (Save, Export, Undo, Redo) to the open [[EditorModel]] when the canvas is not first responder (`MainWindow.swift:442-446`).

## Called by

- [[AppDelegate]] `showMain(mode:)` creates it lazily (`Sources/Pinpoint/AppDelegate.swift:250`).

## Related

[[Workspace]] · [[MainView]] · [[AppDelegate]] · [[EditorModel]]

## Sources

- `Sources/Pinpoint/MainWindow.swift` (lines 419-447)
