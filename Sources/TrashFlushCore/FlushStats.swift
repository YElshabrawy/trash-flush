import Foundation

/// Lifetime totals shown in the menu.
public struct FlushStats: Codable, Sendable, Equatable {
    public var flushCount = 0
    public var itemsFlushed = 0
    public var bytesFlushed: Int64 = 0
    public var lastFlush: Date?

    public init() {}

    public mutating func record(_ event: FlushEvent, at date: Date = Date()) {
        flushCount += 1
        itemsFlushed += event.itemCount
        bytesFlushed += event.bytes
        lastFlush = date
    }
}
