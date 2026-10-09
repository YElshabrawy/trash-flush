import Foundation

/// Timing of the flush animation, in seconds since it started.
///
/// 1. The toilet rises out of the Dock next to the Trash.
/// 2. Files arc one after another from the Trash into the bowl.
/// 3. The handle goes down, the water swirls and the files sink.
/// 4. The toilet slides back into the Dock.
public enum FlushTimeline {
    public static let total = 4.4

    /// The toilet rises, 0...1. The renderer adds the springy overshoot.
    public static func appear(_ t: Double) -> Double { min(max(t / 0.6, 0), 1) }
    /// The toilet slides back down at the end, 0...1.
    public static func exit(_ t: Double) -> Double { smoothstep(3.85, total, t) }

    /// The moment the handle is pressed. The sound starts here too.
    public static let flushStart = 1.75

    /// How far down the handle is, 0...1: a quick press, a short hold, a slow release.
    public static func handle(_ t: Double) -> Double {
        smoothstep(flushStart - 0.12, flushStart, t) * (1 - smoothstep(flushStart + 0.25, flushStart + 0.6, t))
    }
    /// How strong the vortex is, 0...1.
    public static func swirl(_ t: Double) -> Double {
        smoothstep(flushStart, flushStart + 0.4, t) * (1 - smoothstep(3.3, 3.8, t))
    }
    /// Rotation of the water in radians: a lazy drift, then faster and faster once flushed.
    public static func spin(_ t: Double) -> Double {
        let flushed = max(0, t - flushStart)
        return 0.35 * t + 2.4 * flushed + 2.2 * flushed * flushed
    }
    /// Water level, 1 when full. It drops while flushing and refills afterwards.
    public static func waterLevel(_ t: Double) -> Double {
        1 - 0.25 * smoothstep(flushStart + 0.1, 3.2, t) + 0.25 * smoothstep(3.2, 3.8, t)
    }
    /// "Flushed 12 items" fades in once the bowl is empty.
    public static func caption(_ t: Double) -> Double { smoothstep(2.9, 3.2, t) * (1 - smoothstep(3.9, 4.3, t)) }

    public static let flightDuration = 0.7

    /// When file `index` of `count` leaves the Trash. The last one lands just
    /// as the handle is pressed.
    public static func flightStart(index: Int, count: Int) -> Double {
        let spacing = count > 1 ? min(0.12, 0.65 / Double(count - 1)) : 0
        return 0.4 + spacing * Double(index)
    }

    /// Progress 0...1 of file `index` flying from the Trash to the bowl.
    public static func flightProgress(index: Int, count: Int, at t: Double) -> Double {
        min(max((t - flightStart(index: index, count: count)) / flightDuration, 0), 1)
    }

    /// Progress 0...1 of file `index` spiraling down the drain after the flush.
    public static func sinkProgress(index: Int, count: Int, at t: Double) -> Double {
        let spacing = count > 1 ? 0.45 / Double(count - 1) : 0
        let start = flushStart + 0.15 + spacing * Double(index)
        return min(max((t - start) / 1.0, 0), 1)
    }
}

/// The arc a file follows from the Trash into the bowl: a quadratic Bézier
/// curve, eased so it leaves gently and drops into the water.
public enum Flight {
    public struct Point: Equatable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public static func position(progress p: Double, from a: Point, control c: Point, to b: Point) -> Point {
        let u = easeInOut(min(max(p, 0), 1))
        let v = 1 - u
        return Point(x: v * v * a.x + 2 * v * u * c.x + u * u * b.x,
                     y: v * v * a.y + 2 * v * u * c.y + u * u * b.y)
    }

    /// Small as it pops out of the Trash, biggest at the top of the arc, and
    /// full size (1) when it lands.
    public static func scale(progress p: Double) -> Double {
        let p = min(max(p, 0), 1)
        return 0.45 + 0.55 * p + 0.45 * sin(.pi * p)
    }

    /// Slow at both ends, smooth in between.
    static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

/// Geometry of the swirl. Radii are fractions of the water's radius (0...1),
/// angles are radians. Kept free of SwiftUI so it can be unit tested.
public enum Vortex {
    public struct Placement: Equatable, Sendable {
        public var radius: Double
        public var angle: Double
        public var scale: Double
        public var opacity: Double
    }

    /// Where a sinking file is at `progress` 0...1. Like real water, it spins
    /// faster the closer it gets to the drain (angular momentum is conserved).
    public static func particle(progress p: Double, startAngle: Double, startRadius: Double) -> Placement {
        let remaining = 1 - min(max(p, 0), 1)
        return Placement(
            radius: startRadius * pow(remaining, 1.25),
            angle: startAngle + 2.0 * (pow(max(remaining, 0.04), -0.85) - 1),
            scale: 0.25 + 0.75 * pow(remaining, 0.6),
            opacity: 1 - smoothstep(0.75, 1, p)
        )
    }

    /// A point along one spiral arm of the vortex. `u` runs from the rim (0)
    /// to the drain (1); the arm winds tighter toward the center.
    public static func armPoint(u: Double, phase: Double) -> (radius: Double, angle: Double) {
        let u = min(max(u, 0), 1)
        return (0.97 * pow(1 - u, 1.3), phase + 2.6 * (pow(1 - u * 0.92, -0.9) - 1))
    }

    /// Spreads start angles evenly using the golden angle.
    public static func startAngle(for index: Int) -> Double {
        Double(index) * 2.399_963
    }
}

func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    FlushSynth.smoothstep(a, b, x)
}
