import Foundation

/// Timing of the flush animation, in seconds since it started.
public enum FlushTimeline {
    public static let total = 3.4

    /// Bowl pops in.
    public static func appear(_ t: Double) -> Double { smoothstep(0, 0.35, t) }
    /// Whole overlay fades out at the end.
    public static func opacity(_ t: Double) -> Double { 1 - smoothstep(2.9, total, t) }
    /// How far the water has drained, 0...1. Drives the drain hole and colors.
    public static func drain(_ t: Double) -> Double { smoothstep(0.3, 2.7, t) }
    /// "Flushed 12 items" appears near the end.
    public static func caption(_ t: Double) -> Double { smoothstep(2.1, 2.4, t) * opacity(t) }

    /// Rotation of the water in radians. Quadratic, so the vortex keeps speeding up.
    public static func spin(_ t: Double) -> Double { 1.6 * t + 1.4 * t * t }

    public static let particleTravel = 1.3

    /// When particle `index` of `count` starts sinking. Staggered so they swirl
    /// down one after another and the last one is gone at 2.7 s.
    public static func particleProgress(index: Int, count: Int, at t: Double) -> Double {
        let stagger = count > 1 ? 1.1 * Double(index) / Double(count - 1) : 0
        let start = 0.3 + stagger
        return min(max((t - start) / particleTravel, 0), 1)
    }
}

/// Geometry of the swirl. Radii are fractions of the bowl radius (0...1),
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
            opacity: min(1, p / 0.08) * (1 - smoothstep(0.82, 1, p))
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
