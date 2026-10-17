import AppKit
import Observation
import TrashFlushCore

/// The menu bar icon: a Trash can that fills up as the Trash does. Past your
/// limit its lid pops open and two flies buzz around it until you flush.
@MainActor
@Observable
final class MenuBarIcon {
    private(set) var image: NSImage

    @ObservationIgnored private var fullness = TrashFullness.empty
    @ObservationIgnored private var buzz: Task<Void, Never>?

    /// One loop of the flies.
    private static let frameCount = 24
    private static let size = NSSize(width: 22, height: 18)

    init() {
        image = Self.draw(.empty, frame: 0)
    }

    func show(_ fullness: TrashFullness) {
        guard fullness != self.fullness else { return }
        self.fullness = fullness
        buzz?.cancel()
        buzz = nil
        image = Self.draw(fullness, frame: 0)
        guard fullness.isOverflowing, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        let frames = (0..<Self.frameCount).map { Self.draw(fullness, frame: $0) }
        buzz = Task { [weak self] in
            var frame = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / 12))
                guard let self, !Task.isCancelled else { return }
                frame = (frame + 1) % frames.count
                image = frames[frame]
            }
        }
    }

    // MARK: Drawing

    private static func draw(_ fullness: TrashFullness, frame: Int) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            drawLid(open: fullness.isOverflowing)
            drawCan(filled: fullness.fraction)
            if fullness.isOverflowing { drawFlies(frame: frame) }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawCan(filled fraction: Double) {
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 6.2, y: 12.6))
        body.line(to: NSPoint(x: 7.1, y: 2.9))
        body.curve(to: NSPoint(x: 8.2, y: 1.8), controlPoint1: NSPoint(x: 7.15, y: 2.2), controlPoint2: NSPoint(x: 7.5, y: 1.8))
        body.line(to: NSPoint(x: 13.8, y: 1.8))
        body.curve(to: NSPoint(x: 14.9, y: 2.9), controlPoint1: NSPoint(x: 14.5, y: 1.8), controlPoint2: NSPoint(x: 14.85, y: 2.2))
        body.line(to: NSPoint(x: 15.8, y: 12.6))
        body.lineWidth = 1.3
        body.lineCapStyle = .round
        body.lineJoinStyle = .round
        body.stroke()

        guard fraction > 0 else { return }
        let inside = NSBezierPath()
        inside.move(to: NSPoint(x: 7.6, y: 11.9))
        inside.line(to: NSPoint(x: 8.3, y: 3.2))
        inside.line(to: NSPoint(x: 13.7, y: 3.2))
        inside.line(to: NSPoint(x: 14.4, y: 11.9))
        inside.close()
        NSGraphicsContext.saveGraphicsState()
        inside.addClip()
        NSRect(x: 0, y: 3.2, width: size.width, height: (11.9 - 3.2) * fraction).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The lid and its handle. Open, it tips up from its right end.
    private static func drawLid(open: Bool) {
        let lid = NSBezierPath()
        lid.move(to: NSPoint(x: 5, y: 14))
        lid.line(to: NSPoint(x: 17, y: 14))
        lid.move(to: NSPoint(x: 9.3, y: 14))
        lid.line(to: NSPoint(x: 9.3, y: 15.6))
        lid.line(to: NSPoint(x: 12.7, y: 15.6))
        lid.line(to: NSPoint(x: 12.7, y: 14))
        lid.lineWidth = 1.3
        lid.lineCapStyle = .round
        lid.lineJoinStyle = .round
        if open {
            var tilt = AffineTransform(translationByX: -17, byY: -14)
            tilt.append(AffineTransform(rotationByDegrees: 10))
            tilt.append(AffineTransform(translationByX: 17, byY: 14))
            lid.transform(using: tilt)
        }
        lid.stroke()
    }

    /// Two flies looping figure-eights on either side of the can.
    private static func drawFlies(frame: Int) {
        let t = Double(frame) / Double(frameCount) * 2 * .pi
        let flies = [
            NSPoint(x: 2.6 + 1.6 * sin(t), y: 9.5 + 1.3 * sin(2 * t)),
            NSPoint(x: 19.4 + 1.5 * sin(-t + 2), y: 7.5 + 1.2 * sin(2 * t + 1)),
        ]
        for fly in flies {
            NSBezierPath(ovalIn: NSRect(x: fly.x - 1, y: fly.y - 1, width: 2, height: 2)).fill()
        }
    }
}
