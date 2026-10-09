import AppKit
import SwiftUI
import TrashFlushCore

/// Shows the flush animation on the display you are using, then removes it.
/// The SwiftUI view is torn down afterwards, so nothing animates while idle.
@MainActor
final class OverlayController {
    private let panel = OverlayPanel()
    private var hideTask: Task<Void, Never>?

    static let size = CGSize(width: 420, height: 500)

    func play(_ event: FlushEvent, theme: FlushTheme) {
        guard let screen = Self.screenUnderPointer() else { return }

        let frame = screen.visibleFrame
        panel.setFrame(NSRect(x: frame.midX - Self.size.width / 2,
                              y: frame.midY - Self.size.height / 2,
                              width: Self.size.width, height: Self.size.height),
                       display: false)

        let view = FlushView(event: event, theme: theme, start: .now)
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

    private static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first
    }
}
