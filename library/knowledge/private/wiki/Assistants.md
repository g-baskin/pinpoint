---
type: entity
title: "Assistants"
entity: Assistants
kind: struct
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Assistants.swift"
lines: "5-53"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LLMClient]]"
  - "[[ImageFiles]]"
  - "[[JSONValue]]"
  - "[[LLMError]]"
  - "[[GuideBuilder]]"
used_by:
  - "[[EditorModel]]"
  - "[[AppDelegate]]"
  - "[[LibraryModel]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - assistant
related:
  - "[[LLMClient]]"
  - "[[GuideBuilder]]"
  - "[[AssistantPanel]]"
---

# Assistants

## Purpose

The **assistant**: one-shot AI helpers built on any [[LLMClient]] (`Sources/PinpointCore/Assistants.swift:5`): summarize, name and tag, and write a **guide**.

## API

```swift
public struct Assistants: Sendable {
    public let client: LLMClient
    public init(client: LLMClient)

    public func summarize(image: CGImage, ocrText: String) async throws -> String
    public func nameAndTags(image: CGImage, ocrText: String, app: String?) async throws -> (name: String, tags: [String])
    public func writeGuide(steps: [GuideStep], title: String?) async throws -> String
}
```

## Behaviour

- `summarize`: image downscaled to 1280 px, OCR text capped at 6000 chars, 800 max tokens (`Assistants.swift:10-16`).
- `nameAndTags`: asks for JSON `{"name", "tags"}`, parses it with `extractJSONObject`, throws [[LLMError]] if no name; caps name at 80 chars and tags at 8, lowercased (`Assistants.swift:18-35`). The prompt tells the model never to put secrets or personal data in names or tags (`:24`).
- `writeGuide`: sends every step image (1024 px) with its name and OCR text and asks for Markdown with a `{{image N}}` placeholder per step (`Assistants.swift:37-52`). [[GuideBuilder]] replaces those placeholders.

## Called by

- [[EditorModel]] `summarize()` and `nameAndTag()` (`Sources/Pinpoint/EditorModel.swift:315`, `:325`).
- [[AppDelegate]] `postProcess` for AI naming after a capture (`Sources/Pinpoint/AppDelegate.swift:212`).
- [[LibraryModel]] `autoTag()` and `makeGuide()` (`Sources/Pinpoint/LibraryView.swift:78`, `:103`).

## Related

[[LLMClient]] · [[GuideBuilder]] · [[ImageFiles]] · [[JSONValue]] · [[AssistantPanel]] · [[LibraryModel]]

## Sources

- `Sources/PinpointCore/Assistants.swift` (lines 5-53)
