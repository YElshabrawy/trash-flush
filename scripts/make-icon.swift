// Turns the square icon artwork into a macOS app icon: masked to Apple's
// rounded-square shape on the standard 1024 grid, with its drop shadow.
// Usage: swift scripts/make-icon.swift Support/icon-art.jpg output.png
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, let art = NSImage(contentsOfFile: arguments[0]) else {
    fatalError("Usage: make-icon.swift <artwork> <output.png>")
}
let canvas = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Could not create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

// Apple's icon grid: an 824 pt rounded square centered in the 1024 canvas.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
shape.addClip()
art.draw(in: body, from: .zero, operation: .copy, fraction: 1)
// A hairline of light along the edge, like Apple's own icons.
NSColor.white.withAlphaComponent(0.25).setStroke()
shape.lineWidth = 4
shape.stroke()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: URL(fileURLWithPath: arguments[1]))
print("Wrote \(arguments[1])")
