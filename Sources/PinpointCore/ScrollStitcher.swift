import CoreGraphics
import Foundation

/// Joins frames of one screen region, captured while its content scrolls, into one tall image.
/// Rows that stay put between frames (sticky headers and footers) appear once. Use one instance from one task at a time.
public final class ScrollStitcher: @unchecked Sendable {
    public enum Step: Equatable {
        case started        // first frame
        case unchanged      // the content didn't move
        case added(Int)     // it moved; this many new rows joined the result (0 when scrolling back, or above the first frame)
        case lostTrack      // no overlap with the last good frame, usually from scrolling too far between frames
        case full           // size limit reached; later frames are ignored
    }

    public struct Options {
        /// Columns at the right edge ignored when matching, because overlay scrollbars appear there while scrolling.
        public var scrollbarMargin: Int
        /// Largest result, in pixels (width × height).
        public var maxPixels: Int
        public init(scrollbarMargin: Int = 0, maxPixels: Int = 50_000_000) {
            self.scrollbarMargin = scrollbarMargin
            self.maxPixels = maxPixels
        }
    }

    private struct Frame { let rgba: [UInt8]; let luma: [UInt8]; let w: Int; let h: Int }
    private struct Row: Equatable { let hash: UInt64; let informative: Bool }

    private let options: Options
    private var last: Frame?
    private var lastPos = 0      // result row where the last good frame's top row sits
    private var lastBottom = 0   // rows at the bottom of the last frame that stayed put (sticky footer)
    private var canvas: [UInt8] = []
    private var isFull = false
    private let minScore = 0.8

    public init(options: Options = Options()) { self.options = options }

    /// Height of the image `makeImage()` would return now.
    public var height: Int {
        guard let f = last else { return 0 }
        return canvas.isEmpty ? f.h : canvas.count / (f.w * 4) + lastBottom
    }

    @discardableResult
    public func add(_ image: CGImage) -> Step {
        guard let cur = Self.frame(image) else { return .lostTrack }
        guard let prev = last else { last = cur; return .started }
        guard cur.w == prev.w, cur.h == prev.h else { return .lostTrack }
        if isFull { return .full }
        let w = cur.w, h = cur.h

        // Only the columns that changed are matched, so a static area beside the scrolling part can't hide the match.
        let limit = max(1, w - min(max(0, options.scrollbarMargin), w / 4))   // narrow regions keep most columns
        var x0 = limit, x1 = 0
        for y in 0..<h {
            let row = y * w
            var x = 0
            while x < limit && prev.luma[row + x] == cur.luma[row + x] { x += 1 }
            if x == limit { continue }
            x0 = min(x0, x)
            var r = limit - 1
            while r > x && r >= x1 && prev.luma[row + r] == cur.luma[row + r] { r -= 1 }
            x1 = max(x1, r + 1)
        }
        guard x1 > x0 else { last = cur; return .unchanged }

        let hp = Self.rows(prev, x0, x1), hc = Self.rows(cur, x0, x1)
        var t = 0
        while t < h && hp[t] == hc[t] { t += 1 }
        guard t < h else { last = cur; return .unchanged }
        var b = 0
        while b < h - t && hp[h - 1 - b] == hc[h - 1 - b] { b += 1 }
        let lo = t, hi = h - b, m = hi - lo
        let minOverlap = max(4, m / 6)
        guard m > minOverlap else { last = cur; return .unchanged }

        // Shift d means the current frame's row r shows what the last frame had at row r + d.
        var bestD = 0, bestScore = -1.0
        for d in -(m - minOverlap)...(m - minOverlap) {
            let r0 = max(lo, lo - d), r1 = min(hi, hi - d)
            var info = 0, hit = 0
            for r in r0..<r1 where hc[r].informative {
                info += 1
                if hc[r].hash == hp[r + d].hash { hit += 1 }
            }
            guard info >= max(3, (r1 - r0) / 20) else { continue }
            let score = Double(hit) / Double(info)
            if score > bestScore + 1e-9 || (abs(score - bestScore) <= 1e-9 && abs(d) < abs(bestD)) { bestD = d; bestScore = score }
        }
        guard bestScore >= minScore else { return .lostTrack }
        guard bestD != 0 else { last = cur; return .unchanged }

        let pos = lastPos + bestD
        let added = commit(prev, at: lastPos, end: hi) + commit(cur, at: pos, end: hi)
        last = cur; lastPos = pos; lastBottom = b
        return isFull ? .full : .added(added)
    }

    /// The stitched image so far: everything scrolled past, then the last frame's sticky footer.
    public func makeImage() -> CGImage? {
        guard let f = last else { return nil }
        if canvas.isEmpty { return Self.image(Data(f.rgba), w: f.w, h: f.h) }
        // One copy into Data; tall results run to hundreds of MB.
        var bytes = Data(capacity: canvas.count + lastBottom * f.w * 4)
        bytes.append(contentsOf: canvas)
        bytes.append(contentsOf: f.rgba[((f.h - lastBottom) * f.w * 4)...])
        return Self.image(bytes, w: f.w, h: canvas.count / (f.w * 4) + lastBottom)
    }

    /// Appends the rows of `f` (placed at result row `p`) that lie below what's already kept, up to frame row `end`.
    private func commit(_ f: Frame, at p: Int, end: Int) -> Int {
        let have = canvas.count / (f.w * 4)
        let start = max(0, have - p)
        guard start < end, p + start == have else { return 0 }
        var rows = end - start
        let maxRows = max(f.h, options.maxPixels / f.w)
        if have + rows > maxRows { rows = max(0, maxRows - have); isFull = true }
        canvas.append(contentsOf: f.rgba[(start * f.w * 4)..<((start + rows) * f.w * 4)])
        return rows
    }

    private static func rows(_ f: Frame, _ x0: Int, _ x1: Int) -> [Row] {
        (0..<f.h).map { y in
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            var lo: UInt8 = 255, hi: UInt8 = 0
            let base = y * f.w
            for x in x0..<x1 {
                let v = f.luma[base + x]
                hash = (hash ^ UInt64(v >> 2)) &* 0x0000_0100_0000_01b3
                lo = min(lo, v); hi = max(hi, v)
            }
            return Row(hash: hash, informative: hi - lo > 24)
        }
    }

    private static func frame(_ image: CGImage) -> Frame? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        var luma = [UInt8](repeating: 0, count: w * h)
        for i in 0..<(w * h) {
            luma[i] = UInt8((Int(rgba[i * 4]) * 77 + Int(rgba[i * 4 + 1]) * 150 + Int(rgba[i * 4 + 2]) * 29) >> 8)
        }
        return Frame(rgba: rgba, luma: luma, w: w, h: h)
    }

    private static func image(_ rgba: Data, w: Int, h: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
