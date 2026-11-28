---
type: entity
title: "AppDelegate"
entity: AppDelegate
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/AppDelegate.swift"
lines: "1-345"
language: swift
status: developing
partial_scan: false
last_commit_hash: "d4cea7c"
created: 2026-11-27
updated: 2026-11-27
depends_on:
  - "[[LibraryStore]]"
  - "[[Workspace]]"
  - "[[MainWindowController]]"
  - "[[SelectionOverlay]]"
  - "[[CaptureService]]"
  - "[[HotKeyCenter]]"
  - "[[AppSettings]]"
  - "[[EditorModel]]"
  - "[[Analyzer]]"
  - "[[Assistants]]"
  - "[[ImageFiles]]"
  - "[[SettingsView]]"
  - "[[ScrollCaptureSession]]"
used_by:
  - "[[MainView]]"
  - "[[MainWindowController]]"
  - "[[AssistantPanel]]"
tested_by: []
tags:
  - entity
  - pinpoint
  - app
  - capture
related:
  - "[[Workspace]]"
  - "[[CaptureService]]"
  - "[[SelectionOverlay]]"
  - "[[ScrollCaptureSession]]"
---

# AppDelegate (and CaptureMode, main.swift)

## Purpose

The app's entry point and coordinator: menu bar item and main menu, global hotkeys, the **capture** flow for each **capture mode**, background OCR and naming, and the single main and settings windows. `main.swift` creates it and runs the app (`Sources/Pinpoint/main.swift:3-6`). The app target has no tests (project AGENTS.md).

## API (internal)

```swift
enum CaptureMode { case area, window, screen, allScreens, scrolling }

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    let library = LibraryStore()
    lazy var workspace = Workspace(store: library)

    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationWillTerminate(_ notification: Notification)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
    @objc func captureArea()
    @objc func captureWindow()
    @objc func captureScreen()
    @objc func captureAllScreens()
    @objc func captureScrolling()
    @objc func showLibraryAction()
    @objc func showMainAction()
    @objc func showSettingsAction()
    @objc func quit()
    func capture(_ mode: CaptureMode)
    @discardableResult
    func openEditor(meta: CaptureMeta, image: CGImage) -> EditorModel?
    func openEditor(id: UUID)
    func showMain(mode: Workspace.Mode? = nil)
    func mainWindowClosed()
    @objc func openImage()
    func showLibrary()
    func showSettings()
}
```

`main.swift` (whole file):

```swift
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
```

## Behaviour

- Launch: accessory activation policy, menus, then hotkeys via [[HotKeyCenter]]: Control-Shift-1 area, -2 window, -3 screen, -4 all screens, -5 scrolling capture (hotkey id 6), -L library (`AppDelegate.swift:21-37`). It does not prompt for Screen Recording at launch; it only asks after a capture fails (`:33`, `:160-161`).
- Menus: "Scrolling Capture" (Control-Shift-5) in the menu bar item and the File menu, both calling `captureScrolling` (`AppDelegate.swift:67`, `:95`, `:115`).
- `capture(_:)`: screen and all-screens capture directly through [[CaptureService]]; area and window freeze every display and show a [[SelectionOverlay]] on each, with keyboard focus on the screen under the mouse (`AppDelegate.swift:123-163`). Window mode grabs the window itself; area mode crops the frozen image (`:166-188`).
- Scrolling capture: `.scrolling` shows the overlays with `scrolling: true`; a `.scrolling` result is converted from pixels to points and passed to `startScrolling`, which creates a [[ScrollCaptureSession]] held in `scrollSession` and calls `start()`. Its completion clears `scrollSession` and runs `finishCapture` (or ends the capture on cancel); a start failure shows the permission help or an error (`AppDelegate.swift:146-147`, `:184-203`). The user scrolls by hand, so no Accessibility permission is needed.
- While a session is active, `capture(_:)` ignores other modes, and the scrolling hotkey or menu item finishes the session (`AppDelegate.swift:124-125`).
- `finishCapture` creates the capture in [[LibraryStore]], posts `pinpointLibraryChanged`, optionally copies the PNG, opens the editor and triggers auto-redact once [[EditorModel]] has its analysis (polls up to 40 times every 0.25 s) (`AppDelegate.swift:205-226`).
- `postProcess` runs off the main actor: OCR without faces, the offline name from `Analyzer.suggestedName`, then optional AI name and tags via [[Assistants]]; it avoids overwriting edits made meanwhile in an open editor, merging into the editor's meta and saving the result with a single `writeMeta` (`AppDelegate.swift:228-263`). `makeClient`, AI naming and `writeMeta` failures are logged with `PinpointLog` rather than ignored; the offline name still applies when AI fails (`:233`, `:245`, `:258-259`).
- `openImage` imports each chosen file; unreadable images and failed `library.create` calls are collected and reported in one error alert ("Couldn't open N files:" plus a line per file) after the rest open (`AppDelegate.swift:292-309`).
- Shows in the Dock only while a window is open (`AppDelegate.swift:329-338`).

## Called by

- `main.swift`; [[MainView]] (`TopBar`, `EmptyEditor`) and [[AssistantPanel]] through `AppDelegate.shared` (`Sources/Pinpoint/MainWindow.swift:82-91`, `:215`, `Sources/Pinpoint/EditorView.swift:71`); [[MainWindowController]] `windowWillClose` (`MainWindow.swift:439`).

## Related

[[Workspace]] · [[CaptureService]] · [[SelectionOverlay]] · [[ScrollCaptureSession]] · [[HotKeyCenter]] · [[LibraryStore]] · [[AppSettings]] · [[EditorModel]] · [[MainWindowController]]

## Sources

- `Sources/Pinpoint/AppDelegate.swift` (lines 1-345)
- `Sources/Pinpoint/main.swift` (lines 1-6)
