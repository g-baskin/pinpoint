---
type: entity
title: "AppDelegate"
entity: AppDelegate
kind: class
entity_type: class
target: Pinpoint
path: "Sources/Pinpoint/AppDelegate.swift"
lines: "1-303"
language: swift
status: developing
partial_scan: false
last_commit_hash: "66349de"
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
---

# AppDelegate (and CaptureMode, main.swift)

## Purpose

The app's entry point and coordinator: menu bar item and main menu, global hotkeys, the **capture** flow for each **capture mode**, background OCR and naming, and the single main and settings windows. `main.swift` creates it and runs the app (`Sources/Pinpoint/main.swift:3-6`). The app target has no tests (project AGENTS.md).

## API (internal)

```swift
enum CaptureMode { case area, window, screen, allScreens }

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

- Launch: accessory activation policy, menus, then hotkeys via [[HotKeyCenter]]: Control-Shift-1 area, -2 window, -3 screen, -4 all screens, -L library (`AppDelegate.swift:20-35`). It does not prompt for Screen Recording at launch; it only asks after a capture fails (`:31`, `:149-150`).
- `capture(_:)`: screen and all-screens capture directly through [[CaptureService]]; area and window freeze every display and show a [[SelectionOverlay]] on each, with keyboard focus on the screen under the mouse (`AppDelegate.swift:118-153`). Window mode grabs the window itself; area mode crops the frozen image (`:155-172`).
- `finishCapture` creates the capture in [[LibraryStore]], posts `pinpointLibraryChanged`, optionally copies the PNG, opens the editor and triggers auto-redact once [[EditorModel]] has its analysis (polls up to 40 times every 0.25 s) (`AppDelegate.swift:174-194`).
- `postProcess` runs off the main actor: OCR without faces, the offline name from `Analyzer.suggestedName`, then optional AI name and tags via [[Assistants]]; it avoids overwriting edits made meanwhile in an open editor (`AppDelegate.swift:197-224`).
- Shows in the Dock only while a window is open (`AppDelegate.swift:288-296`).

## Called by

- `main.swift`; [[MainView]] (`TopBar`, `EmptyEditor`) and [[AssistantPanel]] through `AppDelegate.shared` (`Sources/Pinpoint/MainWindow.swift:79-88`, `:212`, `Sources/Pinpoint/EditorView.swift:71`); [[MainWindowController]] `windowWillClose` (`MainWindow.swift:436`).

## Related

[[Workspace]] · [[CaptureService]] · [[SelectionOverlay]] · [[HotKeyCenter]] · [[LibraryStore]] · [[AppSettings]] · [[EditorModel]] · [[MainWindowController]]

## Sources

- `Sources/Pinpoint/AppDelegate.swift` (lines 1-303)
- `Sources/Pinpoint/main.swift` (lines 1-6)
