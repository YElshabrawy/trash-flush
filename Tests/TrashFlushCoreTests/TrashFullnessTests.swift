import Testing
@testable import TrashFlushCore

@Suite struct TrashFullnessTests {
    private let gb: Int64 = 1_000_000_000

    @Test func emptyTrashIsAnEmptyCan() {
        #expect(TrashFullness(bytes: 0, isEmpty: true, limit: 5 * gb) == .empty)
    }

    @Test func anythingInTheTrashShows() {
        let tiny = TrashFullness(bytes: 0, isEmpty: false, limit: 5 * gb)
        #expect(tiny.level == 1)
        #expect(!tiny.isOverflowing)
    }

    @Test func fillsInStepsUpToTheLimit() {
        let levels = stride(from: Int64(0), through: 5 * gb, by: Int(gb / 4)).map {
            TrashFullness(bytes: $0, isEmpty: false, limit: 5 * gb).level
        }
        #expect(levels == levels.sorted())
        #expect(levels.first == 1)
        #expect(levels.last == TrashFullness.steps)
    }

    @Test func overflowsAtTheLimit() {
        #expect(!TrashFullness(bytes: 5 * gb - 1, isEmpty: false, limit: 5 * gb).isOverflowing)
        let full = TrashFullness(bytes: 5 * gb, isEmpty: false, limit: 5 * gb)
        #expect(full.isOverflowing)
        #expect(full.level == TrashFullness.steps)
        #expect(TrashFullness(bytes: 80 * gb, isEmpty: false, limit: 5 * gb).level == TrashFullness.steps)
    }

    @Test func noLimitNeverOverflows() {
        let huge = TrashFullness(bytes: 500 * gb, isEmpty: false, limit: 0)
        #expect(!huge.isOverflowing)
        #expect(huge.level == TrashFullness.steps)
    }
}
