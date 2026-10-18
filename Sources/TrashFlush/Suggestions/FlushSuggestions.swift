import AppKit
import Observation
import TrashFlushCore

/// Finds safe junk, lets you review it and moves what you pick to the Trash.
@MainActor
@Observable
final class FlushSuggestions {
    enum Phase: Equatable {
        case idle
        case scanning
        case review
        case moving
        /// Moved this much to the Trash, ready to flush.
        case moved(bytes: Int64, failures: Int)
    }

    private(set) var phase = Phase.idle
    private(set) var items: [JunkCategory: [JunkItem]] = [:]
    /// Categories still being scanned.
    private(set) var pending: Set<JunkCategory> = []
    var selected: Set<URL> = []
    var expanded: Set<JunkCategory> = []

    /// Called after items land in the Trash, so it can be re-read right away.
    var onMoved: (() -> Void)?

    private var scan: Task<Void, Never>?

    var categories: [JunkCategory] { JunkCategory.allCases.filter { !(items[$0] ?? []).isEmpty } }
    var selectedItems: [JunkItem] { items.values.joined().filter { selected.contains($0.url) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var isEmpty: Bool { pending.isEmpty && categories.isEmpty }

    func bytes(in category: JunkCategory) -> Int64 {
        (items[category] ?? []).reduce(0) { $0 + $1.bytes }
    }

    func start() {
        scan?.cancel()
        items = [:]
        selected = []
        expanded = []
        pending = Set(JunkCategory.allCases)
        phase = .scanning

        generation += 1
        let generation = generation
        let scanner = JunkScanner(screenshots: Self.screenshotFolder,
                                  keptCaches: [Bundle.main.bundleIdentifier ?? "TrashFlush"])
        scan = Task(priority: .userInitiated) {
            await withTaskGroup(of: JunkCategory.self) { group in
                for category in JunkCategory.allCases {
                    group.addTask {
                        await scanner.scan(category) { item in await self.add(item, generation: generation) }
                        return category
                    }
                }
                for await category in group where self.generation == generation {
                    pending.remove(category)
                }
            }
            if self.generation == generation { phase = .review }
        }
    }

    /// Bumped by every new scan or cancel, so a stale scan's late results are dropped.
    private var generation = 0

    private func add(_ item: JunkItem, generation: Int) {
        guard generation == self.generation else { return }
        var list = items[item.category] ?? []
        list.insert(item, at: list.firstIndex { $0.bytes < item.bytes } ?? list.endIndex)
        items[item.category] = list
        selected.insert(item.url)
    }

    func cancel() {
        scan?.cancel()
        generation += 1
        phase = .idle
        items = [:]
        selected = []
        pending = []
    }

    func moveSelectedToTrash() {
        let chosen = selectedItems
        guard !chosen.isEmpty, phase == .review else { return }
        phase = .moving
        Task {
            let failed = await Task.detached(priority: .userInitiated) { JunkCleaner.moveToTrash(chosen) }.value
            let moved = chosen.reduce(0) { $0 + $1.bytes } - failed.reduce(0) { $0 + $1.bytes }
            items = [:]
            selected = []
            phase = .moved(bytes: moved, failures: failed.count)
            onMoved?()
        }
    }

    func toggle(_ category: JunkCategory) {
        let urls = Set((items[category] ?? []).map(\.url))
        if urls.isSubset(of: selected) { selected.subtract(urls) } else { selected.formUnion(urls) }
    }

    func toggle(_ item: JunkItem) {
        if selected.contains(item.url) { selected.remove(item.url) } else { selected.insert(item.url) }
    }

    /// Where Screenshot saves, set in its Options menu.
    private static var screenshotFolder: URL? {
        guard let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") else { return nil }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }
}
