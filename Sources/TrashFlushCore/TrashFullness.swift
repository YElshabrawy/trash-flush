import Foundation

/// How full the menu bar Trash looks, measured against the size the user
/// considers "time to flush".
public struct TrashFullness: Sendable, Equatable {
    /// The can fills in this many steps, so the icon only redraws when you can
    /// see the difference.
    public static let steps = 5

    /// The sizes offered in the menu, in bytes. Zero means "never smell".
    public static let limits: [Int64] = [1, 5, 10, 25].map { $0 * 1_000_000_000 } + [0]
    public static let defaultLimit: Int64 = 5_000_000_000

    /// 0 when empty, `steps` when full.
    public var level: Int
    /// Over the limit: the can is full and flies buzz around it.
    public var isOverflowing: Bool

    public init(level: Int, isOverflowing: Bool) {
        self.level = level
        self.isOverflowing = isOverflowing
    }

    public static let empty = TrashFullness(level: 0, isOverflowing: false)

    /// Anything in the Trash shows at least one step. With no limit set the can
    /// fills against the default limit but never overflows.
    public init(bytes: Int64, isEmpty: Bool, limit: Int64) {
        guard !isEmpty else {
            self = .empty
            return
        }
        let scale = limit > 0 ? limit : Self.defaultLimit
        let fraction = min(1, Double(max(0, bytes)) / Double(scale))
        level = max(1, Int((fraction * Double(Self.steps)).rounded(.up)))
        isOverflowing = limit > 0 && bytes >= limit
    }

    public var fraction: Double { Double(level) / Double(Self.steps) }
}
