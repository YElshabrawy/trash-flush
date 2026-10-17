import SwiftUI
import TrashFlushCore

/// The garbage truck pickup: a truck drives along the Dock, brakes by the
/// Trash, takes your files, chomps them and drives off, leaving a receipt.
///
/// Like the notch, it's one `TimelineView(.animation)` and a Metal-backed
/// `Canvas`, driven by a timeline that is a pure function of time.
struct TruckFlushView: View {
    let event: FlushEvent
    /// One per name in `event.sampleNames`.
    let icons: [FileIconCache.Icon]
    let scene: NotchScene
    let timeline: TruckTimeline
    let start: Date
    /// Where the Dock's Trash is right now, when it's on screen.
    let tracker: TrashTracker?
    private let trashFull: NSImage
    private let trashEmpty: NSImage

    @State private var showsConfetti = false

    init(event: FlushEvent, icons: [FileIconCache.Icon], scene: NotchScene, timeline: TruckTimeline, start: Date,
         tracker: TrashTracker?) {
        self.event = event
        self.icons = icons
        self.scene = scene
        self.timeline = timeline
        self.start = start
        self.tracker = tracker
        trashFull = .dockTrash(NSImage.trashFullName, size: scene.trashIconSize)
        trashEmpty = .dockTrash(NSImage.trashEmptyName, size: scene.trashIconSize)
    }

    var body: some View {
        let renderer = TruckRenderer(scene: scene, timeline: timeline, iconCount: icons.count)

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let state = TruckMotion.state(at: t, timeline: timeline)
            let dockTrash = tracker?.center ?? scene.trash
            let receipt = renderer.receiptCenter(dockTrash: dockTrash)
            ZStack(alignment: .topLeading) {
                Canvas { canvas, _ in
                    renderer.draw(in: &canvas, time: t, state: state, dockTrash: dockTrash)
                } symbols: {
                    ForEach(icons.indices, id: \.self) { index in
                        FileIconView(icon: icons[index]).tag(index)
                    }
                    trashImage(trashFull).tag(Symbol.trashFull)
                    trashImage(trashEmpty).tag(Symbol.trashEmpty)
                    Image(systemName: "arrow.3.trianglepath")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .tag(Symbol.recycle)
                }
                .drawingGroup()

                if showsConfetti {
                    ConfettiView()
                        .frame(width: 640, height: 574)
                        .position(receipt)
                }

                IslandContent(event: event, icons: Array(icons.prefix(3)), verb: "Picked up")
                    .environment(\.colorScheme, .dark)
                    .padding(.horizontal, 20)
                    .frame(width: TruckRenderer.receiptSize.width, height: TruckRenderer.receiptSize.height)
                    .background(.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                    .scaleEffect(0.85 + 0.15 * state.receiptOpacity)
                    .blur(radius: (1 - state.receiptOpacity) * 5)
                    .opacity(state.receiptOpacity)
                    .position(receipt)
            }
            .frame(width: scene.size.width, height: scene.size.height)
        }
        .allowsHitTesting(false)
        .task {
            guard !timeline.reduceMotion else { return }
            try? await Task.sleep(for: .seconds(timeline.receiptStart))
            showsConfetti = !Task.isCancelled
        }
    }

    private func trashImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: scene.trashIconSize, height: scene.trashIconSize)
    }
}

/// Draws the truck, the files hopping into it and its exhaust for one frame.
///
/// The truck is drawn in its own coordinates, at its size for a 56 pt Dock
/// icon: x points forward, y down, and the road (the Dock's edge) is y = 0.
private struct TruckRenderer {
    let scene: NotchScene
    let timeline: TruckTimeline
    let iconCount: Int

    static let receiptSize = CGSize(width: 300, height: 64)
    /// From the rear door to the bumper, and from the road to the roof.
    private static let length: CGFloat = 190
    private static let height: CGFloat = 100
    private static let hopperMouth = CGPoint(x: -90, y: -70)
    /// Past this far into a hop, a file is dropping into the hopper and goes behind the truck.
    private static let dropsIn = 0.62
    private static let exhaust = CGPoint(x: 24.5, y: -98)
    private static let wheelRadius: CGFloat = 12

    private var scale: CGFloat { min(max(scene.trashIconSize / 48, 0.85), 1.5) }
    /// Along the Dock, turned a quarter from `away`, so the truck stays upright
    /// relative to the Dock on every edge.
    private var along: CGVector { CGVector(dx: -scene.away.dy, dy: scene.away.dx) }
    /// +1 or -1 along `along`: in from the end of the Dock nearest the Trash,
    /// out by the other.
    private var direction: CGFloat {
        edgeDistance(from: scene.trash, toward: along) < edgeDistance(from: scene.trash, toward: -along) ? -1 : 1
    }
    private var travel: CGVector { along * direction }

    private struct Pose {
        var center: CGPoint
        var wheelTurn: Double
        var sag: CGFloat
    }

    func draw(in context: inout GraphicsContext, time t: Double, state: TruckState, dockTrash: CGPoint) {
        let thrower = TrashThrow(scene: scene, iconCount: iconCount)
        let trash = scene.peeksTrash ? scene.standIn(offset: state.trashOffset) : dockTrash

        var files = context
        thrower.maskInside(&files, trash: trash)
        thrower.drawEmerging(timeline.flights, in: &files, trash: trash, time: t)
        if scene.peeksTrash, state.trashOffset < 0.999 {
            let emptied = timeline.flights.last.map { t >= $0.start } ?? true
            thrower.drawStandIn(in: &context, at: trash, emptied: emptied, puff: state.trashPuff)
        }
        guard !timeline.reduceMotion else { return }

        let pose = pose(at: t, sag: state.sag, dockTrash: dockTrash)
        let start = thrower.rim(of: scene.peeksTrash ? scene.trash : dockTrash)
        let mouth = world(Self.hopperMouth, pose: pose)
        if iconCount > 0 {
            drawFlights(in: &files, time: t, from: start, to: mouth, droppingIn: true)
        }

        drawExhaust(in: &context, time: t, dockTrash: dockTrash)
        var truck = context
        truck.translateBy(x: pose.center.x, y: pose.center.y)
        truck.rotate(by: .radians(atan2(along.dy, along.dx)))
        truck.scaleBy(x: direction * scale, y: scale)
        drawTruck(in: &truck, state: state, wheelTurn: pose.wheelTurn)

        if iconCount > 0 {
            drawFlights(in: &files, time: t, from: start, to: mouth, droppingIn: false)
        }
    }

    /// Above the truck's roof over the Trash, kept on the screen.
    func receiptCenter(dockTrash: CGPoint) -> CGPoint {
        let size = Self.receiptSize
        let lift = Self.height * scale + size.height / 2 + 18
        let point = road(under: dockTrash) + scene.away * lift
        return CGPoint(x: min(max(point.x, size.width / 2 + 12), scene.size.width - size.width / 2 - 12),
                       y: min(max(point.y, size.height / 2 + 12), scene.size.height - size.height / 2 - 12))
    }

    // MARK: Where the truck is

    /// Where the truck's wheels meet the Dock, under the Trash.
    private func road(under trash: CGPoint) -> CGPoint {
        trash + scene.away * (scene.trashIconSize * 0.64 + 2)
    }

    private func pose(at t: Double, sag: Double, dockTrash: CGPoint) -> Pose {
        // Stops just past the Trash, so the files rise behind the truck and arc over into the hopper.
        let stop = road(under: scene.peeksTrash ? scene.trash : dockTrash) - travel * ((Self.hopperMouth.x - 30) * scale)
        let margin = Self.length * scale / 2 + 30
        let entry = edgeDistance(from: stop, toward: -travel) + margin
        let exit = edgeDistance(from: stop, toward: travel) + margin
        let approach = timeline.approach(at: t), departure = timeline.departure(at: t)
        let center = stop - travel * (entry * (1 - approach)) + travel * (exit * departure)
        let traveled = entry * approach + exit * departure
        return Pose(center: center, wheelTurn: traveled / (Self.wheelRadius * scale), sag: sag)
    }

    /// A point on the truck (in its own coordinates) on the screen.
    private func world(_ local: CGPoint, pose: Pose) -> CGPoint {
        pose.center + travel * (local.x * scale) - scene.away * ((local.y + pose.sag) * scale)
    }

    private func edgeDistance(from p: CGPoint, toward v: CGVector) -> CGFloat {
        if v.dx > 0.5 { return scene.size.width - p.x }
        if v.dx < -0.5 { return p.x }
        if v.dy > 0.5 { return scene.size.height - p.y }
        return p.y
    }

    // MARK: Files and exhaust

    /// Each file hops up out of the Trash and drops into the hopper.
    private func drawFlights(in context: inout GraphicsContext, time t: Double, from start: CGPoint, to mouth: CGPoint,
                             droppingIn: Bool) {
        for flight in timeline.flights where flight.start <= t && t < flight.arrival {
            let u = flight.progress(at: t)
            guard (u >= Self.dropsIn) == droppingIn,
                  let icon = context.resolveSymbol(id: flight.index % iconCount) else { continue }
            let wobble = Double((flight.index * 37) % 11) / 10 - 0.5
            let mid = CGPoint(x: (start.x + mouth.x) / 2, y: (start.y + mouth.y) / 2)
            let control = mid + scene.away * ((150 + 40 * wobble) * scale * (flight.isMini ? 0.8 : 1))
                - travel * ((12 + 20 * wobble) * scale)
            let here = FlightPath.position(progress: u, from: point(start), control: point(control), to: point(mouth))
            var file = context
            file.translateBy(x: here.x, y: here.y)
            file.rotate(by: .degrees(FlightPath.spin(index: flight.index, progress: u)))
            let size = FlightPath.scale(progress: u, isMini: flight.isMini) * 0.75
            file.scaleBy(x: size, y: size)
            file.draw(icon, at: .zero, anchor: .center)
        }
    }

    /// A few soft puffs from the exhaust stack as the truck pulls away. Each one
    /// stays where it left the stack, swelling, drifting up and fading.
    private func drawExhaust(in context: inout GraphicsContext, time t: Double, dockTrash: CGPoint) {
        let life = 0.7
        for i in 0..<5 {
            let born = timeline.depart - 0.04 + Double(i) * 0.08
            let age = t - born
            guard age >= 0, age < life else { continue }
            let origin = world(Self.exhaust, pose: pose(at: born, sag: 0, dockTrash: dockTrash))
            let wobble = Double((i * 29) % 7) / 7 - 0.5
            let center = origin + scene.away * ((10 + 34 * age) * scale) - travel * ((8 + 16 * wobble) * age * scale)
            let radius = (7 + 26 * sqrt(age)) * scale
            let fade = 0.5 * (1 - age / life)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [Color(white: 0.9).opacity(fade), Color(white: 0.9).opacity(0)]),
                                               center: center, startRadius: 0, endRadius: radius))
        }
    }

    // MARK: The truck

    private func drawTruck(in context: inout GraphicsContext, state: TruckState, wheelTurn: Double) {
        context.fill(Path(ellipseIn: CGRect(x: -100, y: -4, width: 192, height: 8)), with: .color(.black.opacity(0.22)))
        for x in [-50.0, 50.0] {
            drawWheel(in: &context, at: CGPoint(x: x, y: -Self.wheelRadius), turn: wheelTurn)
        }

        var body = context
        body.translateBy(x: 0, y: state.sag)
        body.translateBy(x: 0, y: -30)
        body.rotate(by: .degrees(state.pitch))
        body.translateBy(x: 0, y: 30)

        // Chassis and the fenders over the wheels.
        body.fill(Path(roundedRect: CGRect(x: -88, y: -31, width: 172, height: 10), cornerRadius: 3), with: .color(.chassis))
        for x in [-50.0, 50.0] {
            var fender = Path()
            fender.addArc(center: CGPoint(x: x, y: -Self.wheelRadius), radius: 15.5,
                          startAngle: .degrees(195), endAngle: .degrees(345), clockwise: false)
            body.stroke(fender, with: .color(.chassis), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        drawHopper(in: &body, chomp: state.chomp)

        // The container: ribbed green, with the recycling mark.
        let container = Path(roundedRect: CGRect(x: -80, y: -88, width: 104, height: 60), cornerRadius: 10, style: .continuous)
        body.fill(container, with: .linearGradient(Gradient(colors: [.truckGreen, .truckGreenDark]),
                                                   startPoint: CGPoint(x: 0, y: -88), endPoint: CGPoint(x: 0, y: -28)))
        for x in [-62.0, -44, 6] {
            var rib = Path()
            rib.move(to: CGPoint(x: x, y: -83))
            rib.addLine(to: CGPoint(x: x, y: -33))
            body.stroke(rib, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        body.fill(Path(roundedRect: CGRect(x: -74, y: -85, width: 92, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.22)))
        if let recycle = body.resolveSymbol(id: Symbol.recycle) {
            body.draw(recycle, at: CGPoint(x: -19, y: -58), anchor: .center)
        }

        // The exhaust stack, behind the cab.
        body.fill(Path(roundedRect: CGRect(x: 22, y: -98, width: 5, height: 26), cornerRadius: 2), with: .color(Color(white: 0.5)))

        drawCab(in: &body, beacon: state.beacon)
    }

    private func drawWheel(in context: inout GraphicsContext, at center: CGPoint, turn: Double) {
        func circle(_ r: CGFloat, at c: CGPoint = center) -> Path {
            Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        context.fill(circle(Self.wheelRadius), with: .color(Color(white: 0.12)))
        context.fill(circle(6.5), with: .color(Color(white: 0.78)))
        for i in 0..<4 {
            let angle = turn + Double(i) * .pi / 2
            context.fill(circle(1.1, at: CGPoint(x: center.x + 3.6 * cos(angle), y: center.y + 3.6 * sin(angle))),
                         with: .color(Color(white: 0.45)))
        }
        context.fill(circle(1.6), with: .color(Color(white: 0.45)))
    }

    /// The rear door swings back from its base to open the hopper, and shuts to chomp.
    private func drawHopper(in context: inout GraphicsContext, chomp: Double) {
        let pivot = CGPoint(x: -80, y: -29)
        let angle = -(1 - chomp) * 24 * .pi / 180
        let doorTop = CGPoint(x: pivot.x + 58 * sin(angle), y: pivot.y - 58 * cos(angle))

        var inside = Path()
        inside.move(to: pivot)
        inside.addLine(to: CGPoint(x: -76, y: -88))
        inside.addLine(to: doorTop)
        inside.closeSubpath()
        context.fill(inside, with: .color(Color(red: 0.05, green: 0.17, blue: 0.1)))

        var door = context
        door.translateBy(x: pivot.x, y: pivot.y)
        door.rotate(by: .radians(angle))
        let panel = Path(roundedRect: CGRect(x: -15, y: -58, width: 16, height: 58), cornerRadius: 5, style: .continuous)
        door.fill(panel, with: .color(.truckGreenDeep))
        for y in [-44.0, -30] {
            door.fill(Path(roundedRect: CGRect(x: -12, y: y, width: 10, height: 2.5), cornerRadius: 1),
                      with: .color(.white.opacity(0.18)))
        }
        door.fill(Path(roundedRect: CGRect(x: -13, y: -15, width: 5, height: 8), cornerRadius: 1.5),
                  with: .color(Color(red: 0.95, green: 0.25, blue: 0.2)))
    }

    private func drawCab(in context: inout GraphicsContext, beacon: Double) {
        let cab = roundedPolygon([CGPoint(x: 26, y: -27), CGPoint(x: 87, y: -27), CGPoint(x: 87, y: -48),
                                  CGPoint(x: 79, y: -76), CGPoint(x: 29, y: -76)], radius: 6)
        context.fill(cab, with: .linearGradient(Gradient(colors: [Color(white: 0.98), Color(white: 0.86)]),
                                                startPoint: CGPoint(x: 0, y: -76), endPoint: CGPoint(x: 0, y: -27)))

        let window = roundedPolygon([CGPoint(x: 39, y: -70), CGPoint(x: 75, y: -70),
                                     CGPoint(x: 81, y: -51), CGPoint(x: 39, y: -51)], radius: 3)
        context.fill(window, with: .linearGradient(Gradient(colors: [Color(red: 0.7, green: 0.88, blue: 0.98),
                                                                     Color(red: 0.42, green: 0.68, blue: 0.9)]),
                                                   startPoint: CGPoint(x: 0, y: -70), endPoint: CGPoint(x: 0, y: -51)))
        var glint = Path()
        glint.move(to: CGPoint(x: 62, y: -68))
        glint.addLine(to: CGPoint(x: 54, y: -53))
        context.stroke(glint, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        var seam = Path()
        seam.move(to: CGPoint(x: 35, y: -47))
        seam.addLine(to: CGPoint(x: 35, y: -30))
        context.stroke(seam, with: .color(Color(white: 0.7)), lineWidth: 1)
        context.fill(Path(roundedRect: CGRect(x: 38, y: -44, width: 7, height: 2.2), cornerRadius: 1), with: .color(Color(white: 0.6)))
        context.fill(Path(roundedRect: CGRect(x: 82, y: -41, width: 5.5, height: 6), cornerRadius: 1.5),
                     with: .color(Color(red: 1, green: 0.86, blue: 0.35)))
        context.fill(Path(roundedRect: CGRect(x: 80, y: -31, width: 10, height: 6), cornerRadius: 2), with: .color(.chassis))

        // The beacon on the roof, blinking while the truck is stopped.
        let glow = 14.0
        context.fill(Path(ellipseIn: CGRect(x: 56 - glow, y: -81 - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [.beacon.opacity(0.55 * beacon), .beacon.opacity(0)]),
                                           center: CGPoint(x: 56, y: -81), startRadius: 0, endRadius: glow))
        context.fill(Path(roundedRect: CGRect(x: 51, y: -79, width: 10, height: 3.5), cornerRadius: 1), with: .color(.chassis))
        context.fill(Path(roundedRect: CGRect(x: 52.5, y: -85, width: 7, height: 6.5), cornerRadius: 2.5),
                     with: .color(.beacon.opacity(0.6 + 0.4 * beacon)))
    }

    private func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        let last = points[points.count - 1], first = points[0]
        path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for i in points.indices {
            path.addArc(tangent1End: points[i], tangent2End: points[(i + 1) % points.count], radius: radius)
        }
        path.closeSubpath()
        return path
    }

    private func point(_ p: CGPoint) -> FlightPath.Point { FlightPath.Point(x: p.x, y: p.y) }
}

private extension Color {
    static let truckGreen = Color(red: 0.24, green: 0.7, blue: 0.43)
    static let truckGreenDark = Color(red: 0.15, green: 0.54, blue: 0.32)
    static let truckGreenDeep = Color(red: 0.11, green: 0.44, blue: 0.26)
    static let chassis = Color(red: 0.2, green: 0.22, blue: 0.25)
    static let beacon = Color(red: 1, green: 0.62, blue: 0.04)
}

private func + (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x + v.dx, y: p.y + v.dy) }
private func - (p: CGPoint, v: CGVector) -> CGPoint { CGPoint(x: p.x - v.dx, y: p.y - v.dy) }
private func * (v: CGVector, k: CGFloat) -> CGVector { CGVector(dx: v.dx * k, dy: v.dy * k) }
private prefix func - (v: CGVector) -> CGVector { CGVector(dx: -v.dx, dy: -v.dy) }
