import Darwin
import Foundation

public enum DiskUsage {
    /// Space a file or folder takes on disk, like `du`.
    ///
    /// Folders are read with `getattrlistbulk`, which hands back a whole
    /// directory's names, types and sizes in a few calls instead of one `stat`
    /// per file, and subfolders are walked in parallel. On a cache folder with
    /// millions of files that's several times faster than `fts` or
    /// `FileManager`.
    public static func allocatedSize(of url: URL) async -> Int64 {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return 0 }
        guard info.st_mode & S_IFMT == S_IFDIR else { return Int64(info.st_blocks) * 512 }
        return await walk(url.path)
    }

    private static func walk(_ path: String) async -> Int64 {
        guard !Task.isCancelled else { return 0 }
        let (files, folders) = read(path)
        if folders.isEmpty { return files }
        return await withTaskGroup(of: Int64.self) { group in
            for folder in folders {
                group.addTask { await walk(folder) }
            }
            var total = files
            for await size in group { total += size }
            return total
        }
    }

    private static let returnedAttributes: attrgroup_t = 0x8000_0000 // ATTR_CMN_RETURNED_ATTRS
    private static let packInvalid: UInt64 = 0x8 // FSOPT_PACK_INVAL_ATTRS
    private static let bufferSize = 128 * 1024

    /// The total size of the files directly in `path`, and its subfolders.
    private static func read(_ path: String) -> (bytes: Int64, folders: [String]) {
        let fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { return (0, []) }
        defer { close(fd) }

        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.commonattr = returnedAttributes | attrgroup_t(ATTR_CMN_NAME) | attrgroup_t(ATTR_CMN_OBJTYPE)
        request.fileattr = attrgroup_t(ATTR_FILE_ALLOCSIZE)

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: bufferSize, alignment: 8)
        defer { buffer.deallocate() }

        var bytes: Int64 = 0
        var folders: [String] = []
        while true {
            let count = getattrlistbulk(fd, &request, buffer, bufferSize, packInvalid)
            guard count > 0 else { break }
            var entry = buffer
            for _ in 0..<count {
                // Every attribute is packed, so each sits at a fixed offset:
                // length, the returned attribute set (5 × UInt32), the name's
                // reference, the object type, then the file's allocated size.
                let length = entry.loadUnaligned(as: UInt32.self)
                let nameRef = entry + 24
                let type = entry.loadUnaligned(fromByteOffset: 32, as: UInt32.self)
                if type == VDIR.rawValue {
                    let name = String(cString: (nameRef + Int(nameRef.loadUnaligned(as: Int32.self)))
                        .assumingMemoryBound(to: CChar.self))
                    folders.append(path + "/" + name)
                } else {
                    bytes += entry.loadUnaligned(fromByteOffset: 36, as: Int64.self)
                }
                entry += Int(length)
            }
        }
        return (bytes, folders)
    }
}
