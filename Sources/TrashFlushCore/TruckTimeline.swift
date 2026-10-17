import Foundation

/// When everything happens in the garbage truck pickup, in seconds since it started.
///
/// 1. A garbage truck drives in along the Dock and brakes with its hopper over
///    the Trash. With an auto-hidden Dock, a stand-in Trash peeks up first.
/// 2. The files hop out of the Trash into the hopper, and the truck sags a
///    little under each one. Past 12 files the rest follow as a quick stream.
/// 3. The hopper door chomps twice to compact them.
/// 4. Beep beep: the truck drives off the other way, and a receipt pops up
///    over the Trash with how much was picked up.
public struct TruckTimeline: Sendable, Equatable {
    public var flights: [NotchTimeline.Flight]
    public var peeksTrash: Bool
    public var reduceMotion: Bool
    /// The truck drives in, and comes to a stop at `stop`.
    public var arrive: Double
    public var stop: Double
    /// The two chomps of the hopper door.
    public var chomps: [Double]
    /// The horn, then the truck pulls away and is gone by `gone`.
    public var depart: Double
    public var gone: Double
    public var receiptStart: Double
    public var receiptEnd: Double
    /// The stand-in Trash slides back off the screen.
    public var trashReturn: Double
    public var total: Double

    public static let driveIn = 1.0
    public static let driveOut = 1.3
    public static let chompLength = 0.2

    public init(itemCount: Int, peeksTrash: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.peeksTrash = peeksTrash && !reduceMotion

        guard !reduceMotion else {
            flights = []
            arrive = 0
            stop = 0
            chomps = []
            depart = 0
            gone = 0
            receiptStart = 0.05
            receiptEnd = 2.2
            trashReturn = 0
            total = 3.0
            return
        }

        arrive = self.peeksTrash ? 0.35 : 0.1
        stop = arrive + Self.driveIn

        let count = max(itemCount, 1)
        let main = min(count, NotchTimeline.maxFlights)
        let stream = min(count - main, NotchTimeline.maxStream)
        let first = stop + 0.15
        let stagger = min(0.12, 1.1 / Double(main))
        let duration = 0.6, miniDuration = 0.45, streamGap = 0.045

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
        chomps = [lastArrival + 0.12, lastArrival + 0.12 + Self.chompLength + 0.1]
        depart = chomps[1] + Self.chompLength + 0.4
        gone = depart + Self.driveOut
        receiptStart = depart + 0.2
        receiptEnd = receiptStart + 2.4
        total = max(gone, receiptEnd + 0.5)
    }

    /// 0 while the truck is off the screen, easing to 1 as it brakes to a stop.
    public func approach(at t: Double) -> Double {
        guard !reduceMotion else { return 1 }
        let u = min(max((t - arrive) / Self.driveIn, 0), 1)
        return 1 - pow(1 - u, 3)
    }

    /// 0 until the truck pulls away, speeding up to 1 once it's off the screen.
    public func departure(at t: Double) -> Double {
        guard !reduceMotion else { return 0 }
        let u = min(max((t - depart) / Self.driveOut, 0), 1)
        return u * u
    }
}

/// Everything about the truck and the stand-in Trash at one moment.
public struct TruckState: Sendable, Equatable {
    /// How far the body sits below its rest height, in points (bounces on its springs).
    public var sag: Double
    /// Body tilt in degrees, positive when the nose dips (braking).
    public var pitch: Double
    /// 0 with the hopper door open, 1 when it's shut.
    public var chomp: Double
    /// 0...1, the orange beacon on the roof while the truck is stopped.
    public var beacon: Double
    public var receiptOpacity: Double
    /// 1 while the stand-in Trash is off the screen, 0 when it has peeked up.
    public var trashOffset: Double
    public var trashPuff: Double
}

/// The truck moves on damped springs, kicked when it brakes, takes each file,
/// chomps and pulls away. Like `NotchMotion`, a pure function of time.
public enum TruckMotion {
    public static func state(at t: Double, timeline: TruckTimeline) -> TruckState {
        var sag = Spring(0, stiffness: 260, damping: 11)
        var pitch = Spring(0, stiffness: 220, damping: 12)
        var chomp = Spring(0, stiffness: 600, damping: 34)
        var trash = Spring(1, stiffness: 260, damping: 24)
        var puff = Spring(0, stiffness: 520, damping: 16)
        var receipt = 0.0

        let step = NotchMotion.step
        let steps = Int(max(t, 0) / step)
        var time = 0.0
        for _ in 0..<steps {
            let next = time + step
            func crosses(_ moment: Double) -> Bool { time < moment && moment <= next }

            if crosses(timeline.stop) { pitch.velocity += 60 }
            if crosses(timeline.depart) { pitch.velocity -= 45 }
            for flight in timeline.flights {
                if crosses(flight.start) { puff.velocity += flight.isMini ? 1.5 : 3.2 }
                if crosses(flight.arrival) { sag.velocity += flight.isMini ? 18 : 42 }
            }
            for start in timeline.chomps where crosses(start + TruckTimeline.chompLength * 0.6) {
                sag.velocity += 70
                pitch.velocity -= 30
            }

            chomp.target = timeline.chomps.contains { next >= $0 && next < $0 + TruckTimeline.chompLength } ? 1 : 0
            trash.target = timeline.peeksTrash && next < timeline.trashReturn ? 0 : 1
            let shows = next >= timeline.receiptStart && next < timeline.receiptEnd
            receipt += ((shows ? 1 : 0) - receipt) * min(1, step * 14)

            sag.advance(step)
            pitch.advance(step)
            chomp.advance(step)
            trash.advance(step)
            puff.advance(step)
            time = next
        }

        let stopped = !timeline.reduceMotion && t >= timeline.stop - 0.1 && t < timeline.depart + 0.3
        let beacon = stopped ? 0.5 + 0.5 * sin((t - timeline.stop) * 2 * .pi * 2.2) : 0

        return TruckState(sag: sag.value, pitch: pitch.value, chomp: min(max(chomp.value, 0), 1.1),
                          beacon: beacon, receiptOpacity: receipt,
                          trashOffset: trash.value, trashPuff: abs(puff.value))
    }
}
