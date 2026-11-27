---
type: entity
title: "EditAgent"
entity: EditAgent
kind: class
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Agent.swift"
lines: "204-253"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LLMClient]]"
  - "[[AgentToolbox]]"
  - "[[AgentState]]"
  - "[[Analysis]]"
  - "[[ImageFiles]]"
  - "[[ChatMessage]]"
  - "[[ChatResponse]]"
  - "[[RGBA]]"
used_by:
  - "[[EditorModel]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:186 AgentLoopTests"
tags:
  - entity
  - pinpointcore
  - agent
related:
  - "[[AgentToolbox]]"
  - "[[EditorModel]]"
  - "[[LLMClient]]"
---

# EditAgent

## Purpose

The **agent**: a tool-using loop that shows the model the screenshot plus OCR, lets it call tools and returns the edited state (`Sources/PinpointCore/Agent.swift:204`).

## API

```swift
public final class EditAgent: @unchecked Sendable {
    public let client: LLMClient
    public var maxSteps: Int

    public init(client: LLMClient, maxSteps: Int = 12)

    public func run(instruction: String, image: CGImage, analysis: Analysis, state: AgentState, color: RGBA = .red,
                    onEvent: @escaping @Sendable (String) -> Void = { _ in }) async throws -> (state: AgentState, reply: String)
}
```

## Behaviour

1. Downscales the image with `ImageFiles.forModel` and builds an [[AgentToolbox]] using the returned scale (`Agent.swift:213-214`).
2. Sends a system prompt plus one user message holding the PNG and a context block: up to 250 OCR lines with model-space rects, sensitive counts, current markup, capture name and the request (`Agent.swift:215-236`).
3. Loops up to `maxSteps` times: checks cancellation, calls `client.send(..., tools: AgentToolbox.tools, maxTokens: 2048)`, runs every tool call through `box.execute`, reports each result via `onEvent`, and appends tool results (`Agent.swift:237-250`).
4. Returns when the model replies without tool calls (reply defaults to "Done."), or after `maxSteps` with "Stopped after N steps." (`Agent.swift:242`, `:251`).

## Called by

- [[EditorModel]] `runAgent(_:)` (`Sources/Pinpoint/EditorModel.swift:344-345`), driven from the [[AssistantPanel]] prompt field.

## Related

[[AgentToolbox]] · [[AgentState]] · [[LLMClient]] · [[ImageFiles]] · [[Analysis]] · [[EditorModel]] · [[AssistantPanel]]

## Tested by

- `AgentLoopTests.testLoopAppliesToolsAndReturnsReply` with a scripted client (`Tests/PinpointCoreTests/CoreTests.swift:186-187`).

## Sources

- `Sources/PinpointCore/Agent.swift` (lines 204-253)
