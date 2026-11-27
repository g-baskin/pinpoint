import AppKit
import CoreGraphics
import CoreImage
import Foundation

/// Draws annotations. All drawing assumes a *flipped* context (origin top-left) in image-pixel units,
/// so the same code paints the live editor canvas and the exported image.
public enum Renderer {
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Draws a CGImage into `rect` of a flipped context without it appearing upside down.
    public static func drawImage(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    /// A fully pixelated copy of `image`; blur annotations reveal it through a clip. Computed once per capture.
    public static func pixelated(_ image: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: image)
        let block = max(10, Double(max(image.width, image.height)) / 110)
        guard let f = CIFilter(name: "CIPixellate") else { return nil }
        f.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
        f.setValue(block, forKey: kCIInputScaleKey)
        f.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)
        guard let out = f.outputImage?.cropped(to: ci.extent) else { return nil }
        return ciContext.createCGImage(out, from: ci.extent)
    }

    public static func draw(_ annotations: [Annotation], in ctx: CGContext, imageSize: CGSize, pixelated: CGImage?) {
        let numbers = noteNumbers(annotations)
        for a in annotations {
            var item = a
            if a.kind == .note { item.text = numbers[a.id].map(String.init) ?? "•" }
            draw(item, in: ctx, imageSize: imageSize, pixelated: pixelated)
        }
        // Numbered badges for markup that carries a note (pins already show their number).
        for a in annotations where a.kind != .note && a.hasNote {
            if let n = numbers[a.id] {
                // Keep the whole badge inside the image.
                let r = max(10, CGFloat(a.fontSize) * 0.45) + 2
                let p = a.badgeAnchor
                let c = CGPoint(x: min(max(p.x, r), max(r, imageSize.width - r)), y: min(max(p.y, r), max(r, imageSize.height - r)))
                drawBadge(n, at: c, size: a.fontSize, ctx: ctx)
            }
        }
    }

    /// 1, 2, 3… in drawing order for every item with a note.
    public static func noteNumbers(_ annotations: [Annotation]) -> [UUID: Int] {
        var out: [UUID: Int] = [:]
        var n = 0
        for a in annotations where a.hasNote { n += 1; out[a.id] = n }
        return out
    }

    static func drawBadge(_ n: Int, at p: CGPoint, size: Double, ctx: CGContext) {
        let r = max(10, CGFloat(size) * 0.45)
        let c = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 3, color: CGColor(gray: 0, alpha: 0.5))
        ctx.setFillColor(CGColor(srgbRed: 0.12, green: 0.15, blue: 0.22, alpha: 1))
        ctx.fillEllipse(in: c)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 1)); ctx.setLineWidth(max(1.5, r * 0.12))
        ctx.strokeEllipse(in: c.insetBy(dx: r * 0.08, dy: r * 0.08))
        drawText("\(n)", font: NSFont.systemFont(ofSize: r * 1.05, weight: .bold), color: .white, centeredIn: c, ctx: ctx)
        ctx.restoreGState()
    }

    public static func draw(_ a: Annotation, in ctx: CGContext, imageSize: CGSize, pixelated: CGImage?) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let lw = CGFloat(a.lineWidth)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(a.color.cgColor)
        ctx.setFillColor(a.color.cgColor)
        let r = a.rect

        switch a.kind {
        case .line:
            if a.hasShadow { setShadow(ctx, lw) }
            ctx.move(to: a.start); ctx.addLine(to: a.end); ctx.strokePath()

        case .arrow:
            let dx = a.end.x - a.start.x, dy = a.end.y - a.start.y
            let len = hypot(dx, dy)
            guard len > 0.5 else { return }
            let ux = dx / len, uy = dy / len
            let head = min(a.arrowHeadLength, len * 0.6)
            let base = CGPoint(x: a.end.x - ux * head * 0.8, y: a.end.y - uy * head * 0.8)
            if a.hasShadow { setShadow(ctx, lw) }
            ctx.move(to: a.start); ctx.addLine(to: base); ctx.strokePath()
            let px = -uy, py = ux, w = head * 0.55
            let back = CGPoint(x: a.end.x - ux * head, y: a.end.y - uy * head)
            ctx.move(to: a.end)
            ctx.addLine(to: CGPoint(x: back.x + px * w, y: back.y + py * w))
            ctx.addLine(to: CGPoint(x: back.x - px * w, y: back.y - py * w))
            ctx.closePath(); ctx.fillPath()

        case .rectangle:
            if a.hasShadow { setShadow(ctx, lw) }
            let path = CGPath(roundedRect: r, cornerWidth: min(lw * 1.5, r.width / 2), cornerHeight: min(lw * 1.5, r.height / 2), transform: nil)
            if let f = a.fillColor { ctx.setFillColor(f.cgColor); ctx.addPath(path); ctx.fillPath(); ctx.setShadow(offset: .zero, blur: 0, color: nil) }
            if lw > 0 { ctx.addPath(path); ctx.strokePath() }

        case .ellipse:
            if a.hasShadow { setShadow(ctx, lw) }
            if let f = a.fillColor { ctx.setFillColor(f.cgColor); ctx.fillEllipse(in: r); ctx.setShadow(offset: .zero, blur: 0, color: nil) }
            if lw > 0 { ctx.strokeEllipse(in: r) }

        case .callout:
            // Snagit-style callout: rounded bubble with wrapped text and a tail.
            guard r.width >= 2, r.height >= 2 else { return }
            let radius = min(CGFloat(a.fontSize) * 0.6, r.width / 2, r.height / 2)
            let bubble = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
            let tailBase = min(r.width * 0.3, CGFloat(a.fontSize) * 1.4)
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: r.minX + r.width * 0.18, y: r.maxY - 1))
            tail.addLine(to: CGPoint(x: r.minX + r.width * 0.18 - tailBase * 0.35, y: r.maxY + CGFloat(a.fontSize) * 1.1))
            tail.addLine(to: CGPoint(x: r.minX + r.width * 0.18 + tailBase, y: r.maxY - 1))
            tail.closeSubpath()
            let shape = CGMutablePath(); shape.addPath(bubble); shape.addPath(tail)
            let fill = a.fillColor ?? a.color
            if a.hasShadow { setShadow(ctx, max(lw, 3)) }
            ctx.setFillColor(fill.cgColor); ctx.addPath(shape); ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            if a.fillColor != nil && lw > 0 { ctx.addPath(bubble); ctx.strokePath() }
            let textColor: NSColor = luminance(fill) > 0.6 ? .black : .white
            let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineBreakMode = .byWordWrapping
            let attrs: [NSAttributedString.Key: Any] = [.font: a.font, .foregroundColor: textColor, .paragraphStyle: para]
            let inset = r.insetBy(dx: CGFloat(a.fontSize) * 0.5, dy: CGFloat(a.fontSize) * 0.3)
            let str = (a.text ?? "") as NSString
            let h = str.boundingRect(with: inset.size, options: [.usesLineFragmentOrigin], attributes: attrs).height
            let textRect = CGRect(x: inset.minX, y: inset.midY - h / 2, width: inset.width, height: h)
            withNSContext(ctx) { str.draw(with: textRect, options: [.usesLineFragmentOrigin], attributes: attrs) }

        case .highlight:
            ctx.setBlendMode(.multiply)
            ctx.setFillColor(a.color.with(alpha: 0.45).cgColor)
            ctx.fill(r)

        case .redact:
            ctx.fill(r)

        case .blur:
            guard r.width >= 1, r.height >= 1 else { return }
            if let pix = pixelated {
                ctx.clip(to: r)
                drawImage(pix, in: CGRect(origin: .zero, size: imageSize), ctx: ctx)
            } else {
                ctx.setFillColor(CGColor(gray: 0.5, alpha: 1)); ctx.fill(r)
            }

        case .note:
            // A speech-bubble pin with the note number.
            let rad = a.stepRadius
            let box = CGRect(x: a.start.x - rad, y: a.start.y - rad, width: rad * 2, height: rad * 1.7)
            let path = CGMutablePath()
            path.addRoundedRect(in: box, cornerWidth: rad * 0.45, cornerHeight: rad * 0.45)
            path.move(to: CGPoint(x: box.minX + rad * 0.45, y: box.maxY - 1))
            path.addLine(to: CGPoint(x: box.minX + rad * 0.3, y: box.maxY + rad * 0.55))
            path.addLine(to: CGPoint(x: box.minX + rad * 0.95, y: box.maxY - 1))
            path.closeSubpath()
            setShadow(ctx, lw)
            ctx.addPath(path); ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            let contrast: NSColor = luminance(a.color) > 0.7 ? .black : .white
            drawText(a.text ?? "•", font: NSFont.systemFont(ofSize: rad * 0.95, weight: .heavy), color: contrast, centeredIn: box, ctx: ctx)

        case .step:
            let rad = a.stepRadius
            let circle = CGRect(x: a.start.x - rad, y: a.start.y - rad, width: rad * 2, height: rad * 2)
            setShadow(ctx, lw)
            ctx.fillEllipse(in: circle)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 1)); ctx.setLineWidth(max(2, rad * 0.12))
            ctx.strokeEllipse(in: circle.insetBy(dx: rad * 0.06, dy: rad * 0.06))
            let label = a.text ?? "1"
            let font = NSFont.systemFont(ofSize: rad * 1.05, weight: .heavy)
            let contrast: NSColor = luminance(a.color) > 0.7 ? .black : .white
            drawText(label, font: font, color: contrast, centeredIn: circle, ctx: ctx)

        case .text:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: a.font, .foregroundColor: a.color.nsColor,
                .strokeColor: luminance(a.color) > 0.6 ? NSColor.black : NSColor.white,
                .strokeWidth: -3.0,
            ]
            withNSContext(ctx) { ((a.text ?? "") as NSString).draw(at: a.start, withAttributes: attrs) }
        }
    }

    static func setShadow(_ ctx: CGContext, _ lw: CGFloat) {
        ctx.setShadow(offset: .zero, blur: max(2, lw * 0.9), color: CGColor(gray: 0, alpha: 0.45))
    }

    static func luminance(_ c: RGBA) -> Double { 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }

    static func drawText(_ s: String, font: NSFont, color: NSColor, centeredIn rect: CGRect, ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (s as NSString).size(withAttributes: attrs)
        let p = CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        withNSContext(ctx) { (s as NSString).draw(at: p, withAttributes: attrs) }
    }

    static func withNSContext(_ ctx: CGContext, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Bakes annotations (and optional crop) into a new image.
    public static func flatten(base: CGImage, annotations: [Annotation], crop: CGRect?, pixelated: CGImage? = nil) -> CGImage? {
        let size = CGSize(width: base.width, height: base.height)
        let pix = pixelated ?? (annotations.contains { $0.kind == .blur } ? Renderer.pixelated(base) : nil)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        drawImage(base, in: CGRect(origin: .zero, size: size), ctx: ctx)
        draw(annotations, in: ctx, imageSize: size, pixelated: pix)
        guard let full = ctx.makeImage() else { return nil }
        if let c = crop?.integral.intersection(CGRect(origin: .zero, size: size)), c.width >= 1, c.height >= 1 {
            return full.cropping(to: c) ?? full
        }
        return full
    }
}

extension Renderer {
    /// The image plus a "Notes" panel underneath listing each numbered note, so a pasted image explains itself.
    /// Returns the image unchanged when there are no notes.
    public static func withNotesPanel(_ image: CGImage, annotations: [Annotation]) -> CGImage {
        let numbers = noteNumbers(annotations)
        let noted = annotations.filter { numbers[$0.id] != nil }.sorted { numbers[$0.id]! < numbers[$1.id]! }
        guard !noted.isEmpty else { return image }
        let W = CGFloat(image.width)
        let fontSize = min(30, max(13, W / 60))
        let pad = fontSize * 1.1
        let badgeR = fontSize * 0.75
        let textX = pad + badgeR * 2 + fontSize * 0.6
        let textW = max(100, W - textX - pad)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(white: 0.1, alpha: 1), .paragraphStyle: para]
        let titleFont = NSFont.systemFont(ofSize: fontSize * 1.05, weight: .semibold)
        let rows: [(Int, String, CGFloat)] = noted.map { a in
            let t = (a.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let text = t.isEmpty ? "(no note)" : t
            let h = (text as NSString).boundingRect(with: CGSize(width: textW, height: 10_000), options: [.usesLineFragmentOrigin], attributes: attrs).height
            return (numbers[a.id]!, text, max(ceil(h), badgeR * 2))
        }
        let titleH = fontSize * 1.6
        let panelH = pad + titleH + rows.reduce(0) { $0 + $1.2 + fontSize * 0.7 } + pad * 0.5
        let H = CGFloat(image.height) + panelH
        guard let ctx = CGContext(data: nil, width: image.width, height: Int(ceil(H)), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        ctx.translateBy(x: 0, y: ceil(H)); ctx.scaleBy(x: 1, y: -1)
        drawImage(image, in: CGRect(x: 0, y: 0, width: W, height: CGFloat(image.height)), ctx: ctx)
        let panel = CGRect(x: 0, y: CGFloat(image.height), width: W, height: ceil(H) - CGFloat(image.height))
        ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1)); ctx.fill(panel)
        ctx.setFillColor(CGColor(gray: 0.82, alpha: 1)); ctx.fill(CGRect(x: 0, y: panel.minY, width: W, height: max(1, fontSize / 12)))
        var y = panel.minY + pad
        withNSContext(ctx) {
            ("Notes" as NSString).draw(at: CGPoint(x: pad, y: y), withAttributes: [.font: titleFont, .foregroundColor: NSColor(white: 0.15, alpha: 1)])
        }
        y += titleH
        for (n, text, h) in rows {
            drawBadge(n, at: CGPoint(x: pad + badgeR, y: y + badgeR), size: Double(badgeR / 0.45), ctx: ctx)
            withNSContext(ctx) {
                (text as NSString).draw(with: CGRect(x: textX, y: y + max(0, (badgeR * 2 - fontSize * 1.2) / 2), width: textW, height: h + fontSize),
                                        options: [.usesLineFragmentOrigin], attributes: attrs)
            }
            y += h + fontSize * 0.7
        }
        return ctx.makeImage() ?? image
    }
}
