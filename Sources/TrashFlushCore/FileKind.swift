import Foundation

/// Picks an SF Symbol for a trashed file, so the animation shows photos, songs
/// and folders going down instead of generic blobs.
public enum FileKind {
    public static func symbolName(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "": return "folder.fill"
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "tif", "webp", "raw": return "photo.fill"
        case "mov", "mp4", "m4v", "avi", "mkv": return "film.fill"
        case "mp3", "m4a", "wav", "aiff", "flac": return "music.note"
        case "zip", "gz", "tar", "rar", "7z", "dmg", "pkg": return "archivebox.fill"
        case "app": return "app.fill"
        case "pdf": return "doc.richtext.fill"
        case "swift", "js", "ts", "py", "rb", "c", "h", "json", "html", "css": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.fill"
        }
    }
}
