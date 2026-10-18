import Darwin
import Foundation

/// Kinds of files that are safe to throw away: they're either leftovers you
/// no longer need or things apps rebuild on their own.
public enum JunkCategory: String, CaseIterable, Sendable {
    /// Disk images, packages and archives sitting in Downloads.
    case installers
    /// Screenshots and screen recordings where macOS saves them.
    case screenshots
    /// DerivedData, old device support files and simulator caches.
    case xcode
    /// App caches in ~/Library/Caches.
    case caches
}

public struct JunkItem: Sendable, Hashable, Identifiable {
    public var url: URL
    public var category: JunkCategory
    public var bytes: Int64
    /// What to call it, when the file name isn't helpful (DerivedData's hashes).
    public var title: String

    public var id: URL { url }

    public init(url: URL, category: JunkCategory, bytes: Int64, title: String? = nil) {
        self.url = url
        self.category = category
        self.bytes = bytes
        self.title = title ?? url.lastPathComponent
    }
}

/// Finds junk. Every category is a separate, independent scan, so they can
/// run at the same time and show up as each one finishes.
public struct JunkScanner: Sendable {
    public var home: URL
    /// Where screenshots are saved: the Desktop unless changed in Screenshot's options.
    public var screenshots: URL
    /// Cache folders to leave alone, like the app's own.
    public var keptCaches: Set<String>
    public var now: Date
    /// Smaller caches aren't worth the trouble.
    public var minimumCacheSize: Int64 = 100 * 1_000_000

    /// Installers and screenshots younger than this are probably still wanted.
    public static let minimumAge: TimeInterval = 7 * 24 * 3600
    /// Below this, a leftover isn't worth listing.
    public static let minimumSize: Int64 = 1_000_000

    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "zip", "xip", "iso"]
    static let screenshotPrefixes = ["Screenshot ", "Screen Shot ", "Screen Recording "]

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, screenshots: URL? = nil,
                keptCaches: Set<String> = [], now: Date = .now) {
        self.home = home
        self.screenshots = screenshots ?? home.appendingPathComponent("Desktop", isDirectory: true)
        self.keptCaches = keptCaches
        self.now = now
    }

    /// Biggest first.
    public func scan(_ category: JunkCategory) async -> [JunkItem] {
        let found = Found()
        await scan(category) { await found.add($0) }
        return await found.items.sorted { $0.bytes > $1.bytes }
    }

    /// Hands over each item as soon as it's measured, so a list can fill in
    /// while the biggest folders are still being walked.
    public func scan(_ category: JunkCategory, found: @escaping @Sendable (JunkItem) async -> Void) async {
        switch category {
        case .installers:
            for item in installers() { await found(item) }
        case .screenshots:
            for item in oldScreenshots() { await found(item) }
        case .xcode:
            await measure(xcodeLeftovers(), category: .xcode, atLeast: Self.minimumSize, found: found)
        case .caches:
            await measure(bigCaches(), category: .caches, atLeast: minimumCacheSize, found: found)
        }
    }

    private actor Found {
        var items: [JunkItem] = []
        func add(_ item: JunkItem) { items.append(item) }
    }

    private func measure(_ candidates: [(url: URL, title: String?)], category: JunkCategory, atLeast minimum: Int64,
                         found: @escaping @Sendable (JunkItem) async -> Void) async {
        await withTaskGroup(of: JunkItem?.self) { group in
            for (url, title) in candidates {
                group.addTask {
                    let bytes = await DiskUsage.allocatedSize(of: url)
                    return bytes >= minimum ? JunkItem(url: url, category: category, bytes: bytes, title: title) : nil
                }
            }
            for await item in group {
                if let item { await found(item) }
            }
        }
    }

    // MARK: Categories

    private func installers() -> [JunkItem] {
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        return oldFiles(in: downloads, category: .installers) {
            Self.installerExtensions.contains($0.pathExtension.lowercased())
        }
    }

    private func oldScreenshots() -> [JunkItem] {
        oldFiles(in: screenshots, category: .screenshots) { url in
            Self.isScreenCapture(url) || Self.screenshotPrefixes.contains { url.lastPathComponent.hasPrefix($0) }
        }
    }

    private func xcodeLeftovers() -> [(url: URL, title: String?)] {
        let developer = home.appendingPathComponent("Library/Developer", isDirectory: true)
        let xcode = developer.appendingPathComponent("Xcode", isDirectory: true)
        var found: [(url: URL, title: String?)] = []

        for build in children(of: xcode.appendingPathComponent("DerivedData")) {
            found.append((build, Self.derivedDataTitle(build.lastPathComponent)))
        }
        // Xcode copies these from every device and OS version it ever saw.
        // Keep the newest of each platform; it's the one in use.
        for platform in children(of: xcode) where platform.lastPathComponent.hasSuffix("DeviceSupport") {
            let versions = children(of: platform).sorted { modified($0) > modified($1) }
            let kind = platform.lastPathComponent.replacingOccurrences(of: " DeviceSupport", with: "")
            for version in versions.dropFirst() {
                found.append((version, "\(kind) \(version.lastPathComponent) device support"))
            }
        }
        for (path, title) in [("CoreSimulator/Caches", "Simulator caches"),
                              ("Xcode/UserData/Previews", "SwiftUI preview simulators")] {
            let url = developer.appendingPathComponent(path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { found.append((url, title)) }
        }
        return found
    }

    private func bigCaches() -> [(url: URL, title: String?)] {
        let caches = home.appendingPathComponent("Library/Caches", isDirectory: true)
        // Apple's own caches are often protected or in use by the system.
        return children(of: caches)
            .filter { !$0.lastPathComponent.hasPrefix("com.apple.") && !keptCaches.contains($0.lastPathComponent) }
            .map { ($0, nil) }
    }

    // MARK: Helpers

    /// Top-level files in `folder` that arrived over a week ago.
    private func oldFiles(in folder: URL, category: JunkCategory, matching matches: (URL) -> Bool) -> [JunkItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .addedToDirectoryDateKey, .contentModificationDateKey,
                                      .totalFileAllocatedSizeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                  options: .skipsHiddenFiles)) ?? []
        return urls.compactMap { url in
            guard matches(url), let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let date = values.addedToDirectoryDate ?? values.contentModificationDate,
                  now.timeIntervalSince(date) >= Self.minimumAge
            else { return nil }
            return JunkItem(url: url, category: category, bytes: Int64(values.totalFileAllocatedSize ?? 0))
        }
    }

    private func children(of folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                                                      options: .skipsHiddenFiles)) ?? []
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// macOS tags every screenshot and screen recording it saves, whatever
    /// the language it's named in.
    static func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, XATTR_NOFOLLOW) > 0
    }

    /// DerivedData has a "Project-<28 letter hash>" folder per project, and
    /// shared ones like "ModuleCache.noindex".
    static func derivedDataTitle(_ name: String) -> String {
        guard let dash = name.lastIndex(of: "-"), name.distance(from: dash, to: name.endIndex) > 20 else {
            return "Xcode " + name.replacingOccurrences(of: ".noindex", with: "")
        }
        return "\(name[..<dash]) build data"
    }
}

public enum JunkCleaner {
    /// Moves items to the Trash, where they can still be put back until the
    /// Trash is flushed. Returns the items it couldn't move.
    public static func moveToTrash(_ items: [JunkItem]) -> [JunkItem] {
        items.filter { item in
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                return false
            } catch {
                return true
            }
        }
    }
}
