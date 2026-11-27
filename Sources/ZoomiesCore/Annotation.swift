import AppKit
import CoreGraphics
import Foundation

public struct RGBA: Codable, Equatable, Hashable, Sendable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }

    public static let red = RGBA(0.93, 0.18, 0.20)
    public static let orange = RGBA(1.0, 0.55, 0.0)
    public static let yellow = RGBA(1.0, 0.86, 0.0)
    public static let green = RGBA(0.16, 0.72, 0.30)
    public static let blue = RGBA(0.10, 0.48, 1.0)
    public static let purple = RGBA(0.58, 0.30, 0.90)
    public static let black = RGBA(0, 0, 0)
    public static let white = RGBA(1, 1, 1)
    public static let presets: [RGBA] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]

    public var cgColor: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    public var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    public func with(alpha: Double) -> RGBA { RGBA(r, g, b, alpha) }

    /// Accepts names ("red") or hex ("#ff0000", "ff0000").
    public static func parse(_ s: String?) -> RGBA? {
        guard var s = s?.trimmingCharacters(in: .whitespaces).lowercased(), !s.isEmpty else { return nil }
        let names: [String: RGBA] = ["red": .red, "orange": .orange, "yellow": .yellow, "green": .green, "blue": .blue,
                                     "purple": .purple, "black": .black, "white": .white]
        if let c = names[s] { return c }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return RGBA(Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }
}

public enum AnnotationKind: String, Codable, CaseIterable, Sendable {
    case arrow, line, rectangle, ellipse, text, callout, highlight, blur, redact, step, note

    /// Kinds whose geometry is a box (start/end are opposite corners).
    public var isBox: Bool { [.rectangle, .ellipse, .callout, .highlight, .blur, .redact].contains(self) }
    public var supportsFill: Bool { [.rectangle, .ellipse, .callout].contains(self) }
}

/// One markup item. Coordinates are image pixels with a top-left origin.
public struct Annotation: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: AnnotationKind
    public var start: CGPoint
    public var end: CGPoint
    public var color: RGBA
    public var lineWidth: Double
    public var text: String?
    public var fontSize: Double
    /// Optional inside colour for rectangles, ellipses and callouts. nil = no fill.
    public var fillColor: RGBA?
    /// Drop shadow; nil means the default (on).
    public var shadow: Bool?
    /// Spoken or typed context attached to this markup (shown as a numbered badge; exported in handoffs).
    public var note: String?

    public init(id: UUID = UUID(), kind: AnnotationKind, start: CGPoint, end: CGPoint, color: RGBA = .red,
                lineWidth: Double = 4, text: String? = nil, fontSize: Double = 28, fillColor: RGBA? = nil, shadow: Bool? = nil,
                note: String? = nil) {
        self.id = id; self.kind = kind; self.start = start; self.end = end; self.color = color
        self.lineWidth = lineWidth; self.text = text; self.fontSize = fontSize; self.fillColor = fillColor; self.shadow = shadow
        self.note = note
    }

    public var hasNote: Bool { kind == .note || !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Where a note badge sits for this item (image pixels).
    public var badgeAnchor: CGPoint {
        switch kind {
        case .arrow, .line: return start
        case .note, .step: return start
        case .text: return CGPoint(x: start.x - 6, y: start.y)
        default: return CGPoint(x: rect.minX, y: rect.minY)
        }
    }

    /// The point or area this markup is "about" (arrow head, box, pin).
    public var target: CGRect {
        switch kind {
        case .arrow: return CGRect(x: end.x - 1, y: end.y - 1, width: 2, height: 2)
        case .note, .step, .text: return CGRect(x: start.x - 1, y: start.y - 1, width: 2, height: 2)
        default: return rect
        }
    }

    public var hasShadow: Bool { shadow ?? true }

    public var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    public var font: NSFont { NSFont.systemFont(ofSize: fontSize, weight: .bold) }

    public var textSize: CGSize {
        let s = (text ?? "").isEmpty ? " " : text!
        let size = (s as NSString).size(withAttributes: [.font: font])
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    public var stepRadius: CGFloat { CGFloat(fontSize) * 0.8 }

    /// Bounding box including stroke, used for hit testing and selection.
    public var bounds: CGRect {
        let pad = CGFloat(lineWidth) / 2 + 2
        switch kind {
        case .text:
            let s = textSize
            return CGRect(origin: start, size: s).insetBy(dx: -4, dy: -4)
        case .step, .note:
            let r = stepRadius
            return CGRect(x: start.x - r, y: start.y - r, width: r * 2, height: r * 2)
        case .arrow:
            let head = arrowHeadLength
            return rect.insetBy(dx: -head, dy: -head)
        case .callout:
            var r = rect.insetBy(dx: -pad, dy: -pad)
            r.size.height += CGFloat(fontSize) * 1.2   // tail
            return r
        default:
            return rect.insetBy(dx: -pad, dy: -pad)
        }
    }

    public var arrowHeadLength: CGFloat { max(12, CGFloat(lineWidth) * 4) }

    public func hitTest(_ p: CGPoint, tolerance: CGFloat) -> Bool {
        switch kind {
        case .arrow, .line:
            return distance(from: p, toSegment: start, end) <= tolerance + CGFloat(lineWidth) / 2
        default:
            return bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(p)
        }
    }

    public func offset(by d: CGSize) -> Annotation {
        var a = self
        a.start = CGPoint(x: start.x + d.width, y: start.y + d.height)
        a.end = CGPoint(x: end.x + d.width, y: end.y + d.height)
        return a
    }

    /// Sensible default sizes so markup looks the same on 1x and Retina captures.
    public static func defaultLineWidth(for size: CGSize) -> Double { max(3, (max(size.width, size.height) / 360).rounded()) }
    public static func defaultFontSize(for size: CGSize) -> Double { max(18, (max(size.width, size.height) / 55).rounded()) }
}

func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}
