import Foundation

public enum TrashAccessError: Error, Equatable {
    /// macOS privacy protection (TCC) blocked us. Full Disk Access fixes it.
    case permissionDenied
}

/// Reads and empties a Trash folder. Every method does blocking file I/O, so
/// call them off the main thread.
public struct TrashFolder: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The current user's Trash on the startup disk.
    public static var user: TrashFolder {
        TrashFolder(url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true))
    }

    /// Finder keeps its own bookkeeping file in the Trash; it is not "an item".
    static let ignoredNames: Set<String> = [".DS_Store", ".localized"]

    /// Lists the Trash. Sizes are reused from `previous` for names it already
    /// knows, because items rarely change while they sit in the Trash, and
    /// measuring a big folder means walking every file inside it.
    public func snapshot(reusing previous: TrashSnapshot = .empty) throws -> TrashSnapshot {
        let names = try itemNames()
        var items: [String: Int64] = [:]
        items.reserveCapacity(names.count)
        for name in names {
            items[name] = previous.items[name] ?? allocatedSize(of: url.appendingPathComponent(name))
        }
        return TrashSnapshot(items: items)
    }

    /// Permanently deletes everything in the Trash. Returns how many items could
    /// not be removed (for example locked files).
    @discardableResult
    public func removeAll() throws -> Int {
        var failures = 0
        for name in try itemNames() {
            do {
                try FileManager.default.removeItem(at: url.appendingPathComponent(name))
            } catch {
                failures += 1
            }
        }
        return failures
    }

    private func itemNames() throws -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: url.path)
                .filter { !Self.ignoredNames.contains($0) }
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            throw TrashAccessError.permissionDenied
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain && (error.code == Int(EPERM) || error.code == Int(EACCES)) {
            throw TrashAccessError.permissionDenied
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // No ~/.Trash yet (fresh account): that is just an empty Trash.
            return []
        }
    }

    private func allocatedSize(of item: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let values = try? item.resourceValues(forKeys: keys) else { return 0 }
        guard values.isDirectory == true else { return Self.size(from: values) }

        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: item, includingPropertiesForKeys: Array(keys))
        while let child = enumerator?.nextObject() as? URL {
            if let childValues = try? child.resourceValues(forKeys: keys), childValues.isDirectory != true {
                total += Self.size(from: childValues)
            }
        }
        return total
    }

    private static func size(from values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }
}
