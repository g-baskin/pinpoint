---
type: entity
title: "ScrollStitcher"
entity: ScrollStitcher
kind: class
entity_type: class
target: PinpointCore
path: "Sources/PinpointCore/ScrollStitcher.swift"
lines: "6-159"
language: swift
status: developing
partial_scan: false
last_commit_hash: "d4cea7c"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[ScrollCaptureSession]]"
tested_by:
  - "Tests/PinpointCoreTests/ScrollStitcherTests.swift"
tags:
  - entity
  - pinpoint-core
  - capture
related:
  - "[[ScrollCaptureSession]]"
---

# ScrollStitcher (and Step, Options)

## Purpose

Joins frames of one screen region, captured while its content scrolls, into one tall image. Rows that stay put between frames (sticky headers and footers) appear once. Not thread-safe: use one instance from one task at a time (`Sources/PinpointCore/ScrollStitcher.swift:4-6`).

## API (public)

```swift
public final class ScrollStitcher: @unchecked Sendable {
    public enum Step: Equatable { case started, unchanged, added(Int), lostTrack, full }
    public struct Options {
        public var scrollbarMargin: Int   // right-edge columns ignored when matching (overlay scrollbars)
        public var maxPixels: Int         // largest result, width × height
        public init(scrollbarMargin: Int = 0, maxPixels: Int = 50_000_000)
    }
    public init(options: Options = Options())
    public var height: Int
    @discardableResult public func add(_ image: CGImage) -> Step
    public func makeImage() -> CGImage?
}
```

## Behaviour

- Each frame is drawn to sRGB RGBA and a luma plane (`ScrollStitcher.swift:134-150`). A frame of a different size returns `.lostTrack` (`:49`).
- Only the columns that changed are matched, so a static area beside the scrolling part can't hide the match (`ScrollStitcher.swift:53-66`). Rows identical at the top and bottom of both frames are treated as sticky header and footer (`:68-74`).
- Rows are hashed (FNV-style over luma with the low 2 bits dropped); rows with little contrast are not "informative" and don't count (`ScrollStitcher.swift:120-131`). Every shift is scored by the share of matching informative rows; the best one needs a score of at least 0.8, else `.lostTrack` (`:79-91`, `:35`).
- New rows are appended to the canvas; scrolling back over known content adds 0 rows (`ScrollStitcher.swift:94-97`, `:109-118`). Reaching `maxPixels` sets `.full` and later frames are ignored (`:50`, `:114-115`).
- `makeImage()` returns the canvas plus the last frame's sticky footer, or the single frame if nothing scrolled (`ScrollStitcher.swift:101-106`).

## Called by

- [[ScrollCaptureSession]], with `scrollbarMargin` of 20 points in pixels (`Sources/Pinpoint/ScrollCaptureSession.swift:30`, `:48`, `:60`, `:77`).

## Tests

`ScrollStitcherTests`: sticky header and footer kept once, a single frame comes back unchanged, and the size limit (`Tests/PinpointCoreTests/ScrollStitcherTests.swift:41`, `:59`, `:67`).

## Related

[[ScrollCaptureSession]]

## Sources

- `Sources/PinpointCore/ScrollStitcher.swift` (lines 1-159)
