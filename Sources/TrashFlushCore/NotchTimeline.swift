import Foundation

/// When everything happens in the flush, in seconds since it started.
///
/// 1. The notch widens a little, as if it noticed something. With an
///    auto-hidden Dock, a stand-in Trash peeks up from the screen edge.
/// 2. Files pop out of the Trash one after another and arc up into the notch,
///    which opens like a mouth and gulps each one. Past 12 files, the rest
///    follow as a quick stream of small icons.
/// 3. The notch grows into an island with "Flushed 12 items" and confetti.
/// 4. The island shrinks back into the notch.
public struct NotchTimeline: Sendable, Equatable {
    public struct Flight: Sendable, Equatable {
        public var index: Int
        public var start: Double
        public var duration: Double
        /// One of the small icons in the stream that follows the first 12.
        public var isMini: Bool

        public var arrival: Double { start + duration }

        /// 0 when the file leaves the Trash, 1 when the notch swallows it.
        public func progress(at t: Double) -> Double {
            min(max((t - start) / duration, 0), 1)
        }

        /// 0...1 while the file climbs up inside the Trash, just before it leaves.
        public func emergence(at t: Double) -> Double {
            min(max((t - start + NotchTimeline.emergeDuration) / NotchTimeline.emergeDuration, 0), 1)
        }
    }

    public static let emergeDuration = 0.14
    public static let maxFlights = 12
    public static let maxStream = 24

    public var flights: [Flight]
    public var peeksTrash: Bool
    public var reduceMotion: Bool
    /// The notch starts growing into the island.
    public var islandStart: Double
    /// The text inside the island fades in.
    public var contentStart: Double
    public var confettiStart: Double?
    /// The text fades out, and right after it the island shrinks back.
    public var contentEnd: Double
    public var collapse: Double
    /// The stand-in Trash slides back off the screen.
    public var trashReturn: Double
    public var total: Double

    public init(itemCount: Int, peeksTrash: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.peeksTrash = peeksTrash && !reduceMotion

        guard !reduceMotion else {
            flights = []
            islandStart = 0.05
            contentStart = 0.17
            confettiStart = nil
            contentEnd = 2.2
            collapse = 2.34
            trashReturn = 0
            total = 3.0
            return
        }

        let count = max(itemCount, 1)
        let main = min(count, Self.maxFlights)
        let stream = min(count - main, Self.maxStream)
        let first = self.peeksTrash ? 0.42 : 0.18
        let stagger = min(0.11, 0.95 / Double(main))
        let duration = 0.85, miniDuration = 0.7, streamGap = 0.04

        var flights = (0..<main).map {
            Flight(index: $0, start: first + Double($0) * stagger, duration: duration, isMini: false)
        }
        let streamStart = first + Double(main) * stagger
        flights += (0..<stream).map {
            Flight(index: main + $0, start: streamStart + Double($0) * streamGap, duration: miniDuration, isMini: true)
        }
        self.flights = flights

        let lastLaunch = flights.map(\.start).max() ?? first
        let lastArrival = flights.map(\.arrival).max() ?? first
        trashReturn = lastLaunch + 0.3
        islandStart = lastArrival + 0.08
        contentStart = lastArrival + 0.2
        confettiStart = lastArrival + 0.2
        contentEnd = lastArrival + 2.2
        collapse = contentEnd + 0.14
        total = collapse + 0.75
    }
}

// MARK: - Notch motion

/// Width, height and bottom corner radius of the black shape, in points.
public struct NotchSize: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var radius: Double

    public init(width: Double, height: Double, radius: Double) {
        self.width = width
        self.height = height
        self.radius = radius
    }
}

/// The shapes the notch moves between. A Mac without a notch gets a pill that
/// only shows during the animation.
public struct NotchStyle: Sendable, Equatable {
    public var rest: NotchSize
    /// Slightly wider: it noticed the Trash being emptied.
    public var notice: NotchSize
    /// Open wide while a file is about to be swallowed.
    public var mouth: NotchSize
    public var island: NotchSize
    public var showsAtRest: Bool

    public init(rest: NotchSize, notice: NotchSize, mouth: NotchSize, island: NotchSize, showsAtRest: Bool) {
        self.rest = rest
        self.notice = notice
        self.mouth = mouth
        self.island = island
        self.showsAtRest = showsAtRest
    }

    /// Sizes relative to the real notch, so they work on every MacBook.
    public static func notch(width: Double, height: Double) -> NotchStyle {
        NotchStyle(rest: NotchSize(width: width, height: height, radius: min(10, height / 3)),
                   notice: NotchSize(width: width + 32, height: height + 4, radius: 12),
                   mouth: NotchSize(width: width + 68, height: height + 18, radius: 18),
                   island: NotchSize(width: max(width + 196, 400), height: height + 66, radius: 30),
                   showsAtRest: true)
    }

    public static let pill = NotchStyle(rest: NotchSize(width: 40, height: 30, radius: 15),
                                        notice: NotchSize(width: 180, height: 34, radius: 17),
                                        mouth: NotchSize(width: 232, height: 46, radius: 23),
                                        island: NotchSize(width: 364, height: 66, radius: 33),
                                        showsAtRest: false)
}

/// Everything about the notch and the stand-in Trash at one moment.
public struct NotchState: Sendable, Equatable {
    public var size: NotchSize
    public var opacity: Double
    public var contentOpacity: Double
    /// 1 while the stand-in Trash is off the screen, 0 when it has peeked up.
    public var trashOffset: Double
    /// How much the Trash puffs up as it throws each file, 0 at rest. It only
    /// ever grows, so a copy drawn over the Dock's Trash always hides it.
    public var trashPuff: Double
}

/// The notch moves on damped springs, kicked each time it swallows a file.
///
/// The state is a pure function of time: it re-runs the springs from 0 at a
/// fixed step. That is under a thousand steps for the whole animation, cheap
/// enough to redo every frame, and it keeps the renderer free of mutable state.
public enum NotchMotion {
    static let step = 1.0 / 240

    public static func state(at t: Double, timeline: NotchTimeline, style: NotchStyle) -> NotchState {
        var width = Spring(style.rest.width)
        var height = Spring(style.rest.height)
        var radius = Spring(style.rest.radius)
        var opacity = Spring(style.showsAtRest ? 1 : 0, stiffness: 260, damping: 32)
        var trash = Spring(1, stiffness: 260, damping: 24)
        var puff = Spring(0, stiffness: 520, damping: 16)
        var content = 0.0

        let steps = Int(max(t, 0) / step)
        var time = 0.0
        for _ in 0..<steps {
            let next = time + step
            for flight in timeline.flights {
                if time < flight.start, flight.start <= next {
                    puff.velocity += flight.isMini ? 1.5 : 3.2
                }
                if time < flight.arrival, flight.arrival <= next {
                    height.velocity -= flight.isMini ? 110 : 320
                    width.velocity += flight.isMini ? 70 : 230
                }
            }

            let target = shape(at: next, timeline: timeline, style: style)
            width.target = target.width
            height.target = target.height
            radius.target = target.radius
            if !style.showsAtRest {
                opacity.target = next < timeline.collapse + 0.3 ? 1 : 0
            }
            trash.target = timeline.peeksTrash && next < timeline.trashReturn ? 0 : 1
            let shows = next >= timeline.contentStart && next < timeline.contentEnd
            content += ((shows ? 1 : 0) - content) * min(1, step * 14)

            width.advance(step)
            height.advance(step)
            radius.advance(step)
            opacity.advance(step)
            trash.advance(step)
            puff.advance(step)
            time = next
        }

        return NotchState(size: NotchSize(width: max(width.value, 0), height: max(height.value, 0), radius: max(radius.value, 0)),
                          opacity: min(max(opacity.value, 0), 1),
                          contentOpacity: content,
                          trashOffset: trash.value,
                          trashPuff: abs(puff.value))
    }

    /// The shape the notch is heading for at time `t`.
    static func shape(at t: Double, timeline: NotchTimeline, style: NotchStyle) -> NotchSize {
        if t >= timeline.collapse { return style.rest }
        if t >= timeline.islandStart { return style.island }
        if timeline.reduceMotion { return style.rest }
        let approaching = timeline.flights.contains { $0.progress(at: t) > 0.55 && $0.progress(at: t) < 1 }
        return approaching ? style.mouth : style.notice
    }
}

/// A damped spring: it overshoots a little and settles, like the real thing.
struct Spring {
    var value: Double
    var velocity = 0.0
    var target: Double
    var stiffness: Double
    var damping: Double

    init(_ value: Double, stiffness: Double = 320, damping: Double = 22) {
        self.value = value
        self.target = value
        self.stiffness = stiffness
        self.damping = damping
    }

    mutating func advance(_ dt: Double) {
        velocity += (-stiffness * (value - target) - damping * velocity) * dt
        value += velocity * dt
    }
}

// MARK: - Flight path

/// The arc a file follows from the Trash up into the notch: a quadratic Bézier
/// curve that fans out to alternating sides, eased to shoot out of the Trash,
/// hang for a moment, then get sucked in.
public enum FlightPath {
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// Where file `index` bends toward. `away` points from the Dock's edge into
    /// the screen, so the arc first rises away from the Dock.
    public static func control(index: Int, from start: Point, to end: Point, away: Point, isMini: Bool) -> Point {
        var rng = SplitMix64(seed: UInt64(index) &* 7919 &+ 17)
        let dx = end.x - start.x, dy = end.y - start.y
        let length = max(hypot(dx, dy), 1)
        let side = (index.isMultiple(of: 2) ? -1.0 : 1.0) * (70 + 190 * rng.nextUnit()) * (isMini ? 0.6 : 1)
        let lift = 90.0
        return Point(x: (start.x + end.x) / 2 - dy / length * side + away.x * lift,
                     y: (start.y + end.y) / 2 + dx / length * side + away.y * lift)
    }

    /// Fast at both ends and slow in the middle. Always moving forward.
    public static func eased(_ u: Double) -> Double {
        let u = min(max(u, 0), 1)
        return u + 0.55 / (2 * .pi) * sin(2 * .pi * u)
    }

    public static func position(progress u: Double, from a: Point, control c: Point, to b: Point) -> Point {
        let p = eased(u), q = 1 - p
        return Point(x: q * q * a.x + 2 * q * p * c.x + p * p * b.x,
                     y: q * q * a.y + 2 * q * p * c.y + p * p * b.y)
    }

    /// Pops out of the Trash with a little overshoot, then shrinks into the notch.
    public static func scale(progress u: Double, isMini: Bool) -> Double {
        let u = min(max(u, 0), 1)
        let pop = u < 0.14 ? 0.35 + 0.65 * easeOutBack(u / 0.14) : 1
        return (isMini ? 0.55 : 1) * pop * (1 - 0.7 * smoothstep(0.6, 1, u))
    }

    /// How much a file stretches along its direction of travel at `speed` points per second.
    public static func stretch(speed: Double) -> Double {
        1 + min(speed / 2600, 0.45)
    }

    /// A gentle tumble, in degrees, that peaks mid-flight.
    public static func spin(index: Int, progress u: Double) -> Double {
        var rng = SplitMix64(seed: UInt64(index) &* 104_729 &+ 3)
        return (rng.nextUnit() - 0.5) * 50 * sin(.pi * min(max(u, 0), 1))
    }

    static func easeOutBack(_ x: Double) -> Double {
        let c = 1.9
        return 1 + (c + 1) * pow(x - 1, 3) + c * pow(x - 1, 2)
    }
}

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
