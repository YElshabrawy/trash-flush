import Foundation

/// Turns a stream of Trash snapshots into "the Trash was just emptied" events.
///
/// The rule: the Trash had items and now has none. Finder deletes items one by
/// one, so on a big Trash we may see a few shrinking snapshots on the way to
/// zero. To report the full amount we remember the snapshot from before the
/// shrinking started, as long as the shrinking keeps going. A single "Put Back"
/// followed much later by Empty Trash is reported from the later snapshot.
public struct FlushDetector: Sendable {
    /// How long a pause in shrinking may last and still count as one empty.
    public var window: TimeInterval

    private var previous: TrashSnapshot?
    private var peak: TrashSnapshot?
    private var lastShrink: Date = .distantPast

    public init(window: TimeInterval = 5) {
        self.window = window
    }

    public mutating func observe(_ snapshot: TrashSnapshot, at now: Date = Date()) -> FlushEvent? {
        defer { previous = snapshot }
        guard let previous else { return nil }

        if snapshot.isEmpty {
            let recentPeak = now.timeIntervalSince(lastShrink) <= window ? peak : nil
            peak = nil
            guard !previous.isEmpty else { return nil }
            return FlushEvent(flushing: recentPeak ?? previous)
        }

        if snapshot.count < previous.count {
            if peak == nil || now.timeIntervalSince(lastShrink) > window {
                peak = previous
            }
            lastShrink = now
        } else {
            peak = nil
        }
        return nil
    }
}
