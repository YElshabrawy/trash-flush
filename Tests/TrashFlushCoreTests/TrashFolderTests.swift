import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct TrashFolderTests {
    func makeFakeTrash() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("trash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 5_000).write(to: url.appendingPathComponent("a.png"))
        try Data(repeating: 2, count: 10).write(to: url.appendingPathComponent(".DS_Store"))
        let folder = url.appendingPathComponent("Old Project")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(repeating: 3, count: 20_000).write(to: folder.appendingPathComponent("big.bin"))
        return url
    }

    @Test func snapshotListsItemsAndSizes() throws {
        let url = try makeFakeTrash()
        defer { try? FileManager.default.removeItem(at: url) }

        let snapshot = try TrashFolder(url: url).snapshot()
        #expect(snapshot.count == 2)
        #expect(snapshot.items["a.png", default: 0] >= 5_000)
        #expect(snapshot.items["Old Project", default: 0] >= 20_000)
    }

    @Test func snapshotReusesKnownSizes() throws {
        let url = try makeFakeTrash()
        defer { try? FileManager.default.removeItem(at: url) }

        let previous = TrashSnapshot(items: ["a.png": 42])
        let snapshot = try TrashFolder(url: url).snapshot(reusing: previous)
        #expect(snapshot.items["a.png"] == 42)
    }

    @Test func removeAllEmptiesTheFolder() throws {
        let url = try makeFakeTrash()
        defer { try? FileManager.default.removeItem(at: url) }

        let folder = TrashFolder(url: url)
        #expect(try folder.removeAll() == 0)
        #expect(try folder.snapshot().isEmpty)
    }

    @Test func missingTrashIsEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)")
        #expect(try TrashFolder(url: url).snapshot().isEmpty)
    }
}
