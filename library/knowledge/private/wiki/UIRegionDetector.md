---
type: entity
title: "UIRegionDetector"
entity: UIRegionDetector
kind: enum
entity_type: service
target: PinpointCore
path: "Sources/PinpointCore/UIRegionDetector.swift"
lines: "4-168"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on: []
used_by:
  - "[[SelectionOverlay]]"
tested_by:
  - "Tests/PinpointCoreTests/ProviderTests.swift:133 UIRegionTests"
tags:
  - entity
  - pinpointcore
  - capture
related:
  - "[[SelectionOverlay]]"
---

# UIRegionDetector

## Purpose

Finds UI structure (toolbars, sidebars, panels, dialogs) inside a window screenshot, with no permissions needed. It uses a recursive XY-cut: a row or column where almost every pixel differs sharply from its neighbour is a separator, so the window is split there and the process repeats inside (`Sources/PinpointCore/UIRegionDetector.swift:4-6`).

## API

```swift
public enum UIRegionDetector {
    public struct Node: Equatable, Sendable {
        public var rect: CGRect          // pixels in the source image
        public var children: [Node]
        public init(rect: CGRect, children: [Node] = [])
        public func path(to p: CGPoint) -> [CGRect]
        public var count: Int
    }

    public struct Options: Sendable {
        public var maxWorkingDimension = 1100   // analyse a downscaled copy for speed
        public var edgeThreshold: Int = 14      // 0-255 luminance step that counts as an edge
        public var coverage: Double = 0.88      // fraction of the span that must be edge to count as a cut
        public var minRegion: Int = 24          // working-pixel minimum panel size
        public var maxDepth = 5
        public init() {}
    }

    public static func detect(image: CGImage, in rect: CGRect, options: Options = Options()) -> Node
}
```

Internal: `IRect`, `WNode`, `Grid`, `map`, `cuts`, `split`, `componentBoxes` (`UIRegionDetector.swift:50-167`).

## Behaviour

- `detect` crops to `rect`, draws a grey copy at most 1100 px, splits it and maps the tree back to source pixels (`UIRegionDetector.swift:31-48`).
- `split` alternates horizontal and vertical cuts up to `maxDepth`; a single thin strip does not add a level (`UIRegionDetector.swift:86-106`). With no full-span cut it looks for self-contained boxes on a plain background (dialogs, cards, popovers) by connected components (`:107-113`, `:116-167`).
- `Node.path(to:)` returns the nested regions containing a point, outermost first (`UIRegionDetector.swift:14-18`).

## Called by

- The private `SelectionView` inside [[SelectionOverlay]], for smart selection of panels inside a window; results are cached per window id (`Sources/Pinpoint/SelectionOverlay.swift:86`, `:136-146`).

## Related

[[SelectionOverlay]] · [[CaptureService]]

## Tested by

- `UIRegionTests` (`Tests/PinpointCoreTests/ProviderTests.swift:133-173`).

## Sources

- `Sources/PinpointCore/UIRegionDetector.swift` (lines 4-168)
