---
type: entity
title: "NotePromptView"
entity: NotePromptView
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/NotePrompt.swift"
lines: "5-175"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[EditorModel]]"
  - "[[SpeechDictation]]"
  - "[[ExternalDictation]]"
  - "[[AppSettings]]"
  - "[[Annotation]]"
used_by:
  - "[[CanvasView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
  - voice
  - view
related:
  - "[[SpeechDictation]]"
  - "[[ExternalDictation]]"
  - "[[CanvasView]]"
---

# NotePromptView (and LevelMeter)

## Purpose

The "Add more context?" popover that appears next to a new **markup item** (or "What's this note about?" for a **note**). The user types, speaks through built-in dictation, or uses an external dictation app that types into the focused field. `LevelMeter` is the five-bar microphone level shown while listening.

## API (internal)

```swift
struct NotePromptView: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var speech = SpeechDictation.shared
    let annotationID: UUID
    let autoListen: Bool
    let close: () -> Void
}

struct LevelMeter: View {
    let level: Float
}
```

## Behaviour

- On appear it loads the item's existing note, reads `AppSettings.shared.activeExternalDictation` and keeps the text field focused. With no external app it installs Option-key push-to-talk and, if `autoListen` and the note is empty, starts listening with a 2.2 s silence stop and auto-answer. With an external app that does not use Option, it still installs Option push-to-talk (`NotePrompt.swift:65-79`).
- On disappear it removes the key monitor and stops dictation (`NotePrompt.swift:80-83`).
- Auto-answer: a spoken "no", "nope", "skip", "cancel", "no thanks" or "never mind" dismisses the prompt; a leading "yes", "yeah", "yep", "sure", "ok" or "okay" is dropped and the next letter capitalised (`NotePrompt.swift:117-137`). `handleAnswer` applies the same rule to the first burst of text pasted by a dictation app (`NotePrompt.swift:42-50`, `:140-148`).
- Typing while dictating stops the microphone (`NotePrompt.swift:44`).
- The mic button: holding longer than 0.35 s is push-to-talk; a quick click starts hands-free listening (`NotePrompt.swift:86-105`). Holding Option does the same as holding the button (`NotePrompt.swift:107-114`).
- Save calls `model.setNote(annotationID, text)`; Skip removes an empty note pin through `model.removeAnnotation` and leaves other markup in place (`NotePrompt.swift:150-161`).
- `LevelMeter` lights bar `i` red when `Float(i) / 5 < level` (`NotePrompt.swift:164-175`).

## Called by

- [[CanvasView]] opens it in a popover for a new item (`Sources/Pinpoint/CanvasView.swift:206`), reached through [[EditorModel]] `promptNote(_:autoListen:)`.

## Related

[[SpeechDictation]] · [[ExternalDictation]] · [[EditorModel]] · [[CanvasView]] · [[AppSettings]] · [[Annotation]]

## Sources

- `Sources/Pinpoint/NotePrompt.swift` (lines 5-175)
