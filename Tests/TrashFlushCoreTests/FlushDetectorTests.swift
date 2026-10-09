import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct FlushDetectorTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    func snapshot(_ count: Int, bytes: Int64 = 100) -> TrashSnapshot {
        TrashSnapshot(items: Dictionary(uniqueKeysWithValues: (0..<count).map { ("file\($0).txt", bytes) }))
    }

    @Test func emptyingTheTrashEmitsAnEvent() {
        var detector = FlushDetector()
        #expect(detector.observe(snapshot(3), at: t0) == nil)
        let event = detector.observe(.empty, at: t0 + 1)
        #expect(event?.itemCount == 3)
        #expect(event?.bytes == 300)
    }

    @Test func emptyTrashAtLaunchIsNotAFlush() {
        var detector = FlushDetector()
        #expect(detector.observe(.empty, at: t0) == nil)
        #expect(detector.observe(.empty, at: t0 + 1) == nil)
    }

    @Test func firstSnapshotNeverEmits() {
        var detector = FlushDetector()
        #expect(detector.observe(snapshot(5), at: t0) == nil)
    }

    @Test func putBackIsNotAFlush() {
        var detector = FlushDetector()
        _ = detector.observe(snapshot(3), at: t0)
        #expect(detector.observe(snapshot(2), at: t0 + 1) == nil)
    }

    @Test func slowEmptyReportsTheFullTrash() {
        var detector = FlushDetector()
        _ = detector.observe(snapshot(10), at: t0)
        _ = detector.observe(snapshot(6), at: t0 + 1)
        _ = detector.observe(snapshot(2), at: t0 + 2)
        #expect(detector.observe(.empty, at: t0 + 3)?.itemCount == 10)
    }

    @Test func putBackLongBeforeEmptyingIsNotCounted() {
        var detector = FlushDetector(window: 5)
        _ = detector.observe(snapshot(10), at: t0)
        _ = detector.observe(snapshot(9), at: t0 + 1)
        #expect(detector.observe(.empty, at: t0 + 60)?.itemCount == 9)
    }

    @Test func growingTrashResetsThePeak() {
        var detector = FlushDetector()
        _ = detector.observe(snapshot(10), at: t0)
        _ = detector.observe(snapshot(9), at: t0 + 1)
        _ = detector.observe(snapshot(12), at: t0 + 2)
        #expect(detector.observe(.empty, at: t0 + 3)?.itemCount == 12)
    }
}
