import AppKit
import SwiftUI
import TrashFlushCore

/// Shows the flush over the screen with the Dock, then removes it.
/// The SwiftUI view is torn down afterwards, so nothing animates while idle.
@MainActor
final class OverlayController {
    private let panel = OverlayPanel()
    private var hideTask: Task<Void, Never>?
    private var tracker: TrashTracker?

    /// Starts the animation and returns its timeline, so the sound can follow it.
    func play(_ event: FlushEvent, icons: [FileIconCache.Icon]) -> NotchTimeline? {
        guard let trash = DockTrashLocator.locate() else { return nil }
        let (frame, scene) = NotchScene.layout(around: trash)
        let timeline = NotchTimeline(itemCount: event.itemCount, peeksTrash: scene.peeksTrash,
                                     reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        panel.setFrame(frame, display: false)

        tracker?.stop()
        let tracker = trash.isExact && !trash.isAutoHidden ? TrashTracker(center: scene.trash, overlay: frame) : nil
        self.tracker = tracker

        let view = NotchFlushView(event: event, icons: icons, scene: scene, timeline: timeline, start: .now,
                                  tracker: tracker)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeline.total + 0.1))
            guard !Task.isCancelled, let self else { return }
            self.tracker?.stop()
            self.tracker = nil
            self.panel.orderOut(nil)
            self.panel.contentView = nil
        }
        return timeline
    }
}
