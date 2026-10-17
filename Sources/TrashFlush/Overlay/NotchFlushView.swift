import SwiftUI
import TrashFlushCore

/// The flush: your files arc out of the Dock's Trash and the notch gulps them
/// down, then grows into an island that says how much you freed.
///
/// One `TimelineView(.animation)` drives it all in sync with the display. The
/// files are drawn in a `Canvas` (rendered with Metal through `drawingGroup()`),
/// underneath the black notch, so they vanish as they reach it.
struct NotchFlushView: View {
    let event: FlushEvent
    /// One per name in `event.sampleNames`.
    let icons: [FileIconCache.Icon]
    let scene: NotchScene
    let timeline: NotchTimeline
    let start: Date
    /// Where the Dock's Trash is right now, when it's on screen.
    let tracker: TrashTracker?
    private let trashFull: NSImage
    private let trashEmpty: NSImage

    @State private var showsConfetti = false

    init(event: FlushEvent, icons: [FileIconCache.Icon], scene: NotchScene, timeline: NotchTimeline, start: Date,
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
        let renderer = FlightRenderer(scene: scene, timeline: timeline, iconCount: icons.count)

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let state = NotchMotion.state(at: t, timeline: timeline, style: scene.style)
            let dockTrash = tracker?.center ?? scene.trash
            ZStack(alignment: .topLeading) {
                Canvas { canvas, _ in
                    renderer.draw(in: &canvas, time: t, state: state, dockTrash: dockTrash)
                } symbols: {
                    ForEach(icons.indices, id: \.self) { index in
                        FileIconView(icon: icons[index]).tag(index)
                    }
                    trashImage(trashFull).tag(Symbol.trashFull)
                    trashImage(trashEmpty).tag(Symbol.trashEmpty)
                }
                .drawingGroup()

                if showsConfetti {
                    ConfettiView()
                        .frame(width: 640, height: 574)
                        .position(x: scene.centerX, y: scene.top + scene.style.island.height + 30)
                }

                notchPath(state.size)
                    .fill(.black)
                    .opacity(state.opacity)

                IslandContent(event: event, icons: Array(icons.prefix(3)))
                    .environment(\.colorScheme, .dark)
                    .frame(width: scene.style.island.width - 40, height: contentHeight)
                    .position(x: scene.centerX, y: scene.top + scene.cameraHeight + contentHeight / 2)
                    .opacity(state.contentOpacity)
                    .scaleEffect(0.92 + 0.08 * state.contentOpacity)
                    .blur(radius: (1 - state.contentOpacity) * 5)
            }
            .frame(width: scene.size.width, height: scene.size.height)
        }
        .allowsHitTesting(false)
        .task {
            guard let confetti = timeline.confettiStart else { return }
            try? await Task.sleep(for: .seconds(confetti))
            showsConfetti = !Task.isCancelled
        }
    }

    private var contentHeight: CGFloat {
        scene.style.island.height - scene.cameraHeight
    }

    private func trashImage(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: scene.trashIconSize, height: scene.trashIconSize)
    }

    /// A real notch hangs from the top of the screen, and grows little
    /// outward curves where it meets the bezel as it widens. The pill is a capsule.
    private func notchPath(_ size: NotchSize) -> Path {
        let w = size.width, h = size.height
        let x0 = scene.centerX - w / 2, x1 = scene.centerX + w / 2, y0 = scene.top
        let r = min(size.radius, h / 2, w / 2)
        guard scene.style.showsAtRest else {
            return Path(roundedRect: CGRect(x: x0, y: y0, width: w, height: h), cornerRadius: r, style: .continuous)
        }
        let flare = min(10, max(0, (w - scene.style.rest.width) / 5), h / 3)
        var path = Path()
        path.move(to: CGPoint(x: x0 - flare, y: y0))
        path.addQuadCurve(to: CGPoint(x: x0, y: y0 + flare), control: CGPoint(x: x0, y: y0))
        path.addArc(tangent1End: CGPoint(x: x0, y: y0 + h), tangent2End: CGPoint(x: x0 + r, y: y0 + h), radius: r)
        path.addArc(tangent1End: CGPoint(x: x1, y: y0 + h), tangent2End: CGPoint(x: x1, y: y0 + h - r), radius: r)
        path.addLine(to: CGPoint(x: x1, y: y0 + flare))
        path.addQuadCurve(to: CGPoint(x: x1 + flare, y: y0), control: CGPoint(x: x1, y: y0))
        path.closeSubpath()
        return path
    }
}

/// Draws the flying files and the stand-in Trash for one frame.
///
/// A plain struct rather than View methods: it holds only values, so the
/// Canvas can call it without touching any main-actor state.
private struct FlightRenderer {
    let scene: NotchScene
    let timeline: NotchTimeline
    let iconCount: Int

    func draw(in context: inout GraphicsContext, time t: Double, state: NotchState, dockTrash: CGPoint) {
        let thrower = TrashThrow(scene: scene, iconCount: iconCount)
        let trash = scene.peeksTrash ? scene.standIn(offset: state.trashOffset) : dockTrash

        var files = context
        thrower.maskInside(&files, trash: trash)
        thrower.drawEmerging(timeline.flights, in: &files, trash: trash, time: t)
        // The stand-in goes over the files still climbing out, so they rise over its rim.
        if scene.peeksTrash, state.trashOffset < 0.999 {
            let emptied = timeline.flights.last.map { t >= $0.start } ?? true
            thrower.drawStandIn(in: &context, at: trash, emptied: emptied, puff: state.trashPuff)
        }
        guard iconCount > 0 else { return }

        let start = point(thrower.rim(of: scene.peeksTrash ? scene.trash : dockTrash))
        let aim = point(scene.mouth(height: scene.style.notice.height))
        let mouth = point(scene.mouth(height: state.size.height))
        for flight in timeline.flights where flight.start <= t && t < flight.arrival {
            guard let icon = context.resolveSymbol(id: flight.index % iconCount) else { continue }
            let u = flight.progress(at: t)
            let control = FlightPath.control(index: flight.index, from: start, to: aim,
                                             away: point(scene.away), isMini: flight.isMini)
            let here = FlightPath.position(progress: u, from: start, control: control, to: mouth)
            let ahead = FlightPath.position(progress: u + 0.01, from: start, control: control, to: mouth)
            let speed = hypot(ahead.x - here.x, ahead.y - here.y) / (0.01 * flight.duration)
            let stretch = FlightPath.stretch(speed: speed)
            let heading = Angle.radians(atan2(ahead.y - here.y, ahead.x - here.x))
            let scale = FlightPath.scale(progress: u, isMini: flight.isMini)

            var file = files
            file.translateBy(x: here.x, y: here.y)
            file.rotate(by: heading)
            file.scaleBy(x: stretch, y: 1 / stretch)
            file.rotate(by: -heading + .degrees(FlightPath.spin(index: flight.index, progress: u)))
            file.scaleBy(x: scale, y: scale)
            file.draw(icon, at: .zero, anchor: .center)
        }
    }

    private func point(_ p: CGPoint) -> FlightPath.Point { FlightPath.Point(x: p.x, y: p.y) }
    private func point(_ v: CGVector) -> FlightPath.Point { FlightPath.Point(x: v.dx, y: v.dy) }
}

private extension FlightPath.Point {
    static func + (a: Self, b: Self) -> Self { Self(x: a.x + b.x, y: a.y + b.y) }
    static func * (a: Self, k: Double) -> Self { Self(x: a.x * k, y: a.y * k) }
}

/// "Flushed 12 items · 734 MB freed", next to a little fan of the files.
struct IslandContent: View {
    let event: FlushEvent
    let icons: [FileIconCache.Icon]
    var verb = "Flushed"

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                ForEach(icons.indices.reversed(), id: \.self) { index in
                    FileIconView(icon: icons[index])
                        .scaleEffect(0.55)
                        .rotationEffect(.degrees(Double(index - 1) * 9))
                        .offset(x: CGFloat(index) * 8 - 8, y: CGFloat(-index) * 2)
                }
            }
            .frame(width: 44, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.itemCount == 1 ? "\(verb) 1 item" : "\(verb) \(event.itemCount) items")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if event.bytes > 0 {
                    Text("\(event.bytes.formatted(.byteCount(style: .file))) freed")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(.white)
    }
}

/// A file as Finder shows it: its icon, or a content preview in a thin white
/// frame for photos and documents.
struct FileIconView: View {
    let icon: FileIconCache.Icon

    var body: some View {
        if icon.isThumbnail {
            Image(nsImage: icon.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(2)
                .background(.white, in: RoundedRectangle(cornerRadius: 3))
                .frame(maxWidth: NotchScene.fileSize - 6, maxHeight: NotchScene.fileSize - 6)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        } else {
            Image(nsImage: icon.image)
                .resizable()
                .frame(width: NotchScene.fileSize, height: NotchScene.fileSize)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        }
    }
}

extension NSAppearance {
    /// The appearance the Dock draws its icons in. Since macOS 26 that follows the
    /// icon style in Settings › Appearance, not Dark Mode: the default style keeps
    /// icons light in Dark Mode. Clear and Tinted styles also come in light/dark.
    static var dockIcons: NSAppearance {
        let style = UserDefaults.standard.string(forKey: "AppleIconAppearanceTheme") ?? ""
        let dark: Bool
        if style.contains("Dark") {
            dark = true
        } else if style.contains("Automatic") {
            dark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        } else {
            dark = false
        }
        return NSAppearance(named: dark ? .darkAqua : .aqua)!
    }
}

extension NSImage {
    /// The system Trash as the Dock draws it right now. The named image holds a
    /// light and a dark variant, so it's flattened here in the Dock's appearance.
    @MainActor
    static func dockTrash(_ name: NSImage.Name, size: CGFloat) -> NSImage {
        guard let source = NSImage(named: name) else { return NSImage() }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pixels = Int((size * scale).rounded(.up))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return source }
        rep.size = NSSize(width: size, height: size)
        NSAppearance.dockIcons.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            source.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            NSGraphicsContext.restoreGraphicsState()
        }
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
