import Foundation

/// What is in the Trash at one moment: each top-level item and its size on disk.
public struct TrashSnapshot: Sendable, Equatable {
    /// File name -> allocated bytes (folders include everything inside them).
    public var items: [String: Int64]

    public init(items: [String: Int64] = [:]) {
        self.items = items
    }

    public static let empty = TrashSnapshot()

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }
    public var totalBytes: Int64 { items.values.reduce(0, +) }
}

/// A completed "empty the Trash", as seen from the outside.
public struct FlushEvent: Sendable, Equatable {
    public var itemCount: Int
    public var bytes: Int64
    /// A few of the flushed file names, used to pick icons for the animation.
    public var sampleNames: [String]

    public init(itemCount: Int, bytes: Int64, sampleNames: [String]) {
        self.itemCount = itemCount
        self.bytes = bytes
        self.sampleNames = sampleNames
    }

    public init(flushing snapshot: TrashSnapshot, sampleLimit: Int = 18) {
        self.init(
            itemCount: snapshot.count,
            bytes: snapshot.totalBytes,
            sampleNames: Array(snapshot.items.keys.sorted().prefix(sampleLimit))
        )
    }

    /// Fake contents for the "Preview" button.
    public static let preview = FlushEvent(
        itemCount: 12,
        bytes: 734_003_200,
        sampleNames: [
            "Screenshot 2026-10-09.png", "Invoice.pdf", "old-project", "Notes.txt",
            "Holiday.mov", "Song.mp3", "Archive.zip", "Draft.docx", "Setup.dmg",
            "Photo.heic", "Slides.key", "Budget.xlsx",
        ]
    )
}
