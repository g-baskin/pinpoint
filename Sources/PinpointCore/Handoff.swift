import CoreGraphics
import Foundation

/// Turns a capture + its noted markup into text a coding agent or a teammate can act on.
public enum Handoff {
    /// Plain-English description of what a markup item points at, using on-screen text when possible.
    public static func describe(_ a: Annotation, ocr: [OCRLine]) -> String {
        let kind: String
        switch a.kind {
        case .arrow: kind = "Arrow pointing at"
        case .note: kind = "Pin at"
        case .rectangle, .ellipse: kind = "Outlined area around"
        case .highlight: kind = "Highlighted"
        case .blur, .redact: kind = "Hidden area"
        case .callout: kind = "Callout"
        case .text: kind = "Text label"
        case .step: kind = "Step \(a.text ?? "")"
        case .line: kind = "Line at"
        }
        let t = a.target
        let pos = "x \(Int(t.midX)), y \(Int(t.midY))" + (t.width > 4 ? ", \(Int(t.width))×\(Int(t.height)) px" : "")
        let nearby = nearbyText(t, ocr: ocr)
        var s = kind
        if !nearby.isEmpty { s += " “" + nearby.joined(separator: "”, “") + "”" }
        s += " (\(pos))"
        if a.kind == .callout || a.kind == .text, let label = a.text, !label.isEmpty { s += " — label: “\(label)”" }
        return s
    }

    /// OCR text inside a box, or the line closest to a point (within ~120 px).
    public static func nearbyText(_ target: CGRect, ocr: [OCRLine]) -> [String] {
        if target.width > 8 && target.height > 8 {
            let inside = ocr.filter { target.intersects($0.rect) }.map(\.text)
            if !inside.isEmpty { return Array(inside.prefix(3)).map { String($0.prefix(80)) } }
        }
        let p = CGPoint(x: target.midX, y: target.midY)
        func dist(_ r: CGRect) -> CGFloat {
            let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
            return hypot(dx, dy)
        }
        if let best = ocr.min(by: { dist($0.rect) < dist($1.rect) }), dist(best.rect) < 120 { return [String(best.text.prefix(80))] }
        return []
    }

    public static func markdown(meta: CaptureMeta, annotations: [Annotation], imagePath: String?, ocr: [OCRLine]) -> String {
        let numbers = Renderer.noteNumbers(annotations)
        var md = "## Screenshot: \(meta.name)\n"
        if let imagePath { md += "Image: \(imagePath)\n" }
        md += "Size: \(meta.width)×\(meta.height) px\(meta.sourceApp.map { " · App: \($0)" } ?? "")\n"
        let noted = annotations.filter { numbers[$0.id] != nil }.sorted { numbers[$0.id]! < numbers[$1.id]! }
        if noted.isEmpty {
            md += "\n(No notes added.)\n"
        } else {
            md += "\n### Notes (numbers match the badges on the image)\n"
            for a in noted {
                let note = (a.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                md += "\(numbers[a.id]!). \(describe(a, ocr: ocr))\n   \(note.isEmpty ? "(no note)" : note.replacingOccurrences(of: "\n", with: "\n   "))\n"
            }
        }
        let others = annotations.filter { numbers[$0.id] == nil && $0.kind != .blur && $0.kind != .redact }
        if !others.isEmpty {
            md += "\nOther markup: " + others.map { describe($0, ocr: ocr) }.joined(separator: "; ") + "\n"
        }
        if let s = meta.summary, !s.isEmpty { md += "\nSummary: \(s)\n" }
        return md
    }
}
