import AppKit
import Observation

/// Follows the Dock's Trash while the flush plays. The Dock slides it along
/// when an app opens or quits, and the files should keep coming out of it.
@MainActor
@Observable
final class TrashTracker {
    /// The Trash's center in the overlay's coordinates.
    private(set) var center: CGPoint

    @ObservationIgnored private var task: Task<Void, Never>?

    init(center: CGPoint, overlay: NSRect) {
        self.center = center
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / 20))
                guard let self else { return }
                guard let trash = DockTrashLocator.locate(), trash.isExact else { continue }
                let frame = trash.frame
                self.center = CGPoint(x: frame.midX - overlay.minX, y: overlay.maxY - frame.midY)
            }
        }
    }

    func stop() {
        task?.cancel()
    }
}
