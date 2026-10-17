import SwiftUI
import TrashFlushCore

/// The toilet flush: Apple's 🚽 pops up next to the Dock's Trash, your files
/// arc into the bowl, water splashes out as it flushes,
/// and the toilet shrinks away, leaving a receipt.
///
/// Like the notch, it's one `TimelineView(.animation)` and a Metal-backed
/// `Canvas`, driven by a timeline that is a pure function of time.
struct ToiletFlushView: View {
    let event: FlushEvent
    /// One per name in `event.sampleNames`.
    let icons: [FileIconCache.Icon]
    let scene: NotchScene
    let timeline: ToiletTimeline
    let start: Date
    /// Where the Dock's Trash is right now, when it's on screen.
    let tracker: TrashTracker?
    private let trashFull: NSImage
    private let trashEmpty: NSImage

    @State private var showsConfetti = false
    init(event: FlushEvent, icons: [FileIconCache.Icon], scene: NotchScene, timeline: ToiletTimeline, start: Date,
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
        let renderer = ToiletRenderer(scene: scene, timeline: timeline, iconCount: icons.count)

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let state = ToiletMotion.state(at: t, timeline: timeline)
            let dockTrash = tracker?.center ?? scene.trash
            let pose = renderer.pose(state: state, dockTrash: dockTrash)
            let receipt = renderer.receiptCenter(dockTrash: dockTrash)
            ZStack(alignment: .topLeading) {
                Canvas { canvas, _ in
                    renderer.draw(in: &canvas, time: t, state: state, pose: pose, dockTrash: dockTrash)
                } symbols: {
                    ForEach(icons.indices, id: \.self) { index in
                        FileIconView(icon: icons[index]).tag(index)
                    }
                    trashImage(trashFull).tag(Symbol.trashFull)
                    trashImage(trashEmpty).tag(Symbol.trashEmpty)
                    Image(nsImage: ToiletRenderer.art)
                        .resizable()
                        .frame(width: renderer.toiletSize, height: renderer.toiletSize)
                        .tag(Symbol.toilet)
                }
                .drawingGroup()

                if showsConfetti {
                    ConfettiView()
                        .frame(width: 640, height: 574)
                        .position(receipt)
                }

                ReceiptCard(event: event, icons: icons, verb: "Flushed", opacity: state.receiptOpacity)
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

/// Where the toilet is drawn this frame, and where its bowl is.
struct ToiletPose {
    /// The middle of its base, where it stands.
    var base: CGPoint
    var scaleX: CGFloat
    var scaleY: CGFloat
    /// The opening of the bowl, where files drop in and water splashes out.
    var bowl: CGPoint
}

/// Draws the toilet, the files flying into it and the splashes for one frame.
private struct ToiletRenderer {
    let scene: NotchScene
    let timeline: ToiletTimeline
    let iconCount: Int

    /// Apple's 🚽, trimmed to its drawing. It fills its square, bowl on the left.
    static let art = emojiArt("🚽")
    /// The seat's opening, as a fraction of the emoji from its top left.
    private static let seat = CGPoint(x: 0.34, y: 0.45)
    /// Past this far into its flight, a file is dropping into the bowl and goes behind the toilet.
    private static let dropsIn = 0.86

    var toiletSize: CGFloat { scene.trashIconSize * 2.6 }

    /// +1 when the Trash is to the right of the toilet, so the bowl turns to face it.
    private var side: CGFloat {
        if scene.away.dx > 0.5 { return -1 }
        if scene.away.dx < -0.5 { return 1 }
        return scene.trash.x > scene.size.width / 2 ? 1 : -1
    }

    private func base(dockTrash: CGPoint) -> CGPoint {
        let trash = scene.peeksTrash ? scene.trash : dockTrash
        let icon = scene.trashIconSize, size = toiletSize
        if abs(scene.away.dx) > 0.5 {
            // On a side Dock it stands beside the Trash.
            return CGPoint(x: trash.x + scene.away.dx * (icon / 2 + size * 0.5 + 6), y: trash.y + icon / 2)
        }
        // Over a bottom Dock it stands on the Dock's edge, its bowl leaning over the Trash.
        return CGPoint(x: trash.x - side * size * 0.42, y: trash.y - icon * 0.64 - 2)
    }

    func pose(state: ToiletState, dockTrash: CGPoint) -> ToiletPose {
        let base = base(dockTrash: dockTrash), size = toiletSize
        let squash = CGFloat(state.squash) * 0.12
        let scaleX = CGFloat(state.size) * (1 + squash), scaleY = CGFloat(state.size) * (1 - squash)
        let seatX = (side > 0 ? 1 - Self.seat.x : Self.seat.x) - 0.5
        let bowl = CGPoint(x: base.x + CGFloat(state.rumble) + seatX * size * scaleX,
                           y: base.y - (1 - Self.seat.y) * size * scaleY)
        return ToiletPose(base: CGPoint(x: base.x + CGFloat(state.rumble), y: base.y), scaleX: scaleX, scaleY: scaleY,
                          bowl: bowl)
    }

    func draw(in context: inout GraphicsContext, time t: Double, state: ToiletState, pose: ToiletPose,
              dockTrash: CGPoint) {
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

        let start = thrower.rim(of: scene.peeksTrash ? scene.trash : dockTrash)
        if iconCount > 0 {
            drawFlights(in: &files, time: t, from: start, to: pose.bowl, droppingIn: true)
        }
        drawToilet(in: &context, pose: pose)
        if iconCount > 0 {
            drawFlights(in: &files, time: t, from: start, to: pose.bowl, droppingIn: false)
        }
        drawSplashes(in: &context, time: t, pose: pose)
    }

    /// Above the toilet, kept on the screen.
    func receiptCenter(dockTrash: CGPoint) -> CGPoint {
        let base = base(dockTrash: dockTrash)
        return ReceiptCard.clamped(CGPoint(x: base.x, y: base.y - toiletSize - ReceiptCard.size.height / 2 - 16),
                                   in: scene.size)
    }

    private func drawToilet(in context: inout GraphicsContext, pose: ToiletPose) {
        guard pose.scaleY > 0.01, let toilet = context.resolveSymbol(id: Symbol.toilet) else { return }
        var drawn = context
        drawn.translateBy(x: pose.base.x, y: pose.base.y)
        drawn.scaleBy(x: pose.scaleX * -side, y: pose.scaleY)
        drawn.draw(toilet, at: CGPoint(x: 0, y: -toiletSize / 2), anchor: .center)
    }

    /// Each file arcs up out of the Trash and drops into the bowl.
    private func drawFlights(in context: inout GraphicsContext, time t: Double, from start: CGPoint, to bowl: CGPoint,
                             droppingIn: Bool) {
        for flight in timeline.flights where flight.start <= t && t < flight.arrival {
            let u = flight.progress(at: t)
            guard (u >= Self.dropsIn) == droppingIn,
                  let icon = context.resolveSymbol(id: flight.index % iconCount) else { continue }
            let wobble = Double((flight.index * 37) % 11) / 10 - 0.5
            let lift = (300 + 60 * wobble) * scene.trashIconSize / 56 * (flight.isMini ? 0.8 : 1)
            // The control point sits over the bowl, so files come down into it from above.
            let control = CGPoint(x: bowl.x + (bowl.x - start.x) * 0.15 + 14 * wobble, y: min(start.y, bowl.y) - lift)
            let landing = CGPoint(x: bowl.x + 10 * wobble, y: bowl.y + 10)
            let here = FlightPath.position(progress: u, from: FlightPath.Point(x: start.x, y: start.y),
                                           control: FlightPath.Point(x: control.x, y: control.y),
                                           to: FlightPath.Point(x: landing.x, y: landing.y))
            var file = context
            file.translateBy(x: here.x, y: here.y)
            file.rotate(by: .degrees(FlightPath.spin(index: flight.index, progress: u) * 2))
            let size = FlightPath.scale(progress: u, isMini: flight.isMini) * 0.65
            file.scaleBy(x: size, y: size)
            file.draw(icon, at: .zero, anchor: .center)
        }
    }

    /// Drops of water jumping out of the bowl as it flushes.
    private func drawSplashes(in context: inout GraphicsContext, time t: Double, pose: ToiletPose) {
        let life = 0.7, scale = scene.trashIconSize / 56
        let water = Color(red: 0.42, green: 0.74, blue: 1)
        for drop in 0..<16 {
            let born = timeline.flush + Double(drop % 8) * 0.07 + Double(drop / 8) * 0.35
            let age = t - born
            guard age >= 0, age < life else { continue }
            let sideways = (Double((drop * 5) % 9) / 8 - 0.5) * 260 * scale
            let speed = (230 + Double((drop * 7) % 5) * 35) * scale
            let rise = speed * age - 0.5 * 1100 * scale * age * age
            let point = CGPoint(x: pose.bowl.x + sideways * age, y: pose.bowl.y - rise)
            let r = (4.5 + Double(drop % 3)) * scale * (1 - 0.5 * age / life)
            let fade = 1 - pow(age / life, 2)
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r * 1.25, width: r * 2, height: r * 2.5)),
                         with: .color(water.opacity(fade)))
            context.fill(Path(ellipseIn: CGRect(x: point.x - r * 0.45, y: point.y - r * 0.8, width: r * 0.6, height: r * 0.8)),
                         with: .color(.white.opacity(0.8 * fade)))
        }
    }

    /// An emoji drawn large from the system's emoji font, so it's Apple's own art.
    /// The font's metrics don't match the bitmap glyph, so draw it with room to
    /// spare and trim to the pixels it actually covers.
    private static func emojiArt(_ emoji: String) -> NSImage {
        let fontSize: CGFloat = 320, side = Int(fontSize * 1.5)
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return NSImage() }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let font = NSFont(name: "Apple Color Emoji", size: fontSize) ?? .systemFont(ofSize: fontSize)
        NSAttributedString(string: emoji, attributes: [.font: font]).draw(at: NSPoint(x: fontSize / 8, y: fontSize / 4))
        NSGraphicsContext.restoreGraphicsState()

        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self), let full = context.makeImage()
        else { return NSImage() }
        var minX = side, minY = side, maxX = -1, maxY = -1
        for y in 0..<side {
            for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 12 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, let trimmed = full.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1,
                                                                   height: maxY - minY + 1))
        else { return NSImage() }
        return NSImage(cgImage: trimmed, size: NSSize(width: trimmed.width, height: trimmed.height))
    }
}
