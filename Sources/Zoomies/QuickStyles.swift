import AppKit
import ZoomiesCore

/// A one-click style preset, shown as a rendered thumbnail in the Properties panel.
struct QuickStyle: Hashable, Identifiable {
    var color: RGBA
    var fill: RGBA? = nil
    var widthScale: Double = 1
    var shadow: Bool = true
    var fontScale: Double? = nil
    var id: Int { hashValue }

    static func presets(for kind: AnnotationKind) -> [QuickStyle] {
        let main: [RGBA] = [.red, .blue, .green, .orange, .purple, .black, .white, .yellow]
        switch kind {
        case .arrow, .line:
            return main.map { QuickStyle(color: $0) } + [
                QuickStyle(color: .red, widthScale: 2), QuickStyle(color: .black, widthScale: 0.6, shadow: false),
                QuickStyle(color: .blue, widthScale: 2), QuickStyle(color: .yellow, widthScale: 2.2)]
        case .rectangle, .ellipse:
            return [.red, .blue, .green, .orange, .black].map { QuickStyle(color: $0) } + [
                QuickStyle(color: .red, fill: RGBA.red.with(alpha: 0.18)),
                QuickStyle(color: .blue, fill: RGBA.blue.with(alpha: 0.18)),
                QuickStyle(color: .black, fill: RGBA.yellow.with(alpha: 0.45), widthScale: 0.6),
                QuickStyle(color: .black, fill: .white, widthScale: 0.6),
                QuickStyle(color: .red, widthScale: 2.2), QuickStyle(color: .white, widthScale: 1.5),
                QuickStyle(color: .purple, widthScale: 0.6, shadow: false)]
        case .callout:
            return [QuickStyle(color: .black, fill: .yellow, widthScale: 0),
                    QuickStyle(color: .blue, widthScale: 0), QuickStyle(color: .red, widthScale: 0),
                    QuickStyle(color: .black, fill: .white, widthScale: 0.6),
                    QuickStyle(color: .black, widthScale: 0), QuickStyle(color: .green, widthScale: 0),
                    QuickStyle(color: .purple, widthScale: 0), QuickStyle(color: .orange, widthScale: 0)]
        case .text:
            return main.map { QuickStyle(color: $0) } + [QuickStyle(color: .red, fontScale: 1.6), QuickStyle(color: .black, shadow: false, fontScale: 0.75)]
        case .step:
            return [.red, .blue, .green, .orange, .purple, .black].map { QuickStyle(color: $0) } + [QuickStyle(color: .red, fontScale: 1.4), QuickStyle(color: .blue, fontScale: 0.7)]
        case .highlight:
            return [.yellow, .green, RGBA(1, 0.4, 0.75), RGBA(0.3, 0.8, 1), .orange].map { QuickStyle(color: $0) }
        case .note:
            return [.yellow, .orange, .blue, .red, .green, .purple].map { QuickStyle(color: $0) }
        case .blur, .redact:
            return []
        }
    }

    /// Renders a small preview of this style for a kind.
    @MainActor
    func preview(for kind: AnnotationKind, size: CGSize = CGSize(width: 64, height: 44)) -> NSImage {
        NSImage(size: size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            NSColor(white: 0.97, alpha: 1).setFill(); rect.fill()
            let lw = 3 * widthScale
            let fs = 13 * (fontScale ?? 1)
            let inset = rect.insetBy(dx: 10, dy: 9)
            var a = Annotation(kind: kind, start: inset.origin, end: CGPoint(x: inset.maxX, y: inset.maxY), color: color,
                               lineWidth: lw, text: nil, fontSize: fs, fillColor: fill, shadow: shadow)
            switch kind {
            case .arrow: a.start = CGPoint(x: inset.minX, y: inset.maxY); a.end = CGPoint(x: inset.maxX, y: inset.minY)
            case .text: a.text = "Aa"; a.start = CGPoint(x: rect.midX - a.textSize.width / 2, y: rect.midY - a.textSize.height / 2)
            case .step: a.text = "1"; a.fontSize = 12 * (fontScale ?? 1); a.start = CGPoint(x: rect.midX, y: rect.midY)
            case .callout: a.text = "Hi"; a.fontSize = 10; a.end = CGPoint(x: inset.maxX, y: inset.maxY - 8)
            default: break
            }
            Renderer.draw(a, in: ctx, imageSize: rect.size, pixelated: nil)
            return true
        }
    }
}
