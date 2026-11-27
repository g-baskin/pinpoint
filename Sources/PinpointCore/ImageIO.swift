import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageFiles {
    public static func load(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true] as CFDictionary)
    }

    public static func encode(_ image: CGImage, type: UTType = .png, quality: Double = 0.9) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func write(_ image: CGImage, to url: URL, type: UTType = .png, quality: Double = 0.9) throws {
        guard let data = encode(image, type: type, quality: quality) else {
            throw NSError(domain: "Pinpoint", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode image"])
        }
        try data.write(to: url, options: .atomic)
    }

    /// Downscales so the long edge is at most `maxDimension`. Returns the image and the scale applied (<= 1).
    public static func downscaled(_ image: CGImage, maxDimension: Int) -> (CGImage, CGFloat) {
        let longEdge = max(image.width, image.height)
        guard longEdge > maxDimension else { return (image, 1) }
        let s = CGFloat(maxDimension) / CGFloat(longEdge)
        let w = max(1, Int(CGFloat(image.width) * s)), h = max(1, Int(CGFloat(image.height) * s))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (image, 1) }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = ctx.makeImage() else { return (image, 1) }
        return (out, s)
    }

    /// PNG bytes suitable for sending to a vision model, plus the scale from original pixels to sent pixels.
    public static func forModel(_ image: CGImage, maxDimension: Int = 1568) -> (data: Data, scale: CGFloat, size: CGSize) {
        let (img, s) = downscaled(image, maxDimension: maxDimension)
        let data = encode(img, type: .png) ?? Data()
        return (data, s, CGSize(width: img.width, height: img.height))
    }
}
