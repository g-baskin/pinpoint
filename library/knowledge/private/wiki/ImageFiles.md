---
type: entity
title: "ImageFiles"
entity: ImageFiles
kind: enum
entity_type: module
target: PinpointCore
path: "Sources/PinpointCore/ImageIO.swift"
lines: "7-49"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[LibraryStore]]"
  - "[[EditAgent]]"
  - "[[Assistants]]"
  - "[[GuideBuilder]]"
  - "[[EditorModel]]"
  - "[[AppDelegate]]"
  - "[[LibraryModel]]"
  - "[[MainView]]"
tested_by: []
tags:
  - entity
  - pinpointcore
  - images
related:
  - "[[LibraryStore]]"
  - "[[EditAgent]]"
---

# ImageFiles

## Purpose

Image loading, encoding, writing and downscaling with ImageIO and CoreGraphics, including the PNG prepared for vision models.

## API

```swift
public enum ImageFiles {
    public static func load(_ url: URL) -> CGImage?
    public static func encode(_ image: CGImage, type: UTType = .png, quality: Double = 0.9) -> Data?
    public static func write(_ image: CGImage, to url: URL, type: UTType = .png, quality: Double = 0.9) throws
    public static func downscaled(_ image: CGImage, maxDimension: Int) -> (CGImage, CGFloat)
    public static func forModel(_ image: CGImage, maxDimension: Int = 1568) -> (data: Data, scale: CGFloat, size: CGSize)
}
```

## Behaviour

- `write` throws an `NSError` in domain "Pinpoint" when encoding fails and writes atomically (`Sources/PinpointCore/ImageIO.swift:21-26`).
- `downscaled` returns the image and scale (at most 1) so the long edge is at most `maxDimension` (`ImageIO.swift:29-41`).
- `forModel` returns PNG bytes, the scale from original to sent pixels, and the sent size (`ImageIO.swift:44-48`); [[EditAgent]] uses the scale for [[AgentToolbox]] coordinates.

## Called by

- [[LibraryStore]] for originals, renders and thumbnails (`Sources/PinpointCore/Library.swift:60`, `:72`, `:84-85`, `:99-103`).
- [[EditAgent]], [[Assistants]], [[GuideBuilder]] (`Agent.swift:213`, `Assistants.swift:11`, `:80`).
- [[EditorModel]] copy and export; [[AppDelegate]] copy after capture and Open Image; [[LibraryModel]] copy; `ShareButton` in [[MainView]].

## Related

[[LibraryStore]] · [[EditAgent]] · [[Assistants]] · [[Renderer]]

## Sources

- `Sources/PinpointCore/ImageIO.swift` (lines 7-49)
