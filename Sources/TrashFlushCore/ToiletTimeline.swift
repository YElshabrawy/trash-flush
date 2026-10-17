import Foundation

/// When everything happens in the toilet flush, in seconds since it started.
///
/// 1. A toilet pops up next to the Dock's Trash, its bowl facing it. With an
///    auto-hidden Dock, a stand-in Trash peeks up first.
/// 2. The files arc out of the Trash into the bowl, and the toilet bounces
///    under each one. Past 12 files the rest follow as a quick stream.
/// 3. It flushes: water splashes up out of the bowl and the toilet rumbles.
/// 4. The toilet shrinks away and a receipt pops up with how much was flushed.
public struct ToiletTimeline: Sendable, Equatable {
    public var flights: [NotchTimeline.Flight]
    public var peeksTrash: Bool
    public var reduceMotion: Bool
    /// The toilet pops up.
    public var appear: Double
    /// It flushes from `flush` to `flushed`.
    public var flush: Double
    public var flushed: Double
    /// The toilet shrinks away.
    public var leave: Double
    public var receiptStart: Double
    public var receiptEnd: Double
    /// The stand-in Trash slides back off the screen.
    public var trashReturn: Double
    public var total: Double

    public static let flushLength = 1.0

    public init(itemCount: Int, peeksTrash: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.peeksTrash = peeksTrash && !reduceMotion

        guard !reduceMotion else {
            flights = []
            appear = 0
            flush = 0
            flushed = 0
            leave = 0
            receiptStart = 0.05
            receiptEnd = 2.2
            trashReturn = 0
            total = 3.0
            return
        }

        appear = self.peeksTrash ? 0.35 : 0.08
        let count = max(itemCount, 1)
        let main = min(count, NotchTimeline.maxFlights)
        let stream = min(count - main, NotchTimeline.maxStream)
        let first = appear + 0.4
        let stagger = min(0.11, 1.0 / Double(main))
        let duration = 0.75, miniDuration = 0.6, streamGap = 0.04

        var flights = (0..<main).map {
            NotchTimeline.Flight(index: $0, start: first + Double($0) * stagger, duration: duration, isMini: false)
        }
        let streamStart = first + Double(main) * stagger
        flights += (0..<stream).map {
            NotchTimeline.Flight(index: main + $0, start: streamStart + Double($0) * streamGap,
                                 duration: miniDuration, isMini: true)
        }
        self.flights = flights

        let lastLaunch = flights.map(\.start).max() ?? first
        let lastArrival = flights.map(\.arrival).max() ?? first
        trashReturn = lastLaunch + 0.35
        flush = lastArrival + 0.15
        flushed = flush + Self.flushLength
        leave = flushed + 0.1
        receiptStart = leave + 0.1
        receiptEnd = receiptStart + 2.4
        total = receiptEnd + 0.5
    }
}

/// Everything about the toilet and the stand-in Trash at one moment.
public struct ToiletState: Sendable, Equatable {
    /// 0 hidden, 1 full size. It overshoots as it pops up.
    public var size: Double
    /// Squash and stretch: positive is squashed (wider, shorter).
    public var squash: Double
    /// Sideways rumble while it flushes, in points.
    public var rumble: Double
    public var receiptOpacity: Double
    /// 1 while the stand-in Trash is off the screen, 0 when it has peeked up.
    public var trashOffset: Double
    public var trashPuff: Double
}

/// Like `NotchMotion`, a pure function of time: it re-runs the springs from 0.
public enum ToiletMotion {
    public static func state(at t: Double, timeline: ToiletTimeline) -> ToiletState {
        var size = Spring(0, stiffness: 300, damping: 17)
        var squash = Spring(0, stiffness: 380, damping: 13)
        var trash = Spring(1, stiffness: 260, damping: 24)
        var puff = Spring(0, stiffness: 520, damping: 16)
        var receipt = 0.0

        let step = NotchMotion.step
        let steps = Int(max(t, 0) / step)
        var time = 0.0
        for _ in 0..<steps {
            let next = time + step
            func crosses(_ moment: Double) -> Bool { time < moment && moment <= next }

            if crosses(timeline.appear) { squash.velocity -= 6 }
            if crosses(timeline.flush) { squash.velocity += 5 }
            if crosses(timeline.leave) { squash.velocity -= 4 }
            for flight in timeline.flights {
                if crosses(flight.start) { puff.velocity += flight.isMini ? 1.5 : 3.2 }
                if crosses(flight.arrival) { squash.velocity += flight.isMini ? 1.2 : 3 }
            }

            let shown = !timeline.reduceMotion && next >= timeline.appear && next < timeline.leave
            size.target = shown ? 1 : 0
            trash.target = timeline.peeksTrash && next < timeline.trashReturn ? 0 : 1
            let shows = next >= timeline.receiptStart && next < timeline.receiptEnd
            receipt += ((shows ? 1 : 0) - receipt) * min(1, step * 14)

            size.advance(step)
            squash.advance(step)
            trash.advance(step)
            puff.advance(step)
            time = next
        }

        // A rumble that swells and dies away over the flush.
        let u = timeline.reduceMotion ? 0 : (t - timeline.flush) / ToiletTimeline.flushLength
        let rumble = u > 0 && u < 1 ? 2.2 * sin(.pi * u) * sin(2 * .pi * 19 * t) : 0

        return ToiletState(size: max(0, size.value), squash: squash.value, rumble: rumble,
                           receiptOpacity: receipt, trashOffset: trash.value, trashPuff: abs(puff.value))
    }
}
