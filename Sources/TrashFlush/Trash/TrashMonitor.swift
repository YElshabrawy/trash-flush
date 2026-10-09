import Foundation
import Observation
import TrashFlushCore

/// Watches ~/.Trash and reports when it gets emptied.
///
/// It is event-driven: the kernel wakes us up (via a dispatch source on the
/// folder) only when the Trash changes. Between changes it uses no CPU at all.
@MainActor
@Observable
final class TrashMonitor {
    enum Access {
        case unknown
        case granted
        /// macOS blocked access. The user must grant Full Disk Access.
        case denied
    }

    private(set) var access: Access = .unknown
    private(set) var snapshot: TrashSnapshot = .empty
    /// Called on the main actor when the Trash goes from full to empty.
    @ObservationIgnored var onFlush: ((FlushEvent) -> Void)?

    let folder: TrashFolder
    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var detector = FlushDetector()
    @ObservationIgnored private var pendingScan: Task<Void, Never>?
    @ObservationIgnored private var isScanning = false
    @ObservationIgnored private var needsRescan = false

    init(folder: TrashFolder = .user) {
        self.folder = folder
    }

    func start() {
        startWatching()
        scheduleScan(after: .zero)
    }

    /// Checks again right away, e.g. after the user granted Full Disk Access.
    func refresh() {
        if source == nil { startWatching() }
        scheduleScan(after: .zero)
    }

    private func startWatching() {
        let fd = open(folder.url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let source = self.source else { return }
                // If the Trash folder itself was replaced, watch the new one.
                if !source.data.isDisjoint(with: [.delete, .rename]) {
                    self.stopWatching()
                    self.startWatching()
                }
                self.scheduleScan()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func stopWatching() {
        source?.cancel()
        source = nil
    }

    /// Finder changes the Trash in bursts (one event per deleted item), so we
    /// wait for a short quiet moment and scan once.
    private func scheduleScan(after delay: Duration = .milliseconds(350)) {
        pendingScan?.cancel()
        pendingScan = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.scan()
        }
    }

    private func scan() async {
        guard !isScanning else {
            needsRescan = true
            return
        }
        isScanning = true
        defer { isScanning = false }

        repeat {
            needsRescan = false
            await scanOnce()
        } while needsRescan
    }

    private func scanOnce() async {
        let folder = folder
        let previous = snapshot
        // Listing and measuring files is blocking I/O: keep it off the main thread.
        let result = await Task.detached(priority: .utility) {
            Result { try folder.snapshot(reusing: previous) }
        }.value

        switch result {
        case .success(let newSnapshot):
            access = .granted
            snapshot = newSnapshot
            if let event = detector.observe(newSnapshot) {
                onFlush?(event)
            }
        case .failure:
            access = .denied
        }
    }
}
