---
type: entity
title: "SelectionOverlay"
entity: SelectionOverlay
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/SelectionOverlay.swift"
lines: "4-365"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[CaptureService]]"
  - "[[UIRegionDetector]]"
used_by:
  - "[[AppDelegate]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - capture
related:
  - "[[AppDelegate]]"
  - "[[UIRegionDetector]]"
  - "[[CaptureService]]"
---

# SelectionOverlay (and SelectionResult, SelectionView)

## Purpose

The full-screen picker shown over a frozen screenshot for area and window **capture modes**. Drag selects a region; click selects a window or panel; the screen edge, F or Return selects the whole screen; A selects all screens; Esc or right-click cancels (`Sources/Pinpoint/SelectionOverlay.swift:11`).

## API (internal)

```swift
enum SelectionResult {
    case region(CGRect)          // pixels in the frozen screen image
    case window(WindowInfo, CGRect) // the window + its rect in frozen-image pixels
    case allScreens                 // every display stitched together
    case cancelled
}

final class SelectionOverlay: NSWindow {
    let targetScreen: NSScreen
    init(screen: NSScreen, frozen: CGImage, windows: [WindowInfo], preferWindow: Bool, completion: @escaping (SelectionResult) -> Void)
    func present(makeKey: Bool)
    func dismiss()
}
```

Grouped private view: `private final class SelectionView: NSView` (`SelectionOverlay.swift:56-365`) does all drawing and input.

## Behaviour

- The window sits at screen-saver level on all Spaces (`SelectionOverlay.swift:20-26`). `present(makeKey:)` gives focus to one overlay; `dismiss()` closes without reporting, used when the selection finished on another screen (`:37-46`).
- Smart selection: unless `preferWindow`, hovering a window runs `UIRegionDetector.detect` on it (cached per window id) and highlights the smallest panel under the mouse; scroll or arrow keys step out to bigger or in to smaller parts (`SelectionOverlay.swift:136-177`, `:360-361`).
- Within 10 points of a screen edge the whole screen is targeted (`SelectionOverlay.swift:85`, `:131-133`).
- A bottom toolbar offers Full Screen, All Screens and Cancel (`SelectionOverlay.swift:67-76`, `:196-209`).
- Every drawn rect passes `isUsable` because null or NaN rects crash NSBezierPath, and labels pass `safeLabel` to strip emoji that crashed CoreText (`SelectionOverlay.swift:179-182`, `:270-283`).
- On mouse up: a drag of 4+ px gives `.region`, a window hover gives `.window`, a panel gives `.region`, otherwise the full screen (`SelectionOverlay.swift:340-353`).

## Called by

- [[AppDelegate]] `capture(_:)` creates one per screen and handles the result in `handleSelection` (`Sources/Pinpoint/AppDelegate.swift:137-146`, `:155-172`).

## Related

[[AppDelegate]] · [[UIRegionDetector]] · [[CaptureService]]

## Sources

- `Sources/Pinpoint/SelectionOverlay.swift` (lines 4-365)
