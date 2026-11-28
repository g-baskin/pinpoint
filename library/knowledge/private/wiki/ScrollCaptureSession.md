---
type: entity
title: "ScrollCaptureSession"
entity: ScrollCaptureSession
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/ScrollCaptureSession.swift"
lines: "8-190"
language: swift
status: developing
partial_scan: false
last_commit_hash: "d4cea7c"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[ScrollStitcher]]"
  - "[[CaptureService]]"
used_by:
  - "[[AppDelegate]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - capture
related:
  - "[[ScrollStitcher]]"
  - "[[AppDelegate]]"
  - "[[SelectionOverlay]]"
---

# ScrollCaptureSession (and Status, OutlineView, ScrollCaptureBar)

## Purpose

Runs one **scrolling capture**: outlines the picked region, grabs it several times a second while the user scrolls it by hand, and stitches the frames with [[ScrollStitcher]] (`Sources/Pinpoint/ScrollCaptureSession.swift:6-8`). Pinpoint never scrolls the page itself, so no Accessibility permission is needed; only Screen Recording.

## API (internal)

```swift
@MainActor
final class ScrollCaptureSession {
    final class Status: ObservableObject { height: Int; message: String; warning: Bool }
    init(screen: NSScreen, rect: CGRect, scale: CGFloat, previousApp: NSRunningApplication?, completion: @escaping (CGImage?) -> Void)
    func start() async throws
    func finish()
    func cancel()
}
```

`rect` is in points relative to the screen's top-left (`ScrollCaptureSession.swift:16`). Grouped private types: `OutlineView` (`:159-167`) and the SwiftUI `ScrollCaptureBar` (`:169-190`).

## Behaviour

- `start()` takes the first frame with `SCScreenshotManager`, so permission errors surface there; the filter leaves out Pinpoint's own windows so the outline and controls never appear in frames (`ScrollCaptureSession.swift:34-48`).
- It then shows the windows and reactivates the previously frontmost app so the trackpad, wheel and keyboard reach the page (`ScrollCaptureSession.swift:50-53`).
- The loop captures, stitches off the main actor, updates the status, then sleeps 80 ms; capture errors show "Capture paused" without stopping (`ScrollCaptureSession.swift:55-68`).
- Status text warns on `.lostTrack` ("Lost the place…") and `.full` ("Maximum length reached…") (`ScrollCaptureSession.swift:91-104`).
- The outline is a dashed blue border at status-bar level that ignores mouse events, so scrolls and clicks go to the page (`ScrollCaptureSession.swift:112-123`, `:159-167`). The non-activating control panel shows the message, the height in px, "⌃⇧5 also finishes", Cancel and Done; it sits below the region, else above, else inside the bottom edge (`:125-151`, `:174-189`).
- `finish()` waits for the loop, then calls `completion` with `makeImage()`; `cancel()` calls it with `nil`. Both run once (`ScrollCaptureSession.swift:72-89`).

## Called by

- [[AppDelegate]] `startScrolling`, after [[SelectionOverlay]] returns `.scrolling`; Control-Shift-5 during a session calls `finish()` (`Sources/Pinpoint/AppDelegate.swift:125`, `:190-203`).

## Related

[[ScrollStitcher]] · [[AppDelegate]] · [[SelectionOverlay]] · [[CaptureService]]

## Sources

- `Sources/Pinpoint/ScrollCaptureSession.swift` (lines 1-190)
