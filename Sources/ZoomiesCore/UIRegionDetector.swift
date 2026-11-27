import CoreGraphics
import Foundation

/// Finds UI structure (toolbars, sidebars, panels, dialogs) inside a window screenshot, with no permissions needed.
/// Recursive XY-cut: a row (or column) where almost every pixel differs sharply from its neighbour is a separator
/// line or a background change between two areas; cutting there splits the window into panels, then repeat inside.
public enum UIRegionDetector {
    public struct Node: Equatable, Sendable {
        public var rect: CGRect          // pixels in the source image
        public var children: [Node]
        public init(rect: CGRect, children: [Node] = []) { self.rect = rect; self.children = children }

        /// Regions containing `p`, from this node down to the smallest.
        public func path(to p: CGPoint) -> [CGRect] {
            guard rect.contains(p) else { return [] }
            for c in children { let sub = c.path(to: p); if !sub.isEmpty { return [rect] + sub } }
            return [rect]
        }
        public var count: Int { 1 + children.reduce(0) { $0 + $1.count } }
    }

    public struct Options: Sendable {
        public var maxWorkingDimension = 1100   // analyse a downscaled copy for speed
        public var edgeThreshold: Int = 14      // 0-255 luminance step that counts as an edge
        public var coverage: Double = 0.88      // fraction of the span that must be edge to count as a cut
        public var minRegion: Int = 24          // working-pixel minimum panel size
        public var maxDepth = 5
        public init() {}
    }

    public static func detect(image: CGImage, in rect: CGRect, options: Options = Options()) -> Node {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard r.width >= 8, r.height >= 8, let crop = image.cropping(to: r) else { return Node(rect: rect) }
        let s = min(1, CGFloat(options.maxWorkingDimension) / max(r.width, r.height))
        let w = max(1, Int(r.width * s)), h = max(1, Int(r.height * s))
        var gray = [UInt8](repeating: 0, count: w * h)
        let ok = gray.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return Node(rect: rect) }
        let g = Grid(w: w, h: h, px: gray)
        let root = split(IRect(x: 0, y: 0, w: w, h: h), g, depth: 0, opt: options, horizontalFirst: true)
        return map(root, scale: s, origin: r.origin)
    }

    struct IRect { var x, y, w, h: Int }
    struct WNode { var r: IRect; var kids: [WNode] }
    struct Grid {
        let w: Int, h: Int, px: [UInt8]
        @inline(__always) func at(_ x: Int, _ y: Int) -> Int { Int(px[y * w + x]) }
    }

    static func map(_ n: WNode, scale s: CGFloat, origin o: CGPoint) -> Node {
        let rect = CGRect(x: o.x + CGFloat(n.r.x) / s, y: o.y + CGFloat(n.r.y) / s, width: CGFloat(n.r.w) / s, height: CGFloat(n.r.h) / s).integral
        return Node(rect: rect, children: n.kids.map { map($0, scale: s, origin: o) })
    }

    /// Indices along the axis where a full-span edge occurs (grouped runs collapse to one cut).
    static func cuts(_ r: IRect, _ g: Grid, horizontal: Bool, opt: Options) -> [Int] {
        let span = horizontal ? r.w : r.h
        let length = horizontal ? r.h : r.w
        guard span >= opt.minRegion, length >= opt.minRegion * 2 else { return [] }
        let need = Int(Double(span) * opt.coverage)
        var marks: [Int] = []
        for i in 1..<length {
            var hits = 0, misses = 0
            let allowedMisses = span - need
            for j in 0..<span {
                let d: Int
                if horizontal { d = abs(g.at(r.x + j, r.y + i) - g.at(r.x + j, r.y + i - 1)) }
                else { d = abs(g.at(r.x + i, r.y + j) - g.at(r.x + i - 1, r.y + j)) }
                if d >= opt.edgeThreshold { hits += 1 } else { misses += 1; if misses > allowedMisses { break } }
            }
            if hits >= need { marks.append(i) }
        }
        // Collapse runs (a 1-3px line produces 2 edges close together).
        var out: [Int] = []
        for m in marks { if let last = out.last, m - last <= 4 { continue }; out.append(m) }
        return out
    }

    static func split(_ r: IRect, _ g: Grid, depth: Int, opt: Options, horizontalFirst: Bool) -> WNode {
        guard depth < opt.maxDepth else { return WNode(r: r, kids: []) }
        for horizontal in horizontalFirst ? [true, false] : [false, true] {
            let cs = cuts(r, g, horizontal: horizontal, opt: opt)
            guard !cs.isEmpty else { continue }
            let length = horizontal ? r.h : r.w
            var bounds = [0] + cs + [length]
            bounds = bounds.reduce(into: [Int]()) { acc, v in if acc.last != v { acc.append(v) } }
            var kids: [WNode] = []
            for k in 0..<(bounds.count - 1) {
                var a = bounds[k], b = bounds[k + 1]
                // Skip the separator line itself.
                if k > 0 { a += 1 }
                if b - a < opt.minRegion { continue }
                b = max(a, b)
                let child = horizontal ? IRect(x: r.x, y: r.y + a, w: r.w, h: b - a) : IRect(x: r.x + a, y: r.y, w: b - a, h: r.h)
                kids.append(split(child, g, depth: depth + 1, opt: opt, horizontalFirst: !horizontal))
            }
            if kids.count >= 2 { return WNode(r: r, kids: kids) }
            if kids.count == 1 { return WNode(r: r, kids: kids[0].kids) }   // only a thin strip was cut: don't add a duplicate level
        }
        // No full-span cuts: look for self-contained boxes (dialogs, cards, popovers, text blocks) on a plain background.
        let boxes = componentBoxes(r, g, opt: opt)
        if !boxes.isEmpty {
            return WNode(r: r, kids: boxes.map { split($0, g, depth: depth + 1, opt: opt, horizontalFirst: true) })
        }
        return WNode(r: r, kids: [])
    }

    /// Connected blobs that differ from the region's dominant background colour.
    static func componentBoxes(_ r: IRect, _ g: Grid, opt: Options) -> [IRect] {
        guard r.w >= opt.minRegion * 2, r.h >= opt.minRegion * 2 else { return [] }
        var hist = [Int](repeating: 0, count: 256)
        let stride = max(1, (r.w * r.h) / 40_000)
        var idx = 0
        for y in r.y..<(r.y + r.h) { for x in r.x..<(r.x + r.w) { if idx % stride == 0 { hist[g.at(x, y)] += 1 }; idx += 1 } }
        let bg = hist.indices.max { hist[$0] < hist[$1] } ?? 255
        // Coarse cells (4px) so nearby glyphs/elements merge; then one cell of dilation to bridge small gaps.
        let cell = 4
        let cw = (r.w + cell - 1) / cell, ch = (r.h + cell - 1) / cell
        var on = [Bool](repeating: false, count: cw * ch)
        for cy in 0..<ch {
            for cx in 0..<cw {
                var hit = false
                let y0 = r.y + cy * cell, x0 = r.x + cx * cell
                yLoop: for y in y0..<min(y0 + cell, r.y + r.h) {
                    for x in x0..<min(x0 + cell, r.x + r.w) where abs(g.at(x, y) - bg) >= opt.edgeThreshold { hit = true; break yLoop }
                }
                on[cy * cw + cx] = hit
            }
        }
        var dil = on
        for cy in 0..<ch { for cx in 0..<cw where on[cy * cw + cx] {
            for dy in -1...1 { for dx in -1...1 {
                let nx = cx + dx, ny = cy + dy
                if nx >= 0, ny >= 0, nx < cw, ny < ch { dil[ny * cw + nx] = true }
            } }
        } }
        var seen = [Bool](repeating: false, count: cw * ch)
        var boxes: [IRect] = []
        let regionArea = r.w * r.h
        for start in 0..<(cw * ch) where dil[start] && !seen[start] {
            var stack = [start]; seen[start] = true
            var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
            while let i = stack.popLast() {
                let cx = i % cw, cy = i / cw
                minX = min(minX, cx); maxX = max(maxX, cx); minY = min(minY, cy); maxY = max(maxY, cy)
                for (nx, ny) in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)] where nx >= 0 && ny >= 0 && nx < cw && ny < ch {
                    let j = ny * cw + nx
                    if dil[j] && !seen[j] { seen[j] = true; stack.append(j) }
                }
            }
            // Undo the dilation margin and convert to pixels.
            let x0 = r.x + min(r.w - 1, (minX + 1) * cell - (minX == 0 ? cell : 0))
            let y0 = r.y + min(r.h - 1, (minY + 1) * cell - (minY == 0 ? cell : 0))
            let x1 = r.x + min(r.w, maxX * cell + (maxX == cw - 1 ? cell : 0))
            let y1 = r.y + min(r.h, maxY * cell + (maxY == ch - 1 ? cell : 0))
            let b = IRect(x: x0, y: y0, w: max(0, x1 - x0), h: max(0, y1 - y0))
            if b.w >= opt.minRegion && b.h >= opt.minRegion && b.w * b.h < regionArea * 85 / 100 { boxes.append(b) }
        }
        return Array(boxes.sorted { $0.w * $0.h > $1.w * $1.h }.prefix(40))
    }
}
