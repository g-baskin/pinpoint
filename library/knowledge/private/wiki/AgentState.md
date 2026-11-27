---
type: entity
title: "AgentState"
entity: AgentState
kind: struct
entity_type: data-model
target: PinpointCore
path: "Sources/PinpointCore/Agent.swift"
lines: "4-14"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Annotation]]"
used_by:
  - "[[AgentToolbox]]"
  - "[[EditAgent]]"
  - "[[EditorModel]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:116 AgentToolboxTests"
  - "Tests/PinpointCoreTests/CoreTests.swift:186 AgentLoopTests"
tags:
  - entity
  - pinpointcore
  - agent
related:
  - "[[AgentToolbox]]"
  - "[[EditAgent]]"
  - "[[EditorModel]]"
---

# AgentState

## Purpose

The editable state the **agent** works on: the capture's markup items, crop, name, tags and image size. The doc comment says it is applied to the editor as one undoable step when the run ends (`Sources/PinpointCore/Agent.swift:4`).

## API

```swift
public struct AgentState: Equatable, Sendable {
    public var annotations: [Annotation]
    public var crop: CGRect?
    public var name: String
    public var tags: [String]
    public var imageSize: CGSize
    public init(annotations: [Annotation], crop: CGRect?, name: String, tags: [String], imageSize: CGSize)
}
```

## Behaviour

- Plain value type; `Equatable` lets [[EditorModel]] skip a checkpoint when the agent changed nothing (`Sources/Pinpoint/EditorModel.swift:349`).

## Called by

- [[EditorModel]] builds one from the open capture in `runAgent(_:)` (`Sources/Pinpoint/EditorModel.swift:344`).
- [[AgentToolbox]] holds and mutates it as `state` (`Sources/PinpointCore/Agent.swift:19`).
- [[EditAgent]] takes it in `run(...)` and returns the edited copy (`Sources/PinpointCore/Agent.swift:211-212`).

## Related

[[AgentToolbox]] · [[EditAgent]] · [[Annotation]] · [[EditorModel]]

## Sources

- `Sources/PinpointCore/Agent.swift` (lines 4-14)
