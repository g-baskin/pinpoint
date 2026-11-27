---
type: entity
title: "Markdown"
entity: Markdown
kind: enum
entity_type: module
target: PinpointCore
path: "Sources/PinpointCore/Assistants.swift"
lines: "106-151"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[GuideBuilder]]"
tested_by:
  - "[[MarkdownSafetyTests]]"
tags:
  - entity
  - pinpointcore
  - guide
related:
  - "[[GuideBuilder]]"
---

# Markdown

## Purpose

A tiny Markdown to HTML converter covering what guides use: headings, paragraphs, lists, images, bold, italics and code (`Sources/PinpointCore/Assistants.swift:106`).

## API

```swift
public enum Markdown {
    public static func escape(_ s: String) -> String
    public static func toHTML(_ md: String) -> String
}
```

Internal: `static func inline(_ s: String) -> String` applies regex rules for images, links, bold, italics and code after escaping (`Assistants.swift:112-123`).

## Behaviour

- `escape` replaces `&`, `<`, `>` and `"` (`Assistants.swift:108-111`).
- Image and link URLs must be relative, `http(s)://` or `mailto:`; anything else (such as `javascript:`) stays as plain text, because guide text comes from the model.
- `toHTML` walks lines: `#` headings, `-`/`*` bullet lists, `1.`/`1)` ordered lists, everything else joined into paragraphs; blank lines close paragraphs and lists (`Assistants.swift:125-150`).

## Called by

- [[GuideBuilder]] `write(...)` for `guide.html` and its `<title>` (`Sources/PinpointCore/Assistants.swift:95`, `:99`).

## Related

[[GuideBuilder]]

## Sources

- `Sources/PinpointCore/Assistants.swift` (lines 106-151)
