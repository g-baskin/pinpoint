// Draws the Pinpoint bullseye artwork: Resources/AppIcon.icns plus assets/icon.png, assets/readme-banner.png
// and assets/social-preview.png. Run from the repo root: swift scripts/make-icon.swift
import AppKit

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let navy = rgb(0x0E1430), indigo = rgb(0x2B1D63), coral = rgb(0xFF4B5C), orange = rgb(0xFF8A3D), cream = rgb(0xFFF6EE)

func bitmap(_ w: Int, _ h: Int, _ draw: (CGRect) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// The bullseye on its own, centred in `r` (a square): alternating coral and cream rings, a crosshair and a glowing centre.
func drawBullseye(in r: CGRect) {
    let c = CGPoint(x: r.midX, y: r.midY), R = r.width / 2
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -R * 0.06), blur: R * 0.18, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    rgb(0xFFFFFF).setFill()
    NSBezierPath(ovalIn: r).fill()
    ctx.restoreGState()
    let rings: [(CGFloat, Bool)] = [(1.0, true), (0.8, false), (0.6, true), (0.4, false), (0.22, true)]
    for (scale, isCoral) in rings {
        let rr = R * scale
        let path = NSBezierPath(ovalIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
        if isCoral {
            NSGradient(colors: [orange, coral, rgb(0xE8236B)])!.draw(in: path, angle: -55)
        } else {
            NSGradient(colors: [rgb(0xFFFFFF), cream])!.draw(in: path, angle: -90)
        }
    }
    // Top-left sheen for a little depth.
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: r).addClip()
    let sheen = NSBezierPath(ovalIn: CGRect(x: c.x - R * 0.92, y: c.y - R * 0.05, width: R * 1.5, height: R * 0.95))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!.draw(in: sheen, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    // Crosshair: thin lines through the centre with a gap around the dot.
    navy.withAlphaComponent(0.55).setStroke()
    for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] as [(CGFloat, CGFloat)] {
        let line = NSBezierPath()
        line.lineWidth = max(1, R * 0.025)
        line.lineCapStyle = .round
        line.move(to: CGPoint(x: c.x + dx * R * 0.3, y: c.y + dy * R * 0.3))
        line.line(to: CGPoint(x: c.x + dx * R * 0.93, y: c.y + dy * R * 0.93))
        line.stroke()
    }
    // The pinpoint: a navy centre dot with a bright core.
    let dot = R * 0.11
    navy.setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - dot, y: c.y - dot, width: dot * 2, height: dot * 2)).fill()
    let core = dot * 0.42
    cream.setFill()
    NSBezierPath(ovalIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)).fill()
}

/// The full app icon: navy-indigo rounded square with a soft glow behind the bullseye.
func drawIcon(in s: CGRect) {
    let inset = s.width * 0.09
    let tile = s.insetBy(dx: inset, dy: inset)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s.width * 0.01), blur: s.width * 0.025, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
    navy.setFill()
    path.fill()
    ctx.restoreGState()
    NSGradient(colors: [indigo, navy])!.draw(in: path, angle: -70)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let glowR = tile.width * 0.48
    NSGradient(colors: [coral.withAlphaComponent(0.35), coral.withAlphaComponent(0)])!
        .draw(fromCenter: CGPoint(x: tile.midX, y: tile.midY), radius: 0, toCenter: CGPoint(x: tile.midX, y: tile.midY), radius: glowR, options: [])
    NSGraphicsContext.restoreGraphicsState()
    let b = tile.width * 0.64
    drawBullseye(in: CGRect(x: tile.midX - b / 2, y: tile.midY - b / 2, width: b, height: b))
}

/// Banner layout shared by the README image and the social preview.
func drawBanner(in r: CGRect, title: CGFloat, tagline: String, footer: String?) {
    NSGradient(colors: [indigo, navy, rgb(0x080C1E)])!.draw(in: r, angle: -20)
    let iconSize = r.height * (footer == nil ? 0.78 : 0.56)
    let iconRect = CGRect(x: r.width * 0.06, y: (r.height - iconSize) / 2, width: iconSize, height: iconSize)
    NSGradient(colors: [coral.withAlphaComponent(0.25), coral.withAlphaComponent(0)])!
        .draw(fromCenter: CGPoint(x: iconRect.midX, y: iconRect.midY), radius: 0,
              toCenter: CGPoint(x: iconRect.midX, y: iconRect.midY), radius: iconSize * 0.9, options: [])
    drawIcon(in: iconRect)
    let textX = iconRect.maxX + r.width * 0.04
    let width = r.width - textX - r.width * 0.05
    let titleAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: title, weight: .heavy), .foregroundColor: cream]
    let tagAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: title * 0.3, weight: .medium),
                                                    .foregroundColor: rgb(0xC9CCE8)]
    let titleStr = NSAttributedString(string: "Pinpoint", attributes: titleAttrs)
    let tagStr = NSAttributedString(string: tagline, attributes: tagAttrs)
    let tagBox = tagStr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
    let titleH = titleStr.size().height
    let gap = title * 0.12
    var blockH = titleH + gap + tagBox.height
    var footStr: NSAttributedString?
    if let footer {
        footStr = NSAttributedString(string: footer, attributes: [.font: NSFont.monospacedSystemFont(ofSize: title * 0.22, weight: .semibold),
                                                                   .foregroundColor: orange])
        blockH += gap * 2 + footStr!.size().height
    }
    var y = (r.height + blockH) / 2 - titleH
    titleStr.draw(at: CGPoint(x: textX, y: y))
    y -= gap + tagBox.height
    tagStr.draw(with: CGRect(x: textX, y: y, width: width, height: tagBox.height), options: [.usesLineFragmentOrigin])
    if let footStr { footStr.draw(at: CGPoint(x: textX, y: y - gap * 2 - footStr.size().height)) }
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for px in [16, 32, 128, 256, 512] {
    try! bitmap(px, px, drawIcon).write(to: iconset.appendingPathComponent("icon_\(px)x\(px).png"))
    try! bitmap(px * 2, px * 2, drawIcon).write(to: iconset.appendingPathComponent("icon_\(px)x\(px)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
precondition(iconutil.terminationStatus == 0, "iconutil failed")

try! fm.createDirectory(at: URL(fileURLWithPath: "assets"), withIntermediateDirectories: true)
try! bitmap(512, 512, drawIcon).write(to: URL(fileURLWithPath: "assets/icon.png"))
let tagline = "Screenshot, mark up and redact on your Mac, with a built-in AI agent."
try! bitmap(1600, 500) { drawBanner(in: $0, title: 150, tagline: tagline, footer: nil) }.write(to: URL(fileURLWithPath: "assets/readme-banner.png"))
try! bitmap(1280, 640) { drawBanner(in: $0, title: 132, tagline: tagline, footer: "github.com/g-baskin/pinpoint") }
    .write(to: URL(fileURLWithPath: "assets/social-preview.png"))
print("Wrote Resources/AppIcon.icns, assets/icon.png, assets/readme-banner.png, assets/social-preview.png")
