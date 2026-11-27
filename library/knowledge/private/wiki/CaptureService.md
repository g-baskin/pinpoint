---
type: entity
title: "CaptureService"
entity: CaptureService
kind: enum
entity_type: service
target: Pinpoint
path: "Sources/Pinpoint/CaptureService.swift"
lines: "5-161"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[Renderer]]"
used_by:
  - "[[AppDelegate]]"
  - "[[SelectionOverlay]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - capture
related:
  - "[[AppDelegate]]"
  - "[[SelectionOverlay]]"
---

# CaptureService (and WindowInfo, CaptureError)

## Purpose

Screen and window **capture** using ScreenCaptureKit (`Sources/Pinpoint/CaptureService.swift:23`), plus the Screen Recording permission help flow and the on-screen window list used by window picking.

## API (internal)

```swift
struct WindowInfo {
    let id: CGWindowID
    let owner: String
    let title: String
    let frame: CGRect   // global CG coordinates (top-left origin of the main display)
}

enum CaptureError: LocalizedError {
    case noPermission, noDisplay, noWindow
    var errorDescription: String?
}

@MainActor
enum CaptureService {
    static func hasPermission() -> Bool
    static func isPermissionError(_ error: Error) -> Bool
    static func showPermissionHelp()
    static func relaunch()
    static func openSettings()
    static func screenUnderMouse() -> NSScreen
    static func displayID(_ screen: NSScreen) -> CGDirectDisplayID
    static func cgOrigin(_ screen: NSScreen) -> CGPoint
    static func captureScreen(_ screen: NSScreen) async throws -> CGImage
    static func captureAllScreens() async throws -> CGImage
    static func captureWindow(_ windowID: CGWindowID, scale: CGFloat) async throws -> CGImage
    static func visibleWindows() -> [WindowInfo]
}
```

## Behaviour

- `isPermissionError` treats any `CaptureError`, code -3801 (user declined) or a failed preflight as a permission problem (`CaptureService.swift:29-32`).
- `showPermissionHelp` asks macOS once, never resets an existing grant, and offers Restart Pinpoint, Open System Settings or Cancel, since macOS applies a new grant only after a restart (`CaptureService.swift:34-55`). `relaunch` reopens the bundle after 1.5 s through a `/bin/sh` helper, then quits; if the helper can't be launched it shows a "Couldn't restart Pinpoint" alert and does not quit (`:58-71`).
- `captureScreen` captures one display at its backing scale, excluding Pinpoint's own windows, without the cursor (`CaptureService.swift:94-107`).
- `captureAllScreens` stitches every display into one image laid out as arranged in System Settings, at the highest backing scale (`CaptureService.swift:110-131`).
- `captureWindow` captures one window independent of what covers it, without its shadow (`CaptureService.swift:133-144`).
- `visibleWindows` lists normal layer-0 windows of other apps, larger than 40 px, front to back (`CaptureService.swift:147-160`).

## Called by

- [[AppDelegate]] `applicationDidFinishLaunching`, `capture(_:)`, `handleSelection` (`Sources/Pinpoint/AppDelegate.swift:32`, `:121-150`, `:160-166`).
- [[SelectionOverlay]] (`SelectionView.windowRect`) uses `cgOrigin`; `WindowInfo` appears in `SelectionResult` (`Sources/Pinpoint/SelectionOverlay.swift:6`, `:116`).

## Related

[[AppDelegate]] · [[SelectionOverlay]] · [[Renderer]] · [[UIRegionDetector]]

> [!note] Build coupling
> Screen Recording permission is tied to the code signature; `scripts/build-app.sh` and `scripts/release.sh` read `CFBundleIdentifier` from `Resources/Info.plist` for the ad-hoc signature.

## Sources

- `Sources/Pinpoint/CaptureService.swift` (lines 5-161)
