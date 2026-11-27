---
type: entity
title: "AssistantPanel"
entity: AssistantPanel
kind: struct
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/EditorView.swift"
lines: "5-99"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[EditorModel]]"
  - "[[AppSettings]]"
  - "[[AppDelegate]]"
used_by:
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - editor
  - ai
  - view
related:
  - "[[EditorModel]]"
  - "[[EditAgent]]"
  - "[[Assistants]]"
  - "[[PropertiesPanel]]"
---

# AssistantPanel (and LogRow)

## Purpose

The Assistant tab of the editor sidebar: the **capture**'s name and tags, one-click **assistant** actions (**auto-redact**, copy text, summarize, name and tag), the log of AI activity, and a prompt field that runs the **agent**. `LogRow` draws one `LogEntry` in the log.

## API (internal)

```swift
struct AssistantPanel: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var settings = AppSettings.shared
}

struct LogRow: View {
    let entry: LogEntry
}
```

## Behaviour

- Name binds to `model.meta.name`; tags are edited as comma-separated text and stored trimmed and lower-cased (`EditorView.swift:12-18`).
- The header shows `settings.current.model`, or "Not set up" when AI is not configured (`EditorView.swift:20-25`).
- Action buttons call `model.autoRedact(style: .blur)` or `.redact`, `extractText()`, `summarize()` and `nameAndTag()`, and are disabled while `model.busy` (`EditorView.swift:27-37`).
- The log lists `model.log` with example prompts when empty, and scrolls to the newest entry (`EditorView.swift:39-56`).
- Submitting the prompt calls `model.runAgent(_:)` and clears the field; while busy the send button becomes a stop button that calls `model.cancelAI()` (`EditorView.swift:58-69`, `:77-81`).
- Without AI configured it offers "Set up AI in Settings..." through `AppDelegate.shared?.showSettings()` (`EditorView.swift:70-72`).
- `LogRow` styles each role: user (bold, tinted), assistant (selectable text), tool (monospaced caption, up to 3 lines), error (red warning label) (`EditorView.swift:84-99`).

## Called by

- [[MainView]] shows it when the sidebar's Assistant tab is selected (`Sources/Pinpoint/MainWindow.swift:198`).

## Related

[[EditorModel]] · [[EditAgent]] · [[Assistants]] · [[PropertiesPanel]] · [[AppSettings]] · [[MainView]]

## Sources

- `Sources/Pinpoint/EditorView.swift` (lines 5-99)
