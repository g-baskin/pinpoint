import CoreGraphics
import Foundation
import Vision

public struct OCRLine: Codable, Equatable, Sendable {
    public var text: String
    public var rect: CGRect   // image pixels, top-left origin
    public init(text: String, rect: CGRect) { self.text = text; self.rect = rect }
}

public struct Analysis: Sendable {
    public var lines: [OCRLine]
    public var sensitive: [SensitiveRegion]
    public var fullText: String { lines.map(\.text).joined(separator: "\n") }
    public init(lines: [OCRLine], sensitive: [SensitiveRegion]) { self.lines = lines; self.sensitive = sensitive }
}

/// On-device analysis with Apple Vision: text recognition, sensitive-text boxes and faces. No network.
public enum Analyzer {
    public static func analyze(_ image: CGImage, faces: Bool = true, customTerms: [String] = []) throws -> Analysis {
        // Vision reads a very tall image (a scrolling capture) at reduced resolution and misses small text,
        // so read it in overlapping strips; each strip keeps only what's centred in its own share of the overlap.
        let w = image.width, h = image.height
        let strip = max(1200, w * 3 / 2), overlap = 200
        guard h > strip + overlap else { return try analyzeWhole(image, faces: faces, customTerms: customTerms) }
        var lines: [OCRLine] = [], sensitive: [SensitiveRegion] = []
        var top = 0
        while top < h {
            let bottom = min(h, top + strip)
            guard let piece = image.cropping(to: CGRect(x: 0, y: top, width: w, height: bottom - top)) else { break }
            let a = try analyzeWhole(piece, faces: faces, customTerms: customTerms)
            let own = CGFloat(top == 0 ? 0 : top + overlap / 2)..<CGFloat(bottom == h ? h : bottom - overlap / 2)
            func shifted(_ r: CGRect) -> CGRect { r.offsetBy(dx: 0, dy: CGFloat(top)) }
            lines += a.lines.map { OCRLine(text: $0.text, rect: shifted($0.rect)) }.filter { own.contains($0.rect.midY) }
            sensitive += a.sensitive.map { SensitiveRegion(kind: $0.kind, text: $0.text, rect: shifted($0.rect)) }.filter { own.contains($0.rect.midY) }
            if bottom == h { break }
            top = bottom - overlap
        }
        return Analysis(lines: lines, sensitive: sensitive)
    }

    private static func analyzeWhole(_ image: CGImage, faces: Bool, customTerms: [String]) throws -> Analysis {
        let W = CGFloat(image.width), H = CGFloat(image.height)
        func toPixels(_ b: CGRect) -> CGRect {
            CGRect(x: b.minX * W, y: (1 - b.maxY) * H, width: b.width * W, height: b.height * H)
        }

        let textReq = VNRecognizeTextRequest()
        textReq.recognitionLevel = .accurate
        textReq.usesLanguageCorrection = false
        let faceReq = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform(faces ? [textReq, faceReq] : [textReq])

        var lines: [OCRLine] = []
        var sensitive: [SensitiveRegion] = []
        let observations = (textReq.results ?? []).sorted {
            // Reading order: top to bottom, then left to right.
            abs($0.boundingBox.maxY - $1.boundingBox.maxY) > 0.01 ? $0.boundingBox.maxY > $1.boundingBox.maxY : $0.boundingBox.minX < $1.boundingBox.minX
        }
        for obs in observations {
            guard let cand = obs.topCandidates(1).first else { continue }
            let text = cand.string
            lines.append(OCRLine(text: text, rect: toPixels(obs.boundingBox)))
            for m in SensitiveDetector.findMatches(in: text, customTerms: customTerms) {
                let box = (try? cand.boundingBox(for: m.range))?.boundingBox ?? obs.boundingBox
                sensitive.append(SensitiveRegion(kind: m.kind, text: m.value, rect: toPixels(box)))
            }
        }
        if faces {
            for f in faceReq.results ?? [] {
                sensitive.append(SensitiveRegion(kind: .face, text: nil, rect: toPixels(f.boundingBox).insetBy(dx: -0.15 * f.boundingBox.width * W, dy: -0.2 * f.boundingBox.height * H)))
            }
        }
        return Analysis(lines: lines, sensitive: sensitive)
    }

    /// Lines whose text contains `query` (case-insensitive). Falls back to fuzzy word overlap.
    public static func find(_ query: String, in lines: [OCRLine]) -> [OCRLine] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let exact = lines.filter { $0.text.lowercased().contains(q) }
        if !exact.isEmpty { return exact }
        let words = Set(q.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        guard !words.isEmpty else { return [] }
        return lines.filter { line in
            let lw = Set(line.text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
            return !lw.isDisjoint(with: words)
        }
    }

    /// Turns detections into blur / black-box annotations, padded a little so nothing peeks out.
    public static func redactions(for regions: [SensitiveRegion], style: AnnotationKind = .blur,
                                  kinds: Set<SensitiveKind>? = nil, imageSize: CGSize) -> [Annotation] {
        let bounds = CGRect(origin: .zero, size: imageSize)
        return regions.filter { kinds?.contains($0.kind) ?? true }.map { r in
            let pad = max(3, r.rect.height * 0.15)
            let box = r.rect.insetBy(dx: -pad, dy: -pad).intersection(bounds)
            return Annotation(kind: style == .redact ? .redact : .blur, start: box.origin,
                              end: CGPoint(x: box.maxX, y: box.maxY), color: .black, lineWidth: 0)
        }
    }

    /// Offline fallback name: the first meaningful line of text.
    public static func suggestedName(from lines: [OCRLine], app: String?) -> String {
        let candidate = lines.map(\.text).first { t in
            let letters = t.filter(\.isLetter).count
            return letters >= 4 && t.count <= 80 && SensitiveDetector.findMatches(in: t).isEmpty
        }
        if let c = candidate { return String(c.prefix(60)) }
        return app.map { "\($0) capture" } ?? "Capture"
    }
}
