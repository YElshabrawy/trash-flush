import Foundation
import Observation
import TrashFlushCore

/// The app's state and actions. Views read from it; it owns the Trash monitor,
/// the overlay and the sound.
@MainActor
@Observable
final class AppModel {
    let monitor = TrashMonitor()
    private(set) var stats: FlushStats
    private(set) var isEmptying = false
    private(set) var errorMessage: String?
    private(set) var loginItemEnabled = LoginItem.isEnabled
    /// Whether we can ask the Dock exactly where the Trash is (Accessibility).
    private(set) var locatesTrashPrecisely = DockTrashLocator.isPrecise

    var launchAtLogin: Bool {
        get { loginItemEnabled }
        set { setLaunchAtLogin(newValue) }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    private let defaults = UserDefaults.standard
    private let overlay = OverlayController()
    private let sound = SoundPlayer()
    private let icons: FileIconCache

    private enum Keys {
        static let soundEnabled = "soundEnabled"
        static let stats = "stats"
    }

    init() {
        let defaults = UserDefaults.standard
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        stats = defaults.data(forKey: Keys.stats)
            .flatMap { try? JSONDecoder().decode(FlushStats.self, from: $0) } ?? FlushStats()
        icons = FileIconCache(folder: monitor.folder.url)

        monitor.onFlush = { [weak self] event in self?.didFlush(event) }
        monitor.onSnapshot = { [weak self] snapshot in self?.icons.update(for: snapshot) }
        monitor.start()
    }

    var trashSummary: String {
        switch monitor.access {
        case .unknown: return "Checking the Trash…"
        case .denied: return "Needs Full Disk Access"
        case .granted:
            let snapshot = monitor.snapshot
            if snapshot.isEmpty { return "Trash is empty" }
            let items = snapshot.count == 1 ? "1 item" : "\(snapshot.count) items"
            return "\(items) · \(snapshot.totalBytes.formatted(.byteCount(style: .file)))"
        }
    }

    // MARK: Actions

    /// Empties the Trash ourselves. The monitor then sees it go empty and plays
    /// the flush, exactly as if you had used Finder's Empty Trash.
    func flushNow() {
        guard !isEmptying else { return }
        isEmptying = true
        errorMessage = nil
        let folder = monitor.folder
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try folder.removeAll() }
            }.value
            isEmptying = false
            switch result {
            case .success(let failures) where failures > 0:
                errorMessage = failures == 1 ? "1 item couldn't be removed (it may be locked)."
                    : "\(failures) items couldn't be removed (they may be locked)."
            case .success:
                break
            case .failure:
                errorMessage = "Couldn't empty the Trash. Check Full Disk Access."
            }
            monitor.refresh()
        }
    }

    func preview() {
        play(.preview)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't change Launch at Login: \(error.localizedDescription)"
        }
        loginItemEnabled = LoginItem.isEnabled
    }

    func refresh() {
        monitor.refresh()
        loginItemEnabled = LoginItem.isEnabled
        locatesTrashPrecisely = DockTrashLocator.isPrecise
    }

    func allowDockAccess() {
        DockTrashLocator.requestAccess()
        SystemSettings.openAccessibility()
    }

    func resetStats() {
        stats = FlushStats()
        saveStats()
    }

    // MARK: Private

    private func didFlush(_ event: FlushEvent) {
        stats.record(event)
        saveStats()
        play(event)
    }

    private func play(_ event: FlushEvent) {
        guard let timeline = overlay.play(event, icons: icons.icons(for: event.sampleNames)) else { return }
        if soundEnabled { sound.play(timeline) }
    }

    private func saveStats() {
        defaults.set(try? JSONEncoder().encode(stats), forKey: Keys.stats)
    }
}
