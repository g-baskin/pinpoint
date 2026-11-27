---
type: entity
title: "AgentToolbox"
entity: AgentToolbox
kind: struct
entity_type: class
target: PinpointCore
path: "Sources/PinpointCore/Agent.swift"
lines: "16-202"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[AgentState]]"
  - "[[Analysis]]"
  - "[[Analyzer]]"
  - "[[Annotation]]"
  - "[[AnnotationKind]]"
  - "[[RGBA]]"
  - "[[ToolSpec]]"
  - "[[JSONValue]]"
  - "[[SensitiveKind]]"
used_by:
  - "[[EditAgent]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:116 AgentToolboxTests"
tags:
  - entity
  - pinpointcore
  - agent
related:
  - "[[EditAgent]]"
  - "[[AgentState]]"
  - "[[Analyzer]]"
---

# AgentToolbox

## Purpose

Executes the **agent**'s tool calls against an [[AgentState]]. It is pure (no network), so it is unit-tested directly (`Sources/PinpointCore/Agent.swift:16`). `scale` maps original pixels to the pixels of the image the model saw: model = original * scale (`Sources/PinpointCore/Agent.swift:17`).

## API

```swift
public struct AgentToolbox {
    public var state: AgentState
    public var analysis: Analysis
    public var scale: CGFloat
    public var color: RGBA

    public init(state: AgentState, analysis: Analysis, scale: CGFloat = 1, color: RGBA = .red)
    public static let tools: [ToolSpec]
    @discardableResult
    public mutating func execute(_ name: String, _ input: JSONValue) -> (String, Bool)
    public func describeAnnotations() -> String
}
```

`execute` returns `(output text, isError)`.

## Tools offered to the model

Defined in `tools` (`Sources/PinpointCore/Agent.swift:44-80`) and dispatched in `execute` (`Sources/PinpointCore/Agent.swift:83-112`):

| Tool | Effect |
|---|---|
| `add_annotation` | Adds one markup item of any [[AnnotationKind]]; steps number themselves via `nextStep`; text, callout and note need text (`Agent.swift:125-141`). |
| `mark_text` | Finds OCR lines with `Analyzer.find` and marks each match as arrow, box, highlight, blur, redact or step (`Agent.swift:143-191`). |
| `redact_sensitive` | Covers [[Analysis]] sensitive regions, optionally filtered by [[SensitiveKind]], using `Analyzer.redactions` (`Agent.swift:193-201`). |
| `list_annotations` | Returns `describeAnnotations()`: short id, kind, rect in model pixels (`Agent.swift:116-123`). |
| `remove_annotations` | By 6-char short id or full UUID, or `all=true` (`Agent.swift:89-94`). |
| `crop` | Sets or resets the crop; rejects crops smaller than 4 px or outside the image (`Agent.swift:95-104`). |
| `set_name_and_tags` | Renames the capture (80 chars max) and lowercases tags (`Agent.swift:105-108`). |

## Behaviour

- Default line width and font size come from `Annotation.defaultLineWidth(for:)` and `defaultFontSize(for:)` (`Agent.swift:28-29`).
- Points are clamped to the image (`Agent.swift:36-38`); redact always uses black (`Agent.swift:132`).
- Unknown tool names return an error result rather than throwing (`Agent.swift:109-110`).

## Called by

- [[EditAgent]] creates one per run and calls `execute` for each tool call (`Sources/PinpointCore/Agent.swift:214`, `:245`), and passes `AgentToolbox.tools` to the [[LLMClient]] (`:239`).

## Related

[[EditAgent]] · [[AgentState]] · [[Analyzer]] · [[Analysis]] · [[Annotation]] · [[ToolSpec]] · [[JSONValue]]

## Tested by

- `AgentToolboxTests` (`Tests/PinpointCoreTests/CoreTests.swift:116`): mark_text arrow, scale conversion, redact by kind, step numbering and removal, missing-text errors.

## Sources

- `Sources/PinpointCore/Agent.swift` (lines 16-202)
