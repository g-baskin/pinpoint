---
type: entity
title: "MainView"
entity: MainView
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/MainWindow.swift"
lines: "52-223"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Workspace]]"
  - "[[EditorModel]]"
  - "[[AppSettings]]"
  - "[[AppDelegate]]"
  - "[[LibraryView]]"
  - "[[CanvasView]]"
  - "[[PropertiesPanel]]"
  - "[[AssistantPanel]]"
  - "[[TrayView]]"
  - "[[Tool]]"
  - "[[ImageFiles]]"
used_by:
  - "[[MainWindowController]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - window
  - view
related:
  - "[[Workspace]]"
  - "[[EditorModel]]"
  - "[[MainWindowController]]"
---

# MainView (and TopBar, ToolStrip, EditorActions, ShareButton, EditorBody, EmptyEditor)

## Purpose

The SwiftUI content of the main window: a top bar, then either the [[LibraryView]] or the editor (canvas, sidebar and tray), or an empty editor prompting a capture.

## API (internal)

```swift
struct MainView: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var settings = AppSettings.shared
}

struct TopBar: View {
    @ObservedObject var ws: Workspace
}

struct ToolStrip: View {
    @ObservedObject var model: EditorModel
}

struct EditorActions: View {
    @ObservedObject var model: EditorModel
}

struct ShareButton: NSViewRepresentable {
    let model: EditorModel
    func makeNSView(context: Context) -> NSButton
    func updateNSView(_ v: NSButton, context: Context)
    func makeCoordinator() -> Coordinator
    @MainActor final class Coordinator: NSObject {
        var model: EditorModel
        init(model: EditorModel)
        @objc func share(_ sender: NSButton)
    }
}

struct EditorBody: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var model: EditorModel
}

struct EmptyEditor: View {
    @ObservedObject var ws: Workspace
}
```

Every struct here except `ShareButton` also declares `var body: some View` (`Sources/Pinpoint/MainWindow.swift:52-223`).

## Behaviour

- `MainView` switches on `ws.mode`; the editor body is keyed by capture id so each capture gets fresh view state (`MainWindow.swift:56-72`).
- `TopBar`: Capture menu (area, window, full screen, all screens, scrolling, Open Image) calling `AppDelegate.shared`, an Editor/Library segmented picker, and for the editor the [[Tool]] strip and actions (`MainWindow.swift:79-115`).
- `EditorActions`: undo, redo, Reset Crop, Copy, the Handoff menu (copy for AI agent, copy file path for terminal agents, copy image with or without notes panel, export handoff folder), Share, Export and Save (`MainWindow.swift:136-156`).
- `ShareButton` writes the flattened image to a temp PNG and shows the macOS share picker; if the write fails it reports "Share failed: <reason>" through `model.fail` and does not show the picker (`MainWindow.swift:160-180`, `:176`).
- `EditorBody`: [[CanvasView]] (via `CanvasScrollView`) beside a Properties or Assistant sidebar, with [[TrayView]] below (`MainWindow.swift:186-205`).

## Called by

- [[MainWindowController]] sets `MainView(ws:)` as window content (`MainWindow.swift:429`).

## Related

[[Workspace]] · [[EditorModel]] · [[PropertiesPanel]] · [[AssistantPanel]] · [[TrayView]] · [[CanvasView]] · [[LibraryView]] · [[Handoff]]

## Sources

- `Sources/Pinpoint/MainWindow.swift` (lines 52-223)
