import AppKit
import SwiftUI
import TrashFlushCore

/// Shows the flush animation beside the Dock's Trash, then removes it.
/// The SwiftUI view is torn down afterwards, so nothing animates while idle.
@MainActor
final class OverlayController {
    private let panel = OverlayPanel()
    private var hideTask: Task<Void, Never>?

    func play(_ event: FlushEvent, icons: [FileIconCache.Icon], theme: FlushTheme) {
        guard let trash = DockTrashLocator.locate() else { return }
        let (frame, scene) = FlushScene.layout(around: trash)
        panel.setFrame(frame, display: false)

        let view = FlushView(event: event, icons: icons, theme: theme, scene: scene, start: .now)
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(FlushTimeline.total + 0.1))
            guard !Task.isCancelled, let self else { return }
            self.panel.orderOut(nil)
            self.panel.contentView = nil
        }
    }
}
