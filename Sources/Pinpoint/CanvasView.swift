import AppKit
import Combine
import SwiftUI
import PinpointCore

/// The drawing surface. Shows the capture fitted to the view and handles all mouse/keyboard editing.
final class CanvasView: NSView {
    let model: EditorModel
    private var bag: AnyCancellable?

    private enum Drag {
        case create(Annotation)
        case move(UUID, CGPoint, Annotation)
        case handle(UUID, isStart: Bool)
        case crop(CGPoint, CGRect?)
    }
    private var drag: Drag?
    private var preview: Annotation?
    private var cropPreview: CGRect?

    init(model: EditorModel) {
        self.model = model
        // The view's coordinate space *is* image pixels; the enclosing scroll view does zooming.
        super.init(frame: CGRect(origin: .zero, size: model.imageSize))
        model.canvas = self
        bag = model.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.needsDisplay = true } }
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Geometry — view coordinates are image pixels; `fitScale` is the current zoom (for handle sizes).

    private var fitScale: CGFloat { max(0.01, enclosingScrollView?.magnification ?? 1) }
    private func toImage(_ p: CGPoint) -> CGPoint { p }
    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), model.imageSize.width), y: min(max(p.y, 0), model.imageSize.height))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = fitScale
        ctx.saveGState()
        let full = CGRect(origin: .zero, size: model.imageSize)
        ctx.interpolationQuality = s < 1 ? .high : .none
        Renderer.drawImage(model.base, in: full, ctx: ctx)

        var items = model.annotations
        if case .move(let id, _, _) = drag, let p = preview, let i = items.firstIndex(where: { $0.id == id }) { items[i] = p }
        else if case .handle(let id, _) = drag, let p = preview, let i = items.firstIndex(where: { $0.id == id }) { items[i] = p }
        else if let p = preview { items.append(p) }
        Renderer.draw(items, in: ctx, imageSize: model.imageSize, pixelated: model.pixelated)

        // Crop: dim everything outside it.
        if let c = cropPreview ?? model.crop {
            let path = CGMutablePath(); path.addRect(full); path.addRect(c)
            ctx.addPath(path); ctx.setFillColor(CGColor(gray: 0, alpha: 0.55)); ctx.fillPath(using: .evenOdd)
            ctx.setStrokeColor(.white); ctx.setLineWidth(1.5 / s); ctx.setLineDash(phase: 0, lengths: [6 / s, 4 / s])
            ctx.stroke(c); ctx.setLineDash(phase: 0, lengths: [])
        }

        // Selection.
        if let id = model.selectedID, let a = items.first(where: { $0.id == id }) {
            ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
            ctx.setLineWidth(1.5 / s)
            ctx.setLineDash(phase: 0, lengths: [5 / s, 3 / s])
            ctx.stroke(a.bounds.insetBy(dx: -3 / s, dy: -3 / s))
            ctx.setLineDash(phase: 0, lengths: [])
            if hasHandles(a) {
                for p in [a.start, a.end] {
                    let r = 5 / s
                    let h = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    ctx.setFillColor(.white); ctx.fillEllipse(in: h)
                    ctx.setStrokeColor(NSColor.controlAccentColor.cgColor); ctx.strokeEllipse(in: h)
                }
            }
        }
        ctx.restoreGState()
    }

    private func hasHandles(_ a: Annotation) -> Bool { a.kind != .text && a.kind != .step }

    // MARK: Mouse

    private func hit(_ p: CGPoint) -> Annotation? {
        model.annotations.reversed().first { $0.hitTest(p, tolerance: 6 / fitScale) }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = toImage(convert(event.locationInWindow, from: nil))
        let cp = clamp(p)

        // Handles of the selected item win.
        if let id = model.selectedID, let a = model.annotations.first(where: { $0.id == id }), hasHandles(a) {
            let r = 8 / fitScale
            if hypot(p.x - a.start.x, p.y - a.start.y) <= r { drag = .handle(id, isStart: true); preview = a; return }
            if hypot(p.x - a.end.x, p.y - a.end.y) <= r { drag = .handle(id, isStart: false); preview = a; return }
        }

        switch model.tool {
        case .crop:
            drag = .crop(cp, model.crop)
        case .select:
            if let a = hit(p) {
                model.selectedID = a.id
                if event.clickCount == 2, a.kind == .text || a.kind == .step || a.kind == .callout { editText(a); return }
                if event.clickCount == 2 { showNotePrompt(for: a.id, autoListen: false); return }
                drag = .move(a.id, p, a); preview = a
            } else { model.selectedID = nil }
        case .text:
            if let a = hit(p), a.kind == .text { model.selectedID = a.id; editText(a); return }
            var a = model.newAnnotation(kind: .text, at: cp)
            if let t = promptText(title: "Add text", initial: ""), !t.isEmpty { a.text = t; model.add(a) }
        case .step:
            model.add(model.newAnnotation(kind: .step, at: cp))
        case .note:
            if let a = hit(p), a.kind == .note { model.selectedID = a.id; showNotePrompt(for: a.id, autoListen: false); return }
            let pin = model.newAnnotation(kind: .note, at: cp)
            model.add(pin)
            needsDisplay = true
            showNotePrompt(for: pin.id, autoListen: AppSettings.shared.listenOnPrompt)
        default:
            // Clicking an existing item with a drawing tool selects it instead of drawing on top.
            if let a = hit(p), event.clickCount == 1, model.selectedID == a.id {
                drag = .move(a.id, p, a); preview = a; return
            }
            if let kind = model.tool.kind {
                model.selectedID = nil
                let a = model.newAnnotation(kind: kind, at: cp)
                drag = .create(a); preview = a
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = toImage(convert(event.locationInWindow, from: nil))
        let cp = clamp(p)
        switch drag {
        case .create(var a)?:
            a.end = cp
            if event.modifierFlags.contains(.shift) { a.end = constrained(a.start, cp, box: a.kind.isBox) }
            drag = .create(a); preview = a
        case .move(let id, let from, let orig)?:
            preview = orig.offset(by: CGSize(width: p.x - from.x, height: p.y - from.y))
            _ = id
        case .handle(_, let isStart)?:
            guard var a = preview else { return }
            if isStart { a.start = cp } else { a.end = cp }
            preview = a
        case .crop(let start, _)?:
            cropPreview = CGRect(x: min(start.x, cp.x), y: min(start.y, cp.y), width: abs(cp.x - start.x), height: abs(cp.y - start.y))
        case nil: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { drag = nil; preview = nil; cropPreview = nil; needsDisplay = true }
        switch drag {
        case .create(let a)?:
            let minSize = 4 / fitScale
            if a.kind == .arrow || a.kind == .line {
                if hypot(a.end.x - a.start.x, a.end.y - a.start.y) >= minSize { model.add(a); askForContext(a) }
            }
            else if a.kind == .callout {
                var c = a
                if c.rect.width < 40 || c.rect.height < 20 {   // a click: make a sensible default bubble
                    let w = CGFloat(a.fontSize) * 9, h = CGFloat(a.fontSize) * 2.6
                    c.end = clamp(CGPoint(x: a.start.x + w, y: a.start.y + h))
                }
                if let t = promptText(title: "Callout text", initial: ""), !t.isEmpty { c.text = t; model.add(c) }
            }
            else if a.rect.width >= minSize && a.rect.height >= minSize { model.add(a); askForContext(a) }
        case .move(let id, _, let orig)?:
            commitEdit(id: id, original: orig)
        case .handle(let id, _)?:
            if let orig = model.annotations.first(where: { $0.id == id }) { commitEdit(id: id, original: orig) }
        case .crop?:
            if let c = cropPreview, c.width >= 8, c.height >= 8 { model.checkpoint(); model.crop = c.integral }
        case nil: break
        }
    }

    // MARK: Voice / typed notes

    private var notePopover: NSPopover?

    /// After drawing an arrow or shape, offer to add context (if enabled in Settings).
    private func askForContext(_ a: Annotation) {
        guard AppSettings.shared.askForContext, [.arrow, .line, .rectangle, .ellipse, .highlight].contains(a.kind) else { return }
        DispatchQueue.main.async { self.showNotePrompt(for: a.id, autoListen: AppSettings.shared.listenOnPrompt) }
    }

    func showNotePrompt(for id: UUID, autoListen: Bool) {
        guard let a = model.annotations.first(where: { $0.id == id }) else { return }
        notePopover?.close()
        let pop = NSPopover()
        pop.behavior = .semitransient
        pop.animates = true
        let view = NotePromptView(model: model, annotationID: id, autoListen: autoListen) { [weak pop] in pop?.close() }
        pop.contentViewController = NSHostingController(rootView: view)
        notePopover = pop
        let anchor: CGRect
        switch a.kind {
        case .arrow: anchor = CGRect(x: a.end.x - 4, y: a.end.y - 4, width: 8, height: 8)
        case .line: anchor = CGRect(x: a.end.x - 4, y: a.end.y - 4, width: 8, height: 8)
        default: anchor = a.bounds
        }
        let visible = anchor.intersection(visibleRect)
        pop.show(relativeTo: visible.isNull || visible.isEmpty ? CGRect(x: visibleRect.midX, y: visibleRect.midY, width: 1, height: 1) : visible,
                 of: self, preferredEdge: .maxX)
    }

    private func commitEdit(id: UUID, original: Annotation) {
        guard let p = preview, p != original, let i = model.annotations.firstIndex(where: { $0.id == id }) else { return }
        model.checkpoint()
        model.annotations[i] = p
    }

    private func constrained(_ a: CGPoint, _ b: CGPoint, box: Bool) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        if box { let m = max(abs(dx), abs(dy)); return CGPoint(x: a.x + (dx < 0 ? -m : m), y: a.y + (dy < 0 ? -m : m)) }
        // Snap lines to 45°.
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4), len = hypot(dx, dy)
        return CGPoint(x: a.x + cos(angle) * len, y: a.y + sin(angle) * len)
    }

    private func editText(_ a: Annotation) {
        guard let t = promptText(title: a.kind == .step ? "Step label" : a.kind == .callout ? "Callout text" : "Edit text", initial: a.text ?? ""),
              let i = model.annotations.firstIndex(where: { $0.id == a.id }) else { return }
        model.checkpoint()
        if t.isEmpty && (a.kind == .text || a.kind == .callout) { model.annotations.remove(at: i); model.selectedID = nil } else { model.annotations[i].text = t }
    }

    private func promptText(title: String, initial: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = initial
        alert.accessoryView = field
        alert.addButton(withTitle: "OK"); alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    // MARK: Keyboard (standard responder actions so the menu bar shortcuts work too)

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 51 || event.keyCode == 117 { model.deleteSelected(); return }   // delete / fwd-delete
        if event.keyCode == 53 { model.selectedID = nil; if model.tool == .crop { model.tool = .select }; return } // Esc
        if mods.isEmpty, let ch = event.charactersIgnoringModifiers?.lowercased().first,
           let tool = Tool.allCases.first(where: { $0.key == ch }) { model.tool = tool; return }
        if let id = model.selectedID, let i = model.annotations.firstIndex(where: { $0.id == id }) {
            let step: CGFloat = mods.contains(.shift) ? 10 : 1
            let d: CGSize? = switch event.keyCode {
            case 123: CGSize(width: -step, height: 0); case 124: CGSize(width: step, height: 0)
            case 125: CGSize(width: 0, height: step); case 126: CGSize(width: 0, height: -step)
            default: nil
            }
            if let d { model.checkpoint(); model.annotations[i] = model.annotations[i].offset(by: d); return }
        }
        super.keyDown(with: event)
    }

    @objc func undo(_ sender: Any?) { model.undo() }
    @objc func redo(_ sender: Any?) { model.redo() }
    @objc func copy(_ sender: Any?) { model.copyImage() }
    @objc func delete(_ sender: Any?) { model.deleteSelected() }
    @objc override func selectAll(_ sender: Any?) { model.tool = .select; model.selectedID = model.annotations.last?.id }
}


/// Keeps the image centred when it's smaller than the visible area.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var r = super.constrainBoundsRect(proposedBounds)
        guard let doc = documentView else { return r }
        if r.width > doc.frame.width { r.origin.x = (doc.frame.width - r.width) / 2 }
        if r.height > doc.frame.height { r.origin.y = (doc.frame.height - r.height) / 2 }
        return r
    }
}

/// Zoom commands from the UI, applied to the canvas scroll view.
@MainActor
final class ZoomController: ObservableObject {
    weak var scrollView: NSScrollView?
    @Published var percent: Int = 100
    @Published var fitMode = true

    func fit() {
        guard let sv = scrollView, let doc = sv.documentView else { return }
        let avail = sv.contentView.bounds.size.applying(CGAffineTransform(scaleX: sv.magnification, y: sv.magnification))
        let size = doc.frame.size
        guard size.width > 0, size.height > 0, avail.width > 0 else { return }
        let m = min((avail.width - 40) / size.width, (avail.height - 40) / size.height, 1)
        sv.magnification = max(sv.minMagnification, m)
        fitMode = true
        update()
    }
    /// 100% = one image pixel per screen pixel.
    func actualSize() {
        guard let sv = scrollView else { return }
        sv.magnification = 1 / (sv.window?.backingScaleFactor ?? 2)
        fitMode = false; update()
    }
    func zoom(by f: CGFloat) {
        guard let sv = scrollView else { return }
        sv.magnification = min(sv.maxMagnification, max(sv.minMagnification, sv.magnification * f))
        fitMode = false; update()
    }
    func update() {
        guard let sv = scrollView else { return }
        percent = Int((sv.magnification * (sv.window?.backingScaleFactor ?? 2) * 100).rounded())
    }
}

struct CanvasScrollView: NSViewRepresentable {
    let model: EditorModel
    let zoom: ZoomController

    func makeNSView(context: Context) -> NSScrollView {
        let sv = NSScrollView()
        sv.contentView = CenteringClipView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
        sv.allowsMagnification = true
        sv.minMagnification = 0.03
        sv.maxMagnification = 8
        sv.backgroundColor = NSColor(white: 0.16, alpha: 1)
        sv.drawsBackground = true
        let canvas = CanvasView(model: model)
        canvas.wantsLayer = true
        canvas.layer?.shadowOpacity = 0.5
        canvas.layer?.shadowRadius = 12
        canvas.layer?.shadowOffset = .zero
        sv.documentView = canvas
        zoom.scrollView = sv
        context.coordinator.observe(sv, zoom: zoom)
        DispatchQueue.main.async { zoom.fit(); sv.window?.makeFirstResponder(canvas) }
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) { sv.documentView?.needsDisplay = true }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var tokens: [Any] = []
        @MainActor func observe(_ sv: NSScrollView, zoom: ZoomController) {
            sv.postsFrameChangedNotifications = true
            tokens.append(NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: sv, queue: .main) { _ in
                Task { @MainActor in if zoom.fitMode { zoom.fit() } }
            })
            tokens.append(NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveMagnifyNotification, object: sv, queue: .main) { _ in
                Task { @MainActor in zoom.fitMode = false; zoom.update() }
            })
        }
        deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
    }
}
