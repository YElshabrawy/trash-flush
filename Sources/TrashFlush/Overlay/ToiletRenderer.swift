import SwiftUI
import TrashFlushCore

/// Draws one frame of the flush into a Canvas `GraphicsContext`: a toilet
/// beside the Dock's Trash, files arcing into it, and the swirl that takes
/// them away.
///
/// A plain struct rather than View methods: it holds only values, so the
/// Canvas can call it without touching any main-actor state.
struct ToiletRenderer {
    let palette: ThemePalette
    let scene: FlushScene
    let fileCount: Int
    let reduceMotion: Bool

    /// Half-size of the water surface when the bowl is full, in toilet points.
    private static let water = CGSize(width: 38, height: 13.5)
    /// Files shrink as they drop in, so a dozen of them fit on the water.
    private static let floatingScale = 0.7

    func draw(in context: inout GraphicsContext, time t: Double) {
        drawTrashGlow(in: &context, t: t)

        let rise = reduceMotion ? 1 : spring(FlushTimeline.appear(t))
        let exit = FlushTimeline.exit(t)
        let fadeIn = reduceMotion ? min(1, t / 0.3) : min(1, FlushTimeline.appear(t) * 2.5)

        // Toilet coordinates: origin at the middle of its base, y pointing down.
        var toilet = context
        toilet.opacity = fadeIn * (1 - exit)
        let drop = reduceMotion ? 0 : 28 * (1 - rise) + 36 * exit * exit
        let scale = reduceMotion ? 1 : 0.55 + 0.45 * rise - 0.3 * exit * exit
        toilet.translateBy(x: scene.toiletBase.x, y: scene.toiletBase.y + drop)
        toilet.rotate(by: .radians(shake(t)))
        toilet.scaleBy(x: scale, y: scale)

        drawToilet(in: &toilet, t: t)

        if !reduceMotion {
            drawFlyingFiles(in: &context, t: t)
        }
    }

    // MARK: Toilet

    private func drawToilet(in context: inout GraphicsContext, t: Double) {
        let bowlY = -Double(FlushScene.bowlHeight)

        context.fill(ellipse(CGPoint(x: 0, y: 0), 44, 8),
                     with: .radialGradient(Gradient(colors: [.black.opacity(0.35), .clear]),
                                           center: .zero, startRadius: 0, endRadius: 44))

        let tank = Path(roundedRect: CGRect(x: -40, y: -148, width: 80, height: 52), cornerRadius: 9)
        fillPorcelain(tank, in: &context)
        let tankLid = Path(roundedRect: CGRect(x: -44, y: -154, width: 88, height: 10), cornerRadius: 4)
        fillPorcelain(tankLid, in: &context)
        drawHandle(in: &context, press: FlushTimeline.handle(t))

        var body = Path()
        body.move(to: CGPoint(x: -49, y: bowlY))
        body.addQuadCurve(to: CGPoint(x: -20, y: -30), control: CGPoint(x: -48, y: -42))
        body.addLine(to: CGPoint(x: -18, y: -6))
        body.addQuadCurve(to: CGPoint(x: -28, y: 0), control: CGPoint(x: -18, y: 0))
        body.addLine(to: CGPoint(x: 28, y: 0))
        body.addQuadCurve(to: CGPoint(x: 18, y: -6), control: CGPoint(x: 18, y: 0))
        body.addLine(to: CGPoint(x: 20, y: -30))
        body.addQuadCurve(to: CGPoint(x: 49, y: bowlY), control: CGPoint(x: 48, y: -42))
        body.closeSubpath()
        fillPorcelain(body, in: &context)

        let rimCenter = CGPoint(x: 0, y: bowlY)
        context.fill(ellipse(CGPoint(x: 0, y: bowlY + 3), 50, 19), with: .color(Color(white: 0.78)))
        fillPorcelain(ellipse(rimCenter, 50, 19), in: &context)

        drawWater(in: &context, center: rimCenter, t: t)
    }

    private func fillPorcelain(_ path: Path, in context: inout GraphicsContext) {
        context.fill(path, with: .linearGradient(
            Gradient(colors: [.white, Color(white: 0.96), Color(red: 0.80, green: 0.84, blue: 0.90)]),
            startPoint: CGPoint(x: -50, y: -150), endPoint: CGPoint(x: 55, y: 0)))
        context.stroke(path, with: .color(Color(red: 0.52, green: 0.57, blue: 0.66).opacity(0.65)), lineWidth: 1.2)
    }

    /// A chrome lever on the front of the tank that tips down when pressed.
    private func drawHandle(in context: inout GraphicsContext, press: Double) {
        var lever = context
        lever.translateBy(x: -28, y: -132)
        lever.rotate(by: .radians(0.55 * press))
        let chrome = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(white: 0.95), Color(white: 0.62)]),
            startPoint: CGPoint(x: 0, y: -3), endPoint: CGPoint(x: 0, y: 3))
        lever.fill(Path(roundedRect: CGRect(x: -2, y: -2.5, width: 20, height: 5), cornerRadius: 2.5), with: chrome)
        lever.fill(ellipse(.zero, 4.5, 4.5), with: chrome)
        lever.stroke(ellipse(.zero, 4.5, 4.5), with: .color(Color(white: 0.5)), lineWidth: 0.8)
    }

    // MARK: Water

    private func drawWater(in context: inout GraphicsContext, center: CGPoint, t: Double) {
        let opening = ellipse(center, 40, 15)
        var bowl = context
        bowl.clip(to: opening)
        bowl.fill(opening, with: .linearGradient(
            Gradient(colors: [Color(white: 0.55), Color(white: 0.88)]),
            startPoint: CGPoint(x: center.x, y: center.y - 15), endPoint: CGPoint(x: center.x, y: center.y + 15)))

        let level = FlushTimeline.waterLevel(t)
        let swirl = reduceMotion ? 0 : FlushTimeline.swirl(t)
        let spin = reduceMotion ? 0 : FlushTimeline.spin(t)
        let surfaceCenter = CGPoint(x: center.x, y: center.y + 4 * (1 - level))

        // Inside `surface`, the water is a unit circle; the transform squashes
        // it into the ellipse you see in perspective.
        var surface = bowl
        surface.translateBy(x: surfaceCenter.x, y: surfaceCenter.y)
        surface.scaleBy(x: Self.water.width * level, y: Self.water.height * level)
        let disc = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))
        surface.fill(disc, with: .radialGradient(
            Gradient(stops: [
                .init(color: palette.deep, location: 0),
                .init(color: palette.water, location: 0.35 + 0.3 * swirl),
                .init(color: palette.shallow, location: 1),
            ]), center: .zero, startRadius: 0, endRadius: 1))
        surface.clip(to: disc)
        drawArms(in: &surface, count: 4, phase: spin, halfWidth: 0.09,
                 color: palette.foam.opacity(0.12 + 0.3 * swirl))
        drawArms(in: &surface, count: 6, phase: spin * 1.35 + 0.4, halfWidth: 0.035,
                 color: palette.shallow.opacity(0.1 + 0.2 * swirl))
        drawFoam(in: &surface, spin: spin, swirl: swirl)
        drawDrain(in: &surface, swirl: swirl)

        if !reduceMotion {
            drawRipples(in: &bowl, at: surfaceCenter, level: level, t: t)
            drawFloatingFiles(in: &context, at: surfaceCenter, level: level, t: t)
            drawDroplets(in: &context, at: surfaceCenter, t: t)
        }
    }

    /// Tapered spiral ribbons in unit-circle space. Each arm has a constant
    /// angular width, so it gets thinner on its own as it winds toward the drain.
    private func drawArms(in context: inout GraphicsContext, count: Int, phase: Double,
                          halfWidth: Double, color: Color) {
        let steps = 32
        for arm in 0..<count {
            let armPhase = phase + Double(arm) * 2 * .pi / Double(count)
            var leftEdge: [CGPoint] = []
            var rightEdge: [CGPoint] = []
            for step in 0...steps {
                let point = Vortex.armPoint(u: Double(step) / Double(steps), phase: armPhase)
                leftEdge.append(polar(.zero, point.radius, point.angle - halfWidth))
                rightEdge.append(polar(.zero, point.radius, point.angle + halfWidth))
            }
            var path = Path()
            path.addLines(leftEdge + rightEdge.reversed())
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
    }

    /// Foam bubbles orbiting the drain, faster the closer they are.
    private func drawFoam(in context: inout GraphicsContext, spin: Double, swirl: Double) {
        for i in 0..<22 {
            let seed = Double(i)
            let orbit = (0.2 + 0.75 * (seed * 0.618_034).truncatingRemainder(dividingBy: 1)) * (1 - 0.4 * swirl)
            let angle = Vortex.startAngle(for: i) + spin * 0.55 / max(orbit, 0.2)
            let size = 0.04 + 0.05 * (seed * 0.371).truncatingRemainder(dividingBy: 1)
            let p = polar(.zero, orbit, angle)
            context.fill(ellipse(p, size, size), with: .color(palette.foam.opacity(0.5)))
        }
    }

    private func drawDrain(in context: inout GraphicsContext, swirl: Double) {
        let hole = 0.05 + 0.13 * swirl
        let glow = hole * 2.4
        context.fill(ellipse(.zero, glow, glow), with: .radialGradient(Gradient(stops: [
            .init(color: .black.opacity(0.9), location: 0),
            .init(color: .black.opacity(0.85), location: hole / glow),
            .init(color: palette.deep.opacity(0), location: 1),
        ]), center: .zero, startRadius: 0, endRadius: glow))
    }

    // MARK: Files

    /// Where file `index` lands, as a fraction of the water's radius and an angle.
    private func landing(_ index: Int) -> (radius: Double, angle: Double) {
        (0.2 + 0.45 * (Double(index) * 0.618_034).truncatingRemainder(dividingBy: 1), Vortex.startAngle(for: index))
    }

    private func landingTime(_ index: Int) -> Double {
        FlushTimeline.flightStart(index: index, count: fileCount) + FlushTimeline.flightDuration
    }

    private func onSurface(_ center: CGPoint, radius: Double, angle: Double, level: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle) * Self.water.width * level,
                y: center.y + radius * sin(angle) * Self.water.height * level)
    }

    /// Files arc out of the Trash and drop into the bowl, tumbling and leaving
    /// a faint trail. Their icons are Canvas symbols tagged 0..<fileCount.
    private func drawFlyingFiles(in context: inout GraphicsContext, t: Double) {
        let from = Flight.Point(x: scene.trash.x, y: scene.trash.y)
        let control = Flight.Point(x: scene.flightControl.x, y: scene.flightControl.y)
        for index in 0..<fileCount {
            let progress = FlushTimeline.flightProgress(index: index, count: fileCount, at: t)
            guard progress > 0, progress < 1, let symbol = context.resolveSymbol(id: index) else { continue }

            let spot = landing(index)
            let target = onSurface(scene.bowlCenter, radius: spot.radius, angle: spot.angle, level: 1)
            let to = Flight.Point(x: target.x, y: target.y)
            let direction: Double = index.isMultiple(of: 2) ? 1 : -1

            for trail in stride(from: 3, through: 0, by: -1) {
                let p = progress - Double(trail) * 0.035
                guard p > 0 else { continue }
                let position = Flight.position(progress: p, from: from, control: control, to: to)
                var file = context
                file.opacity = min(1, p / 0.1) * (trail == 0 ? 1 : 0.22 / Double(trail))
                file.translateBy(x: position.x, y: position.y)
                file.rotate(by: .radians(direction * 1.6 * .pi * (1 - p)))
                let scale = Flight.scale(progress: p) * (1 - (1 - Self.floatingScale) * p)
                file.scaleBy(x: scale, y: scale)
                file.draw(symbol, at: .zero, anchor: .center)
            }
        }
    }

    /// Landed files bob on the water, then spiral down the drain after the flush.
    private func drawFloatingFiles(in context: inout GraphicsContext, at center: CGPoint, level: Double, t: Double) {
        for index in 0..<fileCount {
            let landed = landingTime(index)
            guard t >= landed, let symbol = context.resolveSymbol(id: index) else { continue }

            let spot = landing(index)
            let sink = FlushTimeline.sinkProgress(index: index, count: fileCount, at: t)
            let placement = Vortex.particle(progress: sink, startAngle: spot.angle, startRadius: spot.radius)
            guard placement.opacity > 0 else { continue }

            let drift = 0.3 * (t - landed)
            let position = onSurface(center, radius: placement.radius, angle: placement.angle + drift, level: level)
            let bob = (1 - sink) * sin((t - landed) * 6 + Double(index)) * 1.2 * exp(-(t - landed) * 1.5)
            var file = context
            file.opacity *= placement.opacity
            file.translateBy(x: position.x, y: position.y + bob)
            file.rotate(by: .radians(0.15 * sin(t * 2.2 + Double(index)) + 1.4 * (placement.angle - spot.angle)))
            file.scaleBy(x: placement.scale * Self.floatingScale, y: placement.scale * Self.floatingScale)
            file.draw(symbol, at: .zero, anchor: .center)
        }
    }

    /// An expanding ring where each file hits the water.
    private func drawRipples(in context: inout GraphicsContext, at center: CGPoint, level: Double, t: Double) {
        for index in 0..<fileCount {
            let age = (t - landingTime(index)) / 0.55
            guard age > 0, age < 1 else { continue }
            let spot = landing(index)
            let p = onSurface(center, radius: spot.radius, angle: spot.angle, level: level)
            let r = 4 + 20 * (1 - pow(1 - age, 3))
            context.stroke(ellipse(p, r, r * 0.36), with: .color(palette.foam.opacity(0.8 * (1 - age))),
                           lineWidth: 1.5 * (1 - age) + 0.3)
        }
    }

    /// A few drops thrown up by each splash, falling back under gravity.
    private func drawDroplets(in context: inout GraphicsContext, at center: CGPoint, t: Double) {
        for index in 0..<fileCount {
            let age = t - landingTime(index)
            guard age > 0, age < 0.2 else { continue }
            let spot = landing(index)
            let origin = onSurface(center, radius: spot.radius, angle: spot.angle, level: 1)
            for drop in 0..<4 {
                let side = Double(drop) - 1.5
                let launch = 95 - abs(side) * 15
                // Gone once it falls back to the water.
                let lifetime = 2 * launch / 520
                guard age < lifetime else { continue }
                let x = origin.x + side * 16 * age
                let y = origin.y - launch * age + 520 * age * age
                let size = 1.8 - 0.3 * abs(side)
                context.fill(ellipse(CGPoint(x: x, y: y), size, size),
                             with: .color(palette.shallow.opacity(1 - age / lifetime)))
            }
        }
    }

    // MARK: Extras

    /// A soft glow on the Dock's Trash while files are coming out of it.
    private func drawTrashGlow(in context: inout GraphicsContext, t: Double) {
        guard fileCount > 0, !reduceMotion else { return }
        let lastStart = FlushTimeline.flightStart(index: fileCount - 1, count: fileCount)
        let strength = smoothstep(0.25, 0.5, t) * (1 - smoothstep(lastStart + 0.1, lastStart + 0.45, t))
        guard strength > 0 else { return }
        let r: CGFloat = 38
        context.fill(ellipse(scene.trash, r, r), with: .radialGradient(
            Gradient(colors: [palette.shallow.opacity(0.45 * strength), .clear]),
            center: scene.trash, startRadius: 0, endRadius: r))
    }

    /// The toilet rocks a little when the handle is pressed.
    private func shake(_ t: Double) -> Double {
        let s = t - FlushTimeline.flushStart
        guard s > 0, !reduceMotion else { return 0 }
        return 0.035 * sin(22 * s) * exp(-5 * s)
    }
}

private func ellipse(_ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2))
}

private func polar(_ center: CGPoint, _ r: CGFloat, _ angle: Double) -> CGPoint {
    CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
}

/// A damped spring from 0 to 1 with a small overshoot.
private func spring(_ x: Double) -> Double {
    x >= 1 ? 1 : 1 - exp(-6 * x) * cos(2.4 * .pi * x)
}

private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let u = min(max((x - a) / (b - a), 0), 1)
    return u * u * (3 - 2 * u)
}
