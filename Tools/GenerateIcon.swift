// Usage: swift Tools/GenerateIcon.swift
// Generates Assets/AppIcon.iconset, Assets/AppIcon.icns and the runtime/preview PNGs.
import AppKit
import CoreGraphics

func draw(size s: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()
    func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [r, g, b, a])!
    }
    let u = s / 1024
    // macOS squircle with standard margin
    let rect = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let path = CGPath(roundedRect: rect, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * u), blur: 28 * u, color: col(0, 0, 0, 0.35))
    ctx.addPath(path); ctx.setFillColor(col(0, 0, 0)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let bg = CGGradient(colorsSpace: cs, colors: [col(0.12, 0.85, 0.80), col(0.20, 0.45, 0.98), col(0.50, 0.25, 0.90)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    // soft top glow
    let glow = CGGradient(colorsSpace: cs, colors: [col(1, 1, 1, 0.35), col(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 400 * u, y: 900 * u), startRadius: 0,
                           endCenter: CGPoint(x: 400 * u, y: 900 * u), endRadius: 600 * u, options: [])

    // broom, rotated
    ctx.translateBy(x: 512 * u, y: 500 * u)
    ctx.rotate(by: -0.6)
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 18 * u, color: col(0, 0, 0, 0.3))
    // handle
    let handle = CGPath(roundedRect: CGRect(x: -20 * u, y: 40 * u, width: 40 * u, height: 380 * u),
                        cornerWidth: 20 * u, cornerHeight: 20 * u, transform: nil)
    ctx.addPath(handle); ctx.setFillColor(col(1, 1, 1)); ctx.fillPath()
    // ferrule
    let ferrule = CGPath(roundedRect: CGRect(x: -85 * u, y: -10 * u, width: 170 * u, height: 70 * u),
                         cornerWidth: 18 * u, cornerHeight: 18 * u, transform: nil)
    ctx.addPath(ferrule); ctx.setFillColor(col(1.0, 0.80, 0.30)); ctx.fillPath()
    // bristles
    let b = CGMutablePath()
    b.move(to: CGPoint(x: -85 * u, y: -10 * u))
    b.addLine(to: CGPoint(x: 85 * u, y: -10 * u))
    b.addLine(to: CGPoint(x: 150 * u, y: -250 * u))
    b.addQuadCurve(to: CGPoint(x: -150 * u, y: -250 * u), control: CGPoint(x: 0, y: -300 * u))
    b.closeSubpath()
    ctx.addPath(b); ctx.setFillColor(col(1, 1, 1, 0.95)); ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setStrokeColor(col(0.20, 0.45, 0.98, 0.35)); ctx.setLineWidth(8 * u); ctx.setLineCap(.round)
    for x in stride(from: -90, through: 90, by: 45) {
        ctx.move(to: CGPoint(x: CGFloat(x) * 0.5 * u, y: -50 * u))
        ctx.addLine(to: CGPoint(x: CGFloat(x) * u * 1.3, y: -250 * u))
        ctx.strokePath()
    }
    ctx.restoreGState()

    // sparkles
    func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cx, y: cy + r))
        p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.12, y: cy + r * 0.12))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx + r * 0.12, y: cy - r * 0.12))
        p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.12, y: cy - r * 0.12))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx - r * 0.12, y: cy + r * 0.12))
        ctx.addPath(p); ctx.setFillColor(col(1, 1, 1, 0.95)); ctx.fillPath()
    }
    sparkle(250 * u, 330 * u, 70 * u)
    sparkle(780 * u, 300 * u, 45 * u)
    sparkle(500 * u, 800 * u, 38 * u)

    // rim highlight
    ctx.addPath(path); ctx.setStrokeColor(col(1, 1, 1, 0.25)); ctx.setLineWidth(3 * u); ctx.strokePath()
    img.unlockFocus()
    return img
}

func writePNG(_ img: NSImage, px: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = assets.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
let master = draw(size: 1024)
for base in [16, 32, 128, 256, 512] {
    try writePNG(master, px: base, to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try writePNG(master, px: base * 2, to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try writePNG(master, px: 1024, to: assets.appendingPathComponent("AppIcon-preview.png"))
let res = root.appendingPathComponent("Sources/AppSweeper/Resources")
try fm.createDirectory(at: res, withIntermediateDirectories: true)
try writePNG(master, px: 512, to: res.appendingPathComponent("AppIcon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try p.run(); p.waitUntilExit()
print("done, iconutil exit \(p.terminationStatus)")
