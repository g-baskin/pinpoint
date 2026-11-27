# PRD-001a: Capture *(Retroactive)*

> **Status:** Shipped
> **Parent:** [PRD-001](./prd-001-pinpoint-v0-1-index.md)
> **Retroactive:** Yes. Written from source at commit `66349de`.

## What was built

Pinpoint takes still screenshots with ScreenCaptureKit (`Sources/Pinpoint/CaptureService.swift:23`) in four capture modes (`CaptureMode`, `Sources/Pinpoint/AppDelegate.swift:6`).

### Global shortcuts

Registered with Carbon `RegisterEventHotKey`, which needs no Accessibility permission (`Sources/Pinpoint/HotKeys.swift:4`, registration at `Sources/Pinpoint/AppDelegate.swift:26-30`). The same actions are in the menu bar item (`AppDelegate.swift:48`).

| Shortcut | Action |
|---|---|
| ⌃⇧1 | Area (drag a region, or click a window) |
| ⌃⇧2 | Window |
| ⌃⇧3 | Screen under the mouse |
| ⌃⇧4 | All screens |
| ⌃⇧L | Open the library |

If a shortcut is already taken, registration fails and is only logged (`HotKeys.swift:17`).

### Capture modes

- **Screen**: captures the display under the mouse at full backing scale, without the cursor, excluding Pinpoint's own windows (`CaptureService.swift:88-101`).
- **All screens**: captures each display and stitches them into one image laid out as arranged in System Settings, at the highest backing scale (`CaptureService.swift:103-125`).
- **Area and window**: every display is frozen first, then a selection overlay is shown on all of them; the one under the mouse gets keyboard focus (`AppDelegate.swift:134-146`).
  - In area mode, a click on a window keeps what was on screen. In window mode, Pinpoint captures the window itself through `SCContentFilter(desktopIndependentWindow:)`, so parts hidden behind other windows are included, without the window shadow (`AppDelegate.swift:164-170`, `CaptureService.swift:127-138`). If that fails it falls back to the frozen crop.

### Selection overlay

`SelectionOverlay` (`Sources/Pinpoint/SelectionOverlay.swift:11`):

- Drag = region. Click = window under the pointer. Within 10 points of a screen edge the whole screen is targeted (`SelectionOverlay.swift:84-85`).
- Keys: Esc = cancel, Return / Enter / F = this whole screen, A = all screens, ↑ / ↓ = bigger / smaller panel (`SelectionOverlay.swift:355-361`). Right-click or middle-click also cancels (`SelectionOverlay.swift:328-329`).
- A toolbar at the bottom of each screen offers Full Screen, All Screens and Cancel (`SelectionOverlay.swift:66-74`, `195-205`).
- Only normal app windows count: layer 0, not Pinpoint, visible, larger than 40×40 points (`CaptureService.swift:141-154`).

### Smart panel selection

Hovering a window and scrolling down (or ↓) steps into panels inside it: toolbars, sidebars, dialogs (`SelectionOverlay.swift:135-177`). The panels come from `UIRegionDetector` (`Sources/PinpointCore/UIRegionDetector.swift:4-48`), a recursive XY-cut on a grayscale copy downscaled to at most 1100 px: a row or column where at least 88% of pixels show a luminance step of 14 or more is a cut, down to 5 levels and 24 working pixels (`UIRegionDetector.swift:22-29`). It reads only the frozen image, so it needs no extra permission. Results are cached per window while the overlay is open (`SelectionOverlay.swift:86`, `140`).

### After a capture

`finishCapture` (`AppDelegate.swift:174-188`):

1. Creates a library entry named `<app or "Screen"> <date, time>`, recording the frontmost app (or the clicked window's owner) as `sourceApp`.
2. Copies the PNG to the clipboard if **Copy to clipboard** is on (default on, `Sources/Pinpoint/AppSettings.swift:49`).
3. Opens the editor if **Open in editor** is on (default on, `AppSettings.swift:50`), and runs auto-redact with blur once analysis is ready if **Auto-blur sensitive info** is on (default off, `AppSettings.swift:51`; retry loop `AppDelegate.swift:190-194`).
4. Starts background OCR and naming (see [prd-001e](./prd-001e-pinpoint-v0-1-library-guides.md)).

Images can also be imported with an open panel (`AppDelegate.swift:253-267`).

### Permission handling

`CGPreflightScreenCaptureAccess` checks permission (`CaptureService.swift:26`). Help is shown only after a capture fails with a permission error, and it offers to restart Pinpoint, because macOS applies a new grant only after relaunch (`CaptureService.swift:28-66`, `AppDelegate.swift:147-151`). `Resources/Info.plist` carries `NSScreenCaptureUsageDescription`.

## Acceptance criteria

| ID | Given | When | Then |
|---|---|---|---|
| AC-1 | Pinpoint has Screen Recording permission | the user presses ⌃⇧3 | the display under the mouse is captured without the cursor and without Pinpoint's windows |
| AC-2 | two or more displays | the user presses ⌃⇧4 | one stitched image of all displays is saved |
| AC-3 | ⌃⇧2 and a window partly covered by another | the user clicks the window | the saved image shows the whole window, including the covered part |
| AC-4 | the overlay is open over a window | the user scrolls down | the highlight steps to a smaller panel inside the window, labelled "level i of n" |
| AC-5 | the overlay is open | the user presses Esc or right-clicks | nothing is saved |
| AC-6 | permission was never granted | a capture fails | Pinpoint shows help with a restart option instead of a raw error |

## Tests

`UIRegionTests` (`Tests/PinpointCoreTests/ProviderTests.swift:133`) covers the panel detector. The overlay and capture service are in the app target and have no tests.

## Related

- [Glossary: capture, capture mode](../../../knowledge/private/glossary/glossary.md)
- [ADR-2](../../../knowledge/private/architecture/ADR-2-stored-data-identifiers.md): bundle id and signing keep Screen Recording permission across rebuilds
