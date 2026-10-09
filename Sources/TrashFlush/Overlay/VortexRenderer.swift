import SwiftUI
import TrashFlushCore

/// Draws one frame of the flush into a Canvas `GraphicsContext`.
///
/// A plain struct rather than View methods: it holds only values, so the
/// Canvas can call it without touching any main-actor state.
struct VortexRenderer {
    let palette: ThemePalette
    let fileCount: Int
    let reduceMotion: Bool

    func draw(in context: inout GraphicsContext, size: CGSize, time t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let spin = reduceMotion ? 0 : FlushTimeline.spin(t)
        let drain = FlushTimeline.drain(t)
        let gulp = 1 - 0.12 * (1 - FlushTimeline.opacity(t))
        // Leaves room inside the canvas for the pop-in overshoot and the shadow.
        let popIn: Double = 0.6 + 0.4 * easeOutBack(FlushTimeline.appear(t))
        let radius = size.width * 0.4 * CGFloat(popIn * gulp)

        context.opacity = FlushTimeline.opacity(t) * min(1, FlushTimeline.appear(t) * 2)

        drawShadow(in: &context, center: center, radius: radius)

        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.fill(disc, with: .radialGradient(
            Gradient(stops: [
                .init(color: palette.deep, location: 0),
                .init(color: palette.water, location: 0.3 + 0.35 * drain),
                .init(color: palette.shallow, location: 1),
            ]),
            center: center, startRadius: 0, endRadius: radius))

        context.drawLayer { water in
            water.clip(to: disc)
            drawArms(in: &water, center: center, radius: radius, count: 5, phase: spin,
                     halfWidth: 0.075, color: palette.foam.opacity(0.32))
            drawArms(in: &water, center: center, radius: radius, count: 7, phase: spin * 1.35 + 0.4,
                     halfWidth: 0.03, color: palette.shallow.opacity(0.22))
            drawFoam(in: &water, center: center, radius: radius, spin: spin, drain: drain)
            drawDrain(in: &water, center: center, radius: radius, drain: drain)
        }

        if !reduceMotion {
            drawFiles(in: &context, center: center, radius: radius, t: t, spin: spin)
        }

        drawRim(in: &context, center: center, radius: radius)
    }

    /// A soft gradient instead of a real shadow: much cheaper to redraw every frame.
    private func drawShadow(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * 1.18
        let offsetCenter = CGPoint(x: center.x, y: center.y + radius * 0.06)
        context.fill(
            Path(ellipseIn: CGRect(x: offsetCenter.x - r, y: offsetCenter.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(Gradient(colors: [.black.opacity(0.45), .clear]),
                                  center: offsetCenter, startRadius: radius * 0.85, endRadius: r))
    }

    /// Tapered spiral ribbons. Each arm is a closed shape whose angular width is
    /// constant, so it gets thinner on its own as it winds toward the drain.
    private func drawArms(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                          count: Int, phase: Double, halfWidth: Double, color: Color) {
        let steps = 40
        for arm in 0..<count {
            let armPhase = phase + Double(arm) * 2 * .pi / Double(count)
            var leftEdge: [CGPoint] = []
            var rightEdge: [CGPoint] = []
            for step in 0...steps {
                let point = Vortex.armPoint(u: Double(step) / Double(steps), phase: armPhase)
                leftEdge.append(polar(center, radius * point.radius, point.angle - halfWidth))
                rightEdge.append(polar(center, radius * point.radius, point.angle + halfWidth))
            }
            var path = Path()
            path.addLines(leftEdge + rightEdge.reversed())
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
    }

    /// Little foam bubbles orbiting the drain, faster the closer they are.
    private func drawFoam(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                          spin: Double, drain: Double) {
        for i in 0..<36 {
            let seed = Double(i)
            let orbit = (0.18 + 0.78 * (seed * 0.618_034).truncatingRemainder(dividingBy: 1)) * (1 - 0.45 * drain)
            let angle = Vortex.startAngle(for: i) + spin * 0.55 / max(orbit, 0.2)
            let size = 1.5 + 2.5 * (seed * 0.371).truncatingRemainder(dividingBy: 1)
            let p = polar(center, radius * orbit, angle)
            context.fill(Path(ellipseIn: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)),
                         with: .color(palette.foam.opacity(0.55)))
        }
    }

    private func drawDrain(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, drain: Double) {
        let hole = radius * (0.09 + 0.08 * drain)
        let glow = hole * 2.2
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(Gradient(stops: [
                .init(color: .black.opacity(0.95), location: 0),
                .init(color: .black.opacity(0.9), location: hole / glow),
                .init(color: palette.deep.opacity(0), location: 1),
            ]), center: center, startRadius: 0, endRadius: glow))
    }

    /// Files sink one after another, spinning faster as they near the drain.
    /// Their icons are Canvas symbols tagged 0..<fileCount.
    private func drawFiles(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, t: Double, spin: Double) {
        for index in 0..<fileCount {
            let progress = FlushTimeline.particleProgress(index: index, count: fileCount, at: t)
            guard progress > 0, progress < 1, let symbol = context.resolveSymbol(id: index) else { continue }

            let placement = Vortex.particle(progress: progress, startAngle: Vortex.startAngle(for: index),
                                            startRadius: 0.78)
            let angle = placement.angle + spin * 0.25
            let position = polar(center, radius * placement.radius, angle)
            var file = context
            file.opacity *= placement.opacity
            file.translateBy(x: position.x, y: position.y)
            file.rotate(by: .radians(angle * 0.8))
            file.scaleBy(x: placement.scale, y: placement.scale)
            file.draw(symbol, at: .zero, anchor: .center)
        }
    }

    private func drawRim(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let r = radius * 0.98
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .linearGradient(
                Gradient(colors: [palette.foam, palette.shallow.opacity(0.55), palette.foam.opacity(0.7)]),
                startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
                endPoint: CGPoint(x: center.x + radius, y: center.y + radius)),
            lineWidth: radius * 0.07)
    }
}

private func polar(_ center: CGPoint, _ r: CGFloat, _ angle: Double) -> CGPoint {
    CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
}

/// Overshoots a little before settling, for a springy pop-in.
private func easeOutBack(_ x: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}
