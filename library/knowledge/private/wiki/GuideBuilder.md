---
type: entity
title: "GuideBuilder"
entity: GuideBuilder
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/Assistants.swift"
lines: "55-104"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ImageFiles]]"
  - "[[Markdown]]"
used_by:
  - "[[LibraryModel]]"
  - "[[Assistants]]"
tested_by:
  - "Tests/PinpointCoreTests/CoreTests.swift:251 GuideTests"
tags:
  - entity
  - pinpointcore
  - guide
related:
  - "[[Assistants]]"
  - "[[Markdown]]"
  - "[[LibraryModel]]"
---

# GuideBuilder (and GuideStep)

## Purpose

Builds a **guide**: a step-by-step document (`guide.md`, `guide.html`, `images/`) made from several captures in order. `GuideStep` is one input capture.

## API

```swift
public struct GuideStep: Sendable {
    public var image: CGImage
    public var name: String
    public var ocrText: String
    public init(image: CGImage, name: String, ocrText: String)
}

public enum GuideBuilder {
    public static func fallbackMarkdown(steps: [GuideStep], title: String) -> String
    public static func write(markdown: String, steps: [GuideStep], title: String, to parent: URL) throws -> URL
}
```

## Behaviour

- `fallbackMarkdown` is the offline guide: a title and one `## Step N` section per screenshot with a `{{image N}}` placeholder (`Sources/PinpointCore/Assistants.swift:66-70`).
- `write` creates `"<title up to 60 chars> <timestamp>"` under `parent` with unsafe filename characters replaced, writes `images/step-N.png`, replaces each `{{image N}}` with an image link, appends any image the model forgot to place, and writes `guide.md` and `guide.html` (via [[Markdown]]). Returns the folder (`Assistants.swift:73-103`).

## Called by

- [[LibraryModel]] `makeGuide()` builds `GuideStep`s from the selected captures in pick order and calls both functions; guides go to `<library root>/Guides` (`Sources/Pinpoint/LibraryView.swift:85-103`).
- [[Assistants]] `writeGuide(steps:title:)` takes `[GuideStep]` (`Sources/PinpointCore/Assistants.swift:38`).

## Related

[[Assistants]] · [[Markdown]] · [[ImageFiles]] · [[LibraryModel]] · [[LibraryView]]

## Tested by

- `GuideTests.testWritesGuideWithAllImages` (`Tests/PinpointCoreTests/CoreTests.swift:252`).

## Sources

- `Sources/PinpointCore/Assistants.swift` (lines 55-104)
