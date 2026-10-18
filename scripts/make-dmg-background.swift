// Draws the background of the DMG's Finder window: a soft blue wash and an
// arrow from the app to the Applications folder. Drawn at 2x for Retina;
// make-dmg.sh tags it 144 dpi so Finder shows it at 660 × 400 points.
// Usage: swift scripts/make-dmg-background.swift output.png
import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "background.png"
let width = 660, height = 400, scale = 2

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("Could not create bitmap") }
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bounds = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(colors: [NSColor(red: 0.93, green: 0.97, blue: 1, alpha: 1),
                    NSColor(red: 0.82, green: 0.91, blue: 1, alpha: 1)])?.draw(in: bounds, angle: -90)

// The icons sit at x 170 and 490, 190 from the top (make-dmg.sh places them).
// AppKit's y points up, so that's y 210 here.
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 262, y: 210))
arrow.curve(to: NSPoint(x: 392, y: 210), controlPoint1: NSPoint(x: 300, y: 240), controlPoint2: NSPoint(x: 354, y: 240))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
let blue = NSColor(red: 0.12, green: 0.45, blue: 0.92, alpha: 0.85)
blue.setStroke()
let dash: [CGFloat] = [0.1, 12]
arrow.setLineDash(dash, count: 2, phase: 0)
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 380, y: 226))
head.line(to: NSPoint(x: 398, y: 207))
head.line(to: NSPoint(x: 374, y: 201))
head.lineWidth = 5
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, y: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ]
    NSAttributedString(string: text, attributes: attributes)
        .draw(in: NSRect(x: 0, y: y, width: CGFloat(width), height: size * 1.5))
}
draw("Drag Trash Flush to Applications", size: 17, weight: .semibold,
     color: NSColor(white: 0.15, alpha: 1), y: 68)
draw("Then open it from Applications and grant Full Disk Access when asked.", size: 12, weight: .regular,
     color: NSColor(white: 0.35, alpha: 1), y: 44)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
