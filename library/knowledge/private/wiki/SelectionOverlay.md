---
type: entity
title: "SelectionOverlay"
entity: SelectionOverlay
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/SelectionOverlay.swift"
lines: "4-384"
language: swift
status: developing
partial_scan: false
last_commit_hash: "d4cea7c"
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
  - "[[ScrollCaptureSession]]"
---

# SelectionOverlay (and SelectionResult, SelectionView)

## Purpose

The full-screen picker shown over a frozen screenshot for area, window and scrolling **capture modes**. Drag selects a region; click selects a window or panel; the screen edge, F or Return selects the whole screen; A selects all screens; S makes the next pick a scrolling capture; Esc or right-click cancels (`Sources/Pinpoint/SelectionOverlay.swift:12-13`).

## API (internal)

```swift
enum SelectionResult {
    case region(CGRect)          // pixels in the frozen screen image
    case window(WindowInfo, CGRect) // the window + its rect in frozen-image pixels
    case allScreens                 // every display stitched together
    case scrolling(CGRect)          // pixels in the frozen screen image, for a scrolling capture
    case cancelled
}

final class SelectionOverlay: NSWindow {
    let targetScreen: NSScreen
    init(screen: NSScreen, frozen: CGImage, windows: [WindowInfo], preferWindow: Bool, scrolling: Bool = false, completion: @escaping (SelectionResult) -> Void)
    func present(makeKey: Bool)
    func dismiss()
}
```

Grouped private view: `private final class SelectionView: NSView` (`SelectionOverlay.swift:58-384`) does all drawing and input.

## Behaviour

- The window sits at screen-saver level on all Spaces (`SelectionOverlay.swift:20-26`). `present(makeKey:)` gives focus to one overlay; `dismiss()` closes without reporting, used when the selection finished on another screen (`:37-46`).
- Smart selection: unless `preferWindow`, hovering a window runs `UIRegionDetector.detect` on it (cached per window id) and highlights the smallest panel under the mouse; scroll or arrow keys step out to bigger or in to smaller parts (`SelectionOverlay.swift:154-184`, `:379-380`).
- Within 10 points of a screen edge the whole screen is targeted (`SelectionOverlay.swift:137-140`).
- A bottom toolbar offers Full Screen (F), All Screens (A), Scrolling (S) and Cancel (`SelectionOverlay.swift:69-80`, `:202-217`).
- Scroll mode: the `scrolling` init flag (true for `CaptureMode.scrolling`) sets `scrollMode`; the Scrolling button or the S key toggles it. While on, the Scrolling button stays highlighted and the hint reads "Scrolling capture: click the part that scrolls… · S to turn off" (`SelectionOverlay.swift:93-98`, `:248-251`, `:269`, `:315`, `:320`, `:378`).
- `pick(_:window:)` reports every pick: `.scrolling(rect)` in scroll mode, otherwise `.window` when a window is given, else `.region` (`SelectionOverlay.swift:322-325`).
- Every drawn rect passes `isUsable` because null or NaN rects crash NSBezierPath, and labels pass `safeLabel` to strip emoji that crashed CoreText (`SelectionOverlay.swift:186-189`, `:282-295`).
- On mouse up, through `pick`: a drag of 4+ px gives the dragged rect, a window hover the window, a panel its rect, otherwise the full screen; F, Return and the Full Screen button also go through `pick` (`SelectionOverlay.swift:312`, `:358-370`, `:376`).

## Called by

- [[AppDelegate]] `capture(_:)` creates one per screen and handles the result in `handleSelection` (`Sources/Pinpoint/AppDelegate.swift:145-157`, `:166-188`); `.scrolling` goes to `startScrolling` and a [[ScrollCaptureSession]].

## Related

[[AppDelegate]] · [[UIRegionDetector]] · [[CaptureService]] · [[ScrollCaptureSession]]

## Sources

- `Sources/Pinpoint/SelectionOverlay.swift` (lines 4-384)
