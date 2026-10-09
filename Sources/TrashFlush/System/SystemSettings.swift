import AppKit

@MainActor
enum SystemSettings {
    /// Opens Privacy & Security > Full Disk Access.
    static func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Shows the running app in Finder, so it can be dragged into the
    /// Full Disk Access list if it is not there yet.
    static func revealApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}
