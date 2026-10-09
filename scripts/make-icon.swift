// Draws the app icon in code, so the repo needs no image assets.
// Usage: swift scripts/make-icon.swift output.png
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "icon.png"
let canvas = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Could not create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple's icon grid: an 824 pt rounded square centered in the 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
let center = NSPoint(x: body.midX, y: body.midY)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

let deep = NSColor(red: 0.02, green: 0.10, blue: 0.32, alpha: 1)
let water = NSColor(red: 0.08, green: 0.44, blue: 0.86, alpha: 1)
let shallow = NSColor(red: 0.55, green: 0.86, blue: 1.00, alpha: 1)
NSGradient(colors: [shallow, water, deep])?.draw(in: shape, angle: -65)

// Swirl arms, the same spiral the animation uses.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
for arm in 0..<5 {
    let phase = Double(arm) * 2 * .pi / 5
    let spiral = NSBezierPath()
    for step in 0...60 {
        let u = Double(step) / 60
        let radius = 560 * pow(1 - u, 1.3)
        let angle = phase + 2.6 * (pow(1 - u * 0.92, -0.9) - 1)
        let point = NSPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        if step == 0 { spiral.move(to: point) } else { spiral.line(to: point) }
    }
    spiral.lineWidth = 34
    spiral.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.16).setStroke()
    spiral.stroke()
}
NSGraphicsContext.restoreGraphicsState()

let config = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let symbol = NSImage(systemSymbolName: "toilet.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let size = symbol.size
    symbol.draw(in: NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                           width: size.width, height: size.height))
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
