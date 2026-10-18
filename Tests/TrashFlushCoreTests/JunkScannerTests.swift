import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct JunkScannerTests {
    let home: URL

    init() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)")
        try write("Downloads/Xcode_26.xip", bytes: 3_000_000)
        try write("Downloads/Setup.DMG", bytes: 2_000_000)
        try write("Downloads/notes.txt", bytes: 2_000_000)
        try write("Desktop/Screenshot 2026-09-01 at 10.00.00.png", bytes: 50_000)
        try write("Desktop/holiday.png", bytes: 50_000)
        try write("Library/Developer/Xcode/DerivedData/TrashFlush-bxkqzjwvlhgdtcfyamrnoepsiuqx/Build/app", bytes: 4_000_000)
        try write("Library/Developer/Xcode/DerivedData/Tiny-aaaaaaaaaaaaaaaaaaaaaaaaaaaa/info", bytes: 100)
        try write("Library/Developer/Xcode/iOS DeviceSupport/iPhone 18.0/symbols", bytes: 2_000_000)
        try write("Library/Developer/Xcode/iOS DeviceSupport/iPhone 26.0/symbols", bytes: 2_000_000)
        let newest = home.appendingPathComponent("Library/Developer/Xcode/iOS DeviceSupport/iPhone 26.0")
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(60)], ofItemAtPath: newest.path)
        try write("Library/Developer/CoreSimulator/Caches/dyld/cache", bytes: 1_500_000)
        try write("Library/Caches/com.google.Chrome/Cache/data", bytes: 3_000_000)
        try write("Library/Caches/com.apple.Safari/data", bytes: 3_000_000)
        try write("Library/Caches/com.example.small/data", bytes: 10_000)
        try write("Library/Caches/com.example.kept/data", bytes: 3_000_000)
    }

    private func write(_ path: String, bytes: Int) throws {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: url)
    }

    /// A week and a day from now, so the files above count as old.
    private func scanner() -> JunkScanner {
        var scanner = JunkScanner(home: home, keptCaches: ["com.example.kept"], now: .now.addingTimeInterval(8 * 86_400))
        scanner.minimumCacheSize = 1_000_000
        return scanner
    }

    @Test func findsOldInstallersBiggestFirst() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let names = await scanner().scan(.installers).map(\.title)
        #expect(names == ["Xcode_26.xip", "Setup.DMG"])
    }

    @Test func leavesNewInstallersAlone() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let fresh = JunkScanner(home: home, now: .now)
        #expect(await fresh.scan(.installers).isEmpty)
        #expect(await fresh.scan(.screenshots).isEmpty)
    }

    @Test func findsScreenshotsButNotOtherImages() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let names = await scanner().scan(.screenshots).map(\.title)
        #expect(names == ["Screenshot 2026-09-01 at 10.00.00.png"])
    }

    @Test func findsXcodeLeftoversButKeepsTheNewestDeviceSupport() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let items = await scanner().scan(.xcode)
        #expect(items.map(\.title) == ["TrashFlush build data", "iOS iPhone 18.0 device support", "Simulator caches"])
        #expect(items[0].bytes >= 4_000_000)
    }

    @Test func findsBigCachesExceptApplesAndKeptOnes() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let names = await scanner().scan(.caches).map(\.title)
        #expect(names == ["com.google.Chrome"])
    }

    @Test func missingFoldersFindNothing() async {
        let empty = JunkScanner(home: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        for category in JunkCategory.allCases {
            #expect(await empty.scan(category).isEmpty)
        }
    }

    @Test func diskUsageCountsNestedFiles() async throws {
        defer { try? FileManager.default.removeItem(at: home) }
        let size = await DiskUsage.allocatedSize(of: home.appendingPathComponent("Library/Developer"))
        #expect(size >= 9_500_000)
        #expect(size < 12_000_000)
        let file = await DiskUsage.allocatedSize(of: home.appendingPathComponent("Downloads/Setup.DMG"))
        #expect(file >= 2_000_000 && file < 2_100_000)
    }

    @Test func moveToTrashReportsWhatItCouldNotMove() {
        let missing = JunkItem(url: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"), category: .caches, bytes: 1)
        #expect(JunkCleaner.moveToTrash([missing]) == [missing])
    }

    @Test func derivedDataNamesDropTheHash() {
        #expect(JunkScanner.derivedDataTitle("My-App-bxkqzjwvlhgdtcfyamrnoepsiuqx") == "My-App build data")
        #expect(JunkScanner.derivedDataTitle("ModuleCache.noindex") == "Xcode ModuleCache")
    }
}
