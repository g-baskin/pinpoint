import CoreGraphics
import XCTest
@testable import PinpointCore

final class ScrollStitcherTests: XCTestCase {
    private var width = 60

    /// Grey rows: random noise, with a blank white row every 7th row like line spacing in a page.
    private func page(rows: Int) -> [[UInt8]] {
        var seed: UInt64 = 42
        return (0..<rows).map { y in
            (0..<width).map { _ in
                if y % 7 == 0 { return 255 }
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return UInt8(truncatingIfNeeded: seed >> 33)
            }
        }
    }

    private func bars(_ rows: Int, _ a: Int, _ b: Int) -> [[UInt8]] {
        (0..<rows).map { y in (0..<width).map { x in UInt8((x * a + y * b) % 256) } }
    }

    private func image(_ rows: [[UInt8]]) -> CGImage {
        let bytes: [UInt8] = rows.flatMap { $0.flatMap { v -> [UInt8] in [v, v, v, 255] } }
        return CGImage(width: width, height: rows.count, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }

    private func grey(_ img: CGImage) -> [[UInt8]] {
        var bytes = [UInt8](repeating: 0, count: img.width * img.height * 4)
        let ctx = CGContext(data: &bytes, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        return (0..<img.height).map { y in (0..<img.width).map { x in bytes[(y * img.width + x) * 4] } }
    }

    func testStitchesScrolledFramesWithStickyHeaderAndFooterOnce() {
        let p = page(rows: 600), header = bars(20, 7, 13), footer = bars(10, 3, 29)
        func view(_ offset: Int) -> CGImage { image(header + Array(p[offset..<offset + 90]) + footer) }
        let s = ScrollStitcher()
        XCTAssertEqual(s.add(view(0)), .started)
        XCTAssertEqual(s.add(view(0)), .unchanged)
        func moved(_ step: ScrollStitcher.Step) -> Bool { if case .added = step { return true } else { return false } }
        XCTAssertTrue(moved(s.add(view(25))))
        XCTAssertTrue(moved(s.add(view(60))))
        XCTAssertEqual(s.add(view(30)), .added(0))     // scrolled back up: nothing new
        XCTAssertTrue(moved(s.add(view(100))))
        XCTAssertTrue(moved(s.add(view(170))))
        XCTAssertEqual(s.add(view(500)), .lostTrack)   // too far in one go
        XCTAssertTrue(moved(s.add(view(240))))         // back in range of the last good frame
        XCTAssertEqual(s.height, 20 + 330 + 10)
        XCTAssertEqual(grey(s.makeImage()!), header + Array(p[0..<330]) + footer)
    }

    func testSingleFrameComesBackUnchanged() {
        let rows = page(rows: 80)
        let s = ScrollStitcher()
        XCTAssertNil(s.makeImage())
        s.add(image(rows))
        XCTAssertEqual(grey(s.makeImage()!), rows)
    }

    func testStopsAtSizeLimit() {
        let p = page(rows: 400)
        let s = ScrollStitcher(options: .init(maxPixels: width * 150))
        s.add(image(Array(p[0..<100])))
        XCTAssertEqual(s.add(image(Array(p[60..<160]))), .full)
        XCTAssertEqual(s.add(image(Array(p[90..<190]))), .full)
        XCTAssertEqual(s.makeImage()?.height, 150)
    }

    func testNarrowRegionStillMatchesDespiteScrollbarMargin() {
        width = 30
        let p = page(rows: 300)
        let s = ScrollStitcher(options: .init(scrollbarMargin: 40))
        s.add(image(Array(p[0..<100])))
        XCTAssertNotEqual(s.add(image(Array(p[30..<130]))), .lostTrack)
        XCTAssertEqual(grey(s.makeImage()!), Array(p[0..<130]))
    }
}
