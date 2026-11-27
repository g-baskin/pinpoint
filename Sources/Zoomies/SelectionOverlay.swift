import AppKit
import ZoomiesCore

enum SelectionResult {
    case region(CGRect)          // pixels in the frozen screen image
    case window(WindowInfo, CGRect) // the window + its rect in frozen-image pixels
    case allScreens                 // every display stitched together
    case cancelled
}

/// Full-screen overlay over a frozen screenshot. Drag = region; click = window; edge/F/Return = whole screen; A = all screens; Esc or right-click = cancel.
final class SelectionOverlay: NSWindow {
    private var completion: ((SelectionResult) -> Void)?
    let targetScreen: NSScreen

    init(screen: NSScreen, frozen: CGImage, windows: [WindowInfo], preferWindow: Bool, completion: @escaping (SelectionResult) -> Void) {
        self.completion = completion
        self.targetScreen = screen
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = true
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size), screen: screen, frozen: frozen,
                                 windows: windows, preferWindow: preferWindow)
        view.onFinish = { [weak self] r in self?.finish(r) }
        contentView = view
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { true }

    /// One overlay per display; the one under the mouse gets keyboard focus (Esc / Return).
    func present(makeKey: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        if makeKey { makeKeyAndOrderFront(nil); makeFirstResponder(contentView) } else { orderFrontRegardless() }
    }

    /// Closes without reporting (used when a selection finished on another screen).
    func dismiss() {
        completion = nil
        orderOut(nil)
    }

    private func finish(_ r: SelectionResult) {
        orderOut(nil)
        let c = completion
        completion = nil
        c?(r)
    }
}

private final class SelectionView: NSView {
    let screen: NSScreen
    let frozen: CGImage
    let image: NSImage
    let windows: [WindowInfo]
    let preferWindow: Bool
    let pxScale: CGFloat
    var onFinish: ((SelectionResult) -> Void)?

    /// .part = a panel/toolbar/dialog inside a window found by smart selection (level i of n; 0 would be the whole window).
    private enum Hover { case window(WindowInfo, CGRect), part(WindowInfo, CGRect, Int, Int), screen }
    private enum ToolButton: CaseIterable {
        case fullScreen, allScreens, cancel
        var title: String {
            switch self {
            case .fullScreen: return "Full Screen  (F)"
            case .allScreens: return "All Screens  (A)"
            case .cancel: return "Cancel  (Esc / right-click)"
            }
        }
    }

    private var dragStart: CGPoint?
    private var dragRect: CGRect?
    private var hover: Hover?
    private var hoverButton: ToolButton?
    private var pressedButton = false
    private var mouse: CGPoint = CGPoint(x: -100, y: -100)
    /// Within this many points of a screen edge, the whole screen is targeted (like Snagit).
    private let edgeMargin: CGFloat = 10
    private var regionCache: [CGWindowID: UIRegionDetector.Node] = [:]
    private var levelOffset = 0          // 0 = smallest part under the mouse; scrolling up steps out
    private var lastLeaf: CGRect?
    private var scrollAccum: CGFloat = 0

    init(frame: CGRect, screen: NSScreen, frozen: CGImage, windows: [WindowInfo], preferWindow: Bool) {
        self.screen = screen; self.frozen = frozen; self.windows = windows; self.preferWindow = preferWindow
        self.image = NSImage(cgImage: frozen, size: frame.size)
        self.pxScale = CGFloat(frozen.width) / frame.width
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
        for (_, r) in toolbarRects() { addCursorRect(r, cursor: .pointingHand) }
    }

    override func mouseEntered(with event: NSEvent) { window?.makeKey(); window?.makeFirstResponder(self) }

    private var fullPixels: CGRect { CGRect(x: 0, y: 0, width: frozen.width, height: frozen.height) }

    // MARK: Geometry

    /// Window rects converted to this view's (flipped, point) coordinates.
    private func windowRect(_ w: WindowInfo) -> CGRect {
        let o = CaptureService.cgOrigin(screen)
        return CGRect(x: w.frame.minX - o.x, y: w.frame.minY - o.y, width: w.frame.width, height: w.frame.height)
    }

    private func windowAt(_ p: CGPoint) -> (WindowInfo, CGRect)? {
        for w in windows {
            let r = windowRect(w)
            if r.contains(p) {
                let visible = r.intersection(bounds)
                return Self.isUsable(visible) ? (w, visible) : nil
            }
        }
        return nil
    }

    private func nearEdge(_ p: CGPoint) -> Bool {
        p.x <= bounds.minX + edgeMargin || p.x >= bounds.maxX - edgeMargin || p.y <= bounds.minY + edgeMargin || p.y >= bounds.maxY - edgeMargin
    }

    /// Smart selection: nested UI regions under `p`, from the whole window (index 0) down to the smallest part.
    private func regionPath(_ w: WindowInfo, visible: CGRect, at p: CGPoint) -> [CGRect] {
        guard !preferWindow else { return [visible] }
        let node: UIRegionDetector.Node
        if let n = regionCache[w.id] { node = n }
        else { node = UIRegionDetector.detect(image: frozen, in: toPixels(visible)); regionCache[w.id] = node }
        let path = node.path(to: CGPoint(x: p.x * pxScale, y: p.y * pxScale)).map {
            CGRect(x: $0.minX / pxScale, y: $0.minY / pxScale, width: $0.width / pxScale, height: $0.height / pxScale).intersection(visible)
        }.filter { Self.isUsable($0) && $0.width >= 12 && $0.height >= 12 }
        guard let first = path.first else { return [visible] }
        return [visible] + (first.equalTo(visible) ? Array(path.dropFirst()) : path)
    }

    private func hoverAt(_ p: CGPoint) -> Hover? {
        if button(at: p) != nil { return nil }
        if nearEdge(p) { return .screen }
        if let w = windowAt(p) {
            let path = regionPath(w.0, visible: w.1, at: p)
            if path.last != lastLeaf { lastLeaf = path.last; levelOffset = 0 }
            levelOffset = max(0, min(levelOffset, path.count - 1))
            let idx = path.count - 1 - levelOffset
            return idx == 0 ? .window(w.0, w.1) : .part(w.0, path[idx], idx, path.count - 1)
        }
        return .screen   // bare desktop
    }

    private func rect(of h: Hover) -> CGRect {
        switch h { case .window(_, let r), .part(_, let r, _, _): return r; case .screen: return bounds }
    }

    /// Scroll up / ↑ = bigger (towards the whole window); scroll down / ↓ = smaller.
    private func stepLevel(_ delta: Int) {
        levelOffset = max(0, levelOffset + delta)
        hover = hoverAt(mouse)
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        scrollAccum += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 12)
        let step: CGFloat = 24
        while scrollAccum >= step { scrollAccum -= step; stepLevel(1) }
        while scrollAccum <= -step { scrollAccum += step; stepLevel(-1) }
    }

    /// CGRect.null / infinite / NaN rects crash NSBezierPath, so every rect we draw goes through this.
    static func isUsable(_ r: CGRect) -> Bool {
        !r.isNull && !r.isInfinite && !r.isEmpty && r.minX.isFinite && r.minY.isFinite && r.width.isFinite && r.height.isFinite
    }

    private func clampToBounds(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX), y: min(max(p.y, bounds.minY), bounds.maxY))
    }

    private func toPixels(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * pxScale, y: r.minY * pxScale, width: r.width * pxScale, height: r.height * pxScale).integral
    }

    private static let labelFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private static let buttonFont: NSFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    /// Bottom-centre toolbar on every screen.
    private func toolbarRects() -> [(ToolButton, CGRect)] {
        let h: CGFloat = 34, gap: CGFloat = 8
        let widths = ToolButton.allCases.map { ($0.title as NSString).size(withAttributes: [.font: Self.buttonFont]).width + 28 }
        let total = widths.reduce(0, +) + gap * CGFloat(widths.count - 1)
        var x = bounds.midX - total / 2
        let y = bounds.maxY - h - 46
        var out: [(ToolButton, CGRect)] = []
        for (b, w) in zip(ToolButton.allCases, widths) { out.append((b, CGRect(x: x, y: y, width: w, height: h))); x += w + gap }
        return out
    }

    private func button(at p: CGPoint) -> ToolButton? {
        toolbarRects().first { $0.1.insetBy(dx: -2, dy: -2).contains(p) }?.0
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let candidate = dragRect ?? hover.map(rect(of:))
        let sel = candidate.flatMap { Self.isUsable($0) ? $0 : nil }
        let dim = NSBezierPath(rect: bounds)
        if let s = sel { dim.append(NSBezierPath(rect: s)); dim.windingRule = .evenOdd }
        NSColor.black.withAlphaComponent(0.38).setFill()
        dim.fill()

        let px = toPixels(bounds)
        let screenInfo = "\(screen.localizedName) · \(Int(px.width)) × \(Int(px.height))"
        if let s = sel {
            let border = NSBezierPath(rect: s.insetBy(dx: s == bounds ? 2 : -1, dy: s == bounds ? 2 : -1))
            border.lineWidth = s == bounds ? 4 : 2
            NSColor.systemBlue.setStroke()
            border.stroke()
            let spx = toPixels(s)
            var label = "\(Int(spx.width)) × \(Int(spx.height))"
            if dragRect == nil, let h = hover {
                switch h {
                case .window(let w, _): label = "\(w.owner)\(w.title.isEmpty ? "" : " — " + w.title)   " + label + (preferWindow ? "" : "   Scroll down for panels")
                case .part(let w, _, let i, let n): label = "Part of \(w.owner) · \(label) · level \(i) of \(n)   Scroll up = bigger, down = smaller"
                case .screen: label = "Whole screen · \(screenInfo)   Click to capture"
                }
            }
            let at = s == bounds ? CGPoint(x: bounds.midX - 160, y: bounds.midY - 14)
                                 : CGPoint(x: s.minX, y: s.minY > 30 ? s.minY - 28 : s.maxY + 6)
            drawLabel(label, at: at)
        }
        if dragStart == nil {
            drawLabel("Drag an area · Click a panel or window (scroll for bigger/smaller) · Edge = whole screen · Right-click to cancel     \(screenInfo)",
                      at: CGPoint(x: bounds.midX - 420, y: 14))
            drawToolbar()
        }
        if dragStart == nil && bounds.contains(mouse) && hoverButton == nil && window?.isKeyWindow == true {
            NSColor.white.withAlphaComponent(0.55).setStroke()
            let cross = NSBezierPath()
            cross.move(to: CGPoint(x: mouse.x, y: 0)); cross.line(to: CGPoint(x: mouse.x, y: bounds.maxY))
            cross.move(to: CGPoint(x: 0, y: mouse.y)); cross.line(to: CGPoint(x: bounds.maxX, y: mouse.y))
            cross.lineWidth = 0.5
            cross.stroke()
        }
    }

    private func drawToolbar() {
        for (b, r) in toolbarRects() {
            let hot = hoverButton == b
            (hot ? NSColor.systemBlue : NSColor.black.withAlphaComponent(0.78)).setFill()
            NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9).fill()
            NSColor.white.withAlphaComponent(0.25).setStroke()
            NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9).stroke()
            let attrs: [NSAttributedString.Key: Any] = [.font: Self.buttonFont, .foregroundColor: NSColor.white]
            let size = (b.title as NSString).size(withAttributes: attrs)
            (b.title as NSString).draw(at: CGPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2), withAttributes: attrs)
        }
    }

    /// Window titles can contain emoji or symbols that some fonts can't fall back from (that crashed CoreText);
    /// keep the label to plain text and use the system font, which has a full fallback list.
    static func safeLabel(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            let p = u.properties
            if p.isEmojiPresentation || (p.isEmoji && u.value > 0xFF) || p.generalCategory == .control
                || p.generalCategory == .privateUse || p.generalCategory == .surrogate
                || u.value == 0xFE0F || u.value == 0x200D { continue }
            out.append(u)
        }
        let cleaned = String(out).trimmingCharacters(in: .whitespaces)
        return cleaned.count > 140 ? String(cleaned.prefix(140)) + "…" : cleaned
    }

    private func drawLabel(_ raw: String, at p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite else { return }
        let s = Self.safeLabel(raw)
        guard !s.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.labelFont, .foregroundColor: NSColor.white]
        let size = (s as NSString).size(withAttributes: attrs)
        guard size.width.isFinite, size.height.isFinite else { return }
        let w = size.width + 14, h = size.height + 8
        let bg = CGRect(x: min(max(4, p.x), max(4, bounds.width - w - 4)), y: min(max(4, p.y), max(4, bounds.height - h - 4)), width: w, height: h)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 6, yRadius: 6).fill()
        (s as NSString).draw(at: CGPoint(x: bg.minX + 7, y: bg.minY + 4), withAttributes: attrs)
    }

    // MARK: Input

    private func perform(_ b: ToolButton) {
        switch b {
        case .fullScreen: onFinish?(.region(fullPixels))
        case .allScreens: onFinish?(.allScreens)
        case .cancel: onFinish?(.cancelled)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        mouse = clampToBounds(convert(event.locationInWindow, from: nil))
        hoverButton = button(at: mouse)
        hover = hoverAt(mouse)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hover = nil; hoverButton = nil; mouse = CGPoint(x: -100, y: -100); needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = clampToBounds(convert(event.locationInWindow, from: nil))
        if let b = button(at: p) { pressedButton = true; perform(b); return }
        pressedButton = false
        dragStart = p
        dragRect = nil
    }

    override func rightMouseDown(with event: NSEvent) { onFinish?(.cancelled) }
    override func otherMouseDown(with event: NSEvent) { onFinish?(.cancelled) }

    override func mouseDragged(with event: NSEvent) {
        guard let s = dragStart else { return }
        let p = clampToBounds(convert(event.locationInWindow, from: nil))
        mouse = p
        let r = CGRect(x: min(s.x, p.x), y: min(s.y, p.y), width: abs(p.x - s.x), height: abs(p.y - s.y))
        dragRect = (r.width > 3 || r.height > 3) && Self.isUsable(r) ? r : nil
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil }
        if pressedButton { pressedButton = false; return }
        guard dragStart != nil else { return }
        if let r = dragRect, Self.isUsable(r), r.width >= 4, r.height >= 4 {
            onFinish?(.region(toPixels(r)))
            return
        }
        switch hoverAt(clampToBounds(convert(event.locationInWindow, from: nil))) {
        case .window(let w, let r)?: onFinish?(.window(w, toPixels(r)))
        case .part(_, let r, _, _)?: onFinish?(.region(toPixels(r)))
        default: onFinish?(.region(fullPixels))
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onFinish?(.cancelled)                       // Esc
        case 36, 76, 3: onFinish?(.region(fullPixels))       // Return, Enter, F = this whole screen
        case 0: onFinish?(.allScreens)                       // A = all screens
        case 126: stepLevel(1)                               // ↑ bigger
        case 125: stepLevel(-1)                              // ↓ smaller
        default: super.keyDown(with: event)
        }
    }
}
