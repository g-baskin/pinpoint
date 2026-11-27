---
type: entity
title: "PropertiesPanel"
entity: PropertiesPanel
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/MainWindow.swift"
lines: "225-353, 449-475"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[EditorModel]]"
  - "[[QuickStyle]]"
  - "[[AnnotationKind]]"
  - "[[RGBA]]"
  - "[[Renderer]]"
used_by:
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
  - view
related:
  - "[[EditorModel]]"
  - "[[QuickStyle]]"
---

# PropertiesPanel (and ColorRow, NotesList)

## Purpose

The editor's Properties sidebar: style controls for the selected markup item or current **tool**, the capture's **notes**, layer actions, and capture name and tags.

## API (internal)

```swift
struct PropertiesPanel: View {
    @ObservedObject var model: EditorModel
}

struct ColorRow: View {
    let selected: RGBA?
    let pick: (RGBA) -> Void
}

struct NotesList: View {
    @ObservedObject var model: EditorModel
}
```

## Behaviour

- Shows properties for the selected item's kind, else the current tool's (`Sources/Pinpoint/MainWindow.swift:230-231`).
- Quick Styles grid from `QuickStyle.presets(for:)`, colour, fill (callouts get opaque fill, others 30% alpha), width, size and shadow, each calling `styleChanged()` when edited (`MainWindow.swift:239-279`).
- Crop and Select tools show help text; selection adds Add or Edit voice note, bring to front, send to back, duplicate and delete (`MainWindow.swift:280-306`).
- Capture section edits `meta.name` and comma-separated lowercased tags (`MainWindow.swift:309-317`).
- `ColorRow`: the eight [[RGBA]] presets plus a custom colour picker converted to sRGB (`MainWindow.swift:331-353`).
- `NotesList`: every noted item numbered like the badges (`Renderer.noteNumbers`), each note editable inline or by dictation, plus "Copy for AI" (`MainWindow.swift:449-475`).

## Called by

- `EditorBody` in [[MainView]] when the sidebar tab is Properties (`MainWindow.swift:198`).

## Related

[[EditorModel]] · [[QuickStyle]] · [[RGBA]] · [[Renderer]] · [[NotePromptView]] · [[AssistantPanel]]

## Sources

- `Sources/Pinpoint/MainWindow.swift` (lines 225-353, 449-475)
