import AppKit
import ScreenCaptureKit
import PinpointCore

struct WindowInfo {
    let id: CGWindowID
    let owner: String
    let title: String
    let frame: CGRect   // global CG coordinates (top-left origin of the main display)
}

enum CaptureError: LocalizedError {
    case noPermission, noDisplay, noWindow
    var errorDescription: String? {
        switch self {
        case .noPermission: return "Pinpoint needs Screen Recording permission."
        case .noDisplay: return "Couldn't find that display."
        case .noWindow: return "Couldn't find that window."
        }
    }
}

/// Screen and window capture using ScreenCaptureKit.
@MainActor
enum CaptureService {
    static func hasPermission() -> Bool { CGPreflightScreenCaptureAccess() }

    /// True when an error from ScreenCaptureKit means "not allowed" rather than some other failure.
    static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        return error is CaptureError || ns.code == -3801 /* SCStreamErrorUserDeclined */ || !hasPermission()
    }

    /// Shown only after a capture actually failed for lack of permission.
    /// macOS applies a new grant only after the app restarts, so the main fix offered is "Restart Pinpoint".
    static func showPermissionHelp() {
        // Ask macOS once (shows the system prompt if Pinpoint has never been asked); never reset an existing grant.
        _ = CGRequestScreenCaptureAccess()
        let alert = NSAlert()
        alert.messageText = "Pinpoint needs to restart to see the screen"
        alert.informativeText = """
        If you just allowed Pinpoint (or switched it on in System Settings), click “Restart Pinpoint” — macOS only applies the permission after a restart.

        If you haven't allowed it yet, click “Open System Settings”, switch on Pinpoint under Screen & System Audio Recording, then come back and click Restart.
        """
        alert.addButton(withTitle: "Restart Pinpoint")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: relaunch()
        case .alertSecondButtonReturn: openSettings()
        default: break
        }
    }

    /// Quits and reopens Pinpoint after a short pause (avoids the "app still quitting" race).
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1.5; /usr/bin/open \"$0\"", path]
        try? p.run()
        NSApp.terminate(nil)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func screenUnderMouse() -> NSScreen {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    /// Top-left of `screen` in global CG coordinates.
    static func cgOrigin(_ screen: NSScreen) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGPoint(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY)
    }

    static func captureScreen(_ screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let id = displayID(screen)
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.noDisplay }
        let ours = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ours, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Every display stitched into one image, laid out as arranged in System Settings → Displays.
    static func captureAllScreens() async throws -> CGImage {
        let screens = NSScreen.screens
        if screens.count == 1 { return try await captureScreen(screens[0]) }
        var shots: [(CGRect, CGImage)] = []
        for s in screens {
            shots.append((CGRect(origin: cgOrigin(s), size: s.frame.size), try await captureScreen(s)))
        }
        let union = shots.map(\.0).reduce(CGRect.null) { $0.union($1) }
        let scale = screens.map(\.backingScaleFactor).max() ?? 2
        let w = Int((union.width * scale).rounded()), h = Int((union.height * scale).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CaptureError.noDisplay }
        ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        for (r, img) in shots {
            let dest = CGRect(x: (r.minX - union.minX) * scale, y: (r.minY - union.minY) * scale, width: r.width * scale, height: r.height * scale)
            Renderer.drawImage(img, in: dest, ctx: ctx)
        }
        guard let out = ctx.makeImage() else { throw CaptureError.noDisplay }
        return out
    }

    static func captureWindow(_ windowID: CGWindowID, scale: CGFloat) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let win = content.windows.first(where: { $0.windowID == windowID }) else { throw CaptureError.noWindow }
        let filter = SCContentFilter(desktopIndependentWindow: win)
        let config = SCStreamConfiguration()
        config.width = Int(win.frame.width * scale)
        config.height = Int(win.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Normal app windows on screen, front to back.
    static func visibleWindows() -> [WindowInfo] {
        let me = ProcessInfo.processInfo.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? pid_t) != me,
                  ((w[kCGWindowAlpha as String] as? Double) ?? 1) > 0.01,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: b), rect.width > 40, rect.height > 40,
                  let num = w[kCGWindowNumber as String] as? CGWindowID else { return nil }
            return WindowInfo(id: num, owner: w[kCGWindowOwnerName as String] as? String ?? "",
                              title: w[kCGWindowName as String] as? String ?? "", frame: rect)
        }
    }
}
