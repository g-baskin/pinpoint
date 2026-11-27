// Generates Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let out = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px), inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.42, blue: 0.21, alpha: 1), NSColor(srgbRed: 0.93, green: 0.13, blue: 0.45, alpha: 1)])!
        .draw(in: path, angle: -60)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.46, weight: .bold)
    if let sym = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
        }
        let sz = tinted.size
        tinted.draw(in: CGRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for px in sizes where px <= 512 {
    try! render(px).write(to: out.appendingPathComponent("icon_\(px)x\(px).png"))
    try! render(px * 2).write(to: out.appendingPathComponent("icon_\(px)x\(px)@2x.png"))
}
