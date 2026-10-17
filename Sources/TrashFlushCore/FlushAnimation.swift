import Foundation

/// The animations you can pick from in the menu.
public enum FlushAnimation: String, CaseIterable, Sendable {
    /// The notch opens like a mouth and gulps the files.
    case notch
    /// A garbage truck drives along the Dock and picks them up.
    case truck

    public var title: String {
        switch self {
        case .notch: "Notch gulp"
        case .truck: "Garbage truck"
        }
    }
}

/// What the overlay and the sound share about one animation run.
public protocol FlushTimeline: Sendable {
    /// Seconds until the last frame.
    var total: Double { get }
    /// The sound, timed to the animation, as mono samples in -1...1.
    func soundtrack() -> [Float]
}

extension NotchTimeline: FlushTimeline {
    public func soundtrack() -> [Float] { GulpSynth.render(self) }
}

extension TruckTimeline: FlushTimeline {
    public func soundtrack() -> [Float] { TruckSynth.render(self) }
}
