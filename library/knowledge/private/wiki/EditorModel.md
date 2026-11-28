---
type: entity
title: "EditorModel"
entity: EditorModel
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/EditorModel.swift"
lines: "37-381"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[CaptureMeta]]"
  - "[[Annotation]]"
  - "[[AnnotationKind]]"
  - "[[RGBA]]"
  - "[[Tool]]"
  - "[[LibraryStore]]"
  - "[[Renderer]]"
  - "[[Analyzer]]"
  - "[[Analysis]]"
  - "[[Handoff]]"
  - "[[ImageFiles]]"
  - "[[Assistants]]"
  - "[[EditAgent]]"
  - "[[AgentState]]"
  - "[[AppSettings]]"
  - "[[QuickStyle]]"
  - "[[ZoomController]]"
  - "[[CanvasView]]"
used_by:
  - "[[Workspace]]"
  - "[[AppDelegate]]"
  - "[[CanvasView]]"
  - "[[MainView]]"
  - "[[PropertiesPanel]]"
  - "[[AssistantPanel]]"
  - "[[TrayView]]"
  - "[[NotePromptView]]"
  - "[[MainWindowController]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
related:
  - "[[Workspace]]"
  - "[[CanvasView]]"
  - "[[EditAgent]]"
  - "[[Handoff]]"
---

# EditorModel (and LogEntry, pinpointLibraryChanged)

## Purpose

The state and actions of the editor for one open **capture**: markup items, crop, current **tool** and style, selection, undo and redo, saving and export, **handoff**, on-device **analysis**, **auto-redact**, the **assistant** actions and the **agent**. `LogEntry` is one line in the Assistant panel log.

## API (internal)

```swift
struct LogEntry: Identifiable {
    enum Role { case user, assistant, tool, error }
    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
final class EditorModel: ObservableObject {
    let base: CGImage
    let pixelated: CGImage?
    let library: LibraryStore
    var imageSize: CGSize

    @Published var meta: CaptureMeta
    @Published var annotations: [Annotation]
    @Published var crop: CGRect?
    @Published var tool: Tool = .arrow
    @Published var color: RGBA = .red
    @Published var lineWidth: Double
    @Published var fontSize: Double
    @Published var fillColor: RGBA?
    @Published var shadow = true
    @Published var selectedID: UUID?
    let zoom = ZoomController()
    weak var canvas: CanvasView?
    @Published var analysis: Analysis?
    @Published var log: [LogEntry] = []
    @Published var busy = false
    @Published var dirty = false

    init(meta: CaptureMeta, base: CGImage, library: LibraryStore)

    func setNote(_ id: UUID, _ text: String)
    func removeAnnotation(_ id: UUID)
    func promptNote(_ id: UUID, autoListen: Bool)
    var handoffMarkdown: String
    func copyHandoff()
    func copyFilePath()
    func exportHandoff()
    var canUndo: Bool
    var canRedo: Bool
    func checkpoint()
    func undo()
    func redo()
    func add(_ a: Annotation)
    func deleteSelected()
    func styleChanged()
    var selected: Annotation?
    func apply(_ s: QuickStyle)
    func bringToFront()
    func sendToBack()
    func duplicateSelected()
    var nextStep: Int
    func newAnnotation(kind: AnnotationKind, at p: CGPoint) -> Annotation
    func flattened() -> CGImage?
    func copyImage(includeNotesPanel: Bool = true)
    func save()
    func export()
    func startAnalysis()
    func autoRedact(style: AnnotationKind)
    func extractText()
    func summarize()
    func nameAndTag()
    func runAgent(_ instruction: String)
    func cancelAI()
    func info(_ s: String)
    func fail(_ s: String)
}

extension Notification.Name {
    static let pinpointLibraryChanged = Notification.Name("pinpointLibraryChanged")
}
```

## Behaviour

- `init` copies markup and crop from the meta, sets default line width and font size for the image size, precomputes the pixelated copy and starts analysis (`EditorModel.swift:136-147`).
- Undo and redo keep up to 200 `(annotations, crop)` snapshots; `checkpoint()` marks the model dirty (`EditorModel.swift:152-167`).
- Selecting an item loads its style into the Properties panel; `styleChanged()` writes the current style back to the selection (`EditorModel.swift:61-67`, `:177-188`).
- `newAnnotation` makes redact black, notes orange and numbers **steps** automatically (`EditorModel.swift:215-221`).
- `copyImage` puts one picture (PNG and TIFF) on the clipboard, with the notes panel when there are notes (`EditorModel.swift:229-245`). `save()` writes meta and the rendered image to [[LibraryStore]] and posts `pinpointLibraryChanged` (`:247-255`).
- Handoff: `copyHandoff()` saves and copies `Handoff.markdown` with the rendered image path; `exportHandoff()` writes `screenshot.png`, `screenshot-with-notes.png` and `notes.md` to a chosen folder (`EditorModel.swift:92-126`). `copyFilePath()` saves, then copies `LibraryStore.bestURL` as plain text for pasting into a coding CLI; it copies nothing if the save failed.
- `startAnalysis()` runs [[Analyzer]] off the main actor with the user's redact terms, and fills empty OCR text in the meta, logging a failed save with `PinpointLog.storage` (`EditorModel.swift:271-285`). `autoRedact` adds blur or redact markup for every sensitive region in one undo step (`:287-294`).
- `runAgent` waits for or runs analysis, runs [[EditAgent]] with an [[AgentState]], logs each tool event, and applies the result as one checkpoint (`EditorModel.swift:332-359`). `runAI` allows one AI job at a time and `cancelAI()` cancels it (`:361-373`).

## Called by

- [[Workspace]] creates it (`Sources/Pinpoint/MainWindow.swift:28`); [[AppDelegate]] calls `autoRedact` after capture (`AppDelegate.swift:191`).
- [[CanvasView]] edits markup through it; [[MainView]], [[PropertiesPanel]], [[AssistantPanel]], [[TrayView]], [[NotePromptView]] and [[MainWindowController]] call its actions.
- `pinpointLibraryChanged` is observed by [[Workspace]] and [[LibraryModel]] and posted by [[AppDelegate]], [[LibraryModel]] and this model.

## Related

[[Workspace]] · [[CanvasView]] · [[Renderer]] · [[Handoff]] · [[Analyzer]] · [[EditAgent]] · [[Assistants]] · [[Tool]] · [[QuickStyle]]

## Sources

- `Sources/Pinpoint/EditorModel.swift` (lines 37-381)
