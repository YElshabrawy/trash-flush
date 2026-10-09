import AppKit
import QuickLookThumbnailing
import TrashFlushCore
import UniformTypeIdentifiers

/// The real icons of the files in the Trash, as Finder shows them.
///
/// They are captured while the files are still there: by the time we notice
/// the Trash was emptied, the files (and their icons) are gone. Photos, PDFs
/// and other documents get a Quick Look preview of their content; everything
/// else keeps its Finder icon.
@MainActor
final class FileIconCache {
    struct Icon {
        var image: NSImage
        /// A preview of the content rather than an icon, so it gets a frame.
        var isThumbnail: Bool
    }

    private let folder: URL
    private var icons: [String: Icon] = [:]
    private var loading: Set<String> = []

    init(folder: URL) {
        self.folder = folder
    }

    /// Captures icons for the files a flush of this snapshot would show.
    func update(for snapshot: TrashSnapshot) {
        let names = FlushEvent(flushing: snapshot).sampleNames
        if snapshot.isEmpty || icons.count > 100 {
            icons = icons.filter { names.contains($0.key) }
        }
        for name in names where icons[name] == nil {
            load(name)
        }
    }

    func icons(for names: [String]) -> [Icon] {
        names.map { icons[$0] ?? Self.genericIcon(for: $0) }
    }

    /// The standard icon for a file's type, for files we never saw (and the preview).
    static func genericIcon(for name: String) -> Icon {
        let ext = (name as NSString).pathExtension
        let type = ext.isEmpty ? UTType.folder : UTType(filenameExtension: ext) ?? .data
        return Icon(image: NSWorkspace.shared.icon(for: type), isThumbnail: false)
    }

    private func load(_ name: String) {
        let url = folder.appendingPathComponent(name)
        icons[name] = Icon(image: NSWorkspace.shared.icon(forFile: url.path), isThumbnail: false)

        guard loading.insert(name).inserted else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 64, height: 64),
                                                   scale: 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            let image = thumbnail?.cgImage
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loading.remove(name)
                guard let image, self.icons[name] != nil else { return }
                self.icons[name] = Icon(image: NSImage(cgImage: image, size: .zero), isThumbnail: true)
            }
        }
    }
}
