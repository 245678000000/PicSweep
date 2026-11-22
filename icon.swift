import AppKit
let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: a)
}
func grad(_ cols: [CGColor], _ p0: CGPoint, _ p1: CGPoint) {
    let g = CGGradient(colorsSpace: cs, colors: cols as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }

// Base squircle with shadow
let base = CGRect(x: 100, y: 100, width: 824, height: 824)
let basePath = rr(base, 186)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: c(0x000000, 0.35))
ctx.addPath(basePath); ctx.setFillColor(c(0x20234A)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState(); ctx.addPath(basePath); ctx.clip()
grad([c(0x3A3F9E), c(0x1B1E3D)], CGPoint(x: 200, y: 924), CGPoint(x: 824, y: 100))
// soft glow
let glow = CGGradient(colorsSpace: cs, colors: [c(0x8B7CFF, 0.55), c(0x8B7CFF, 0)] as CFArray, locations: nil)!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 560), endRadius: 420, options: [])
ctx.restoreGState()

// Photo card
func card(center: CGPoint, angle: CGFloat, scene: (CGRect) -> Void) {
    let w: CGFloat = 430, h: CGFloat = 350
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y); ctx.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: c(0x000000, 0.4))
    ctx.addPath(rr(r, 34)); ctx.setFillColor(c(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    let inner = r.insetBy(dx: 20, dy: 20)
    ctx.saveGState(); ctx.addPath(rr(inner, 18)); ctx.clip(); scene(inner); ctx.restoreGState()
    ctx.restoreGState()
}
func mountains(_ r: CGRect, _ far: CGColor, _ near: CGColor) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX, y: r.minY + r.height*0.30))
    p.addLine(to: CGPoint(x: r.minX + r.width*0.30, y: r.minY + r.height*0.62))
    p.addLine(to: CGPoint(x: r.minX + r.width*0.52, y: r.minY + r.height*0.40))
    p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height*0.30))
    p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.closeSubpath()
    ctx.addPath(p); ctx.setFillColor(far); ctx.fillPath()
    let q = CGMutablePath()
    q.move(to: CGPoint(x: r.minX, y: r.minY + r.height*0.12))
    q.addLine(to: CGPoint(x: r.minX + r.width*0.62, y: r.minY + r.height*0.50))
    q.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height*0.22))
    q.addLine(to: CGPoint(x: r.maxX, y: r.minY)); q.addLine(to: CGPoint(x: r.minX, y: r.minY)); q.closeSubpath()
    ctx.addPath(q); ctx.setFillColor(near); ctx.fillPath()
}
card(center: CGPoint(x: 470, y: 560), angle: 14) { r in
    grad([c(0xFFC3A0), c(0xFF8FA3)], CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.midX, y: r.minY))
}
card(center: CGPoint(x: 545, y: 535), angle: -9) { r in
    grad([c(0xC7B8FF), c(0x8E7BF0)], CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.midX, y: r.minY))
}
card(center: CGPoint(x: 505, y: 470), angle: 0) { r in
    grad([c(0x6FB8FF), c(0xBFE3FF)], CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.midX, y: r.minY))
    ctx.setFillColor(c(0xFFD45C))
    ctx.fillEllipse(in: CGRect(x: r.maxX - 120, y: r.maxY - 112, width: 66, height: 66))
    mountains(r, c(0x5FC79A), c(0x2E9E77))
}
// sparkle
func sparkle(_ p: CGPoint, _ s: CGFloat, _ col: CGColor) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: p.x, y: p.y + s))
    path.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - s), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y), control: p)
    path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s), control: p)
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 18, color: c(0xFFFFFF, 0.8))
    ctx.addPath(path); ctx.setFillColor(col); ctx.fillPath(); ctx.restoreGState()
}
sparkle(CGPoint(x: 752, y: 762), 78, c(0xFFFFFF))
sparkle(CGPoint(x: 820, y: 660), 34, c(0xFFE7A3))
sparkle(CGPoint(x: 245, y: 290), 28, c(0xFFFFFF, 0.85))

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
