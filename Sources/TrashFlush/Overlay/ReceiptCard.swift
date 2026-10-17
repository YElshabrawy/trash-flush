import SwiftUI
import TrashFlushCore

/// "Picked up 12 items · 734 MB freed" on a black card that pops up near the
/// Dock at the end of the truck and the flush.
struct ReceiptCard: View {
    nonisolated static let size = CGSize(width: 300, height: 64)

    let event: FlushEvent
    let icons: [FileIconCache.Icon]
    let verb: String
    /// 0 hidden, 1 shown.
    let opacity: Double

    var body: some View {
        IslandContent(event: event, icons: Array(icons.prefix(3)), verb: verb)
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 20)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .scaleEffect(0.85 + 0.15 * opacity)
            .blur(radius: (1 - opacity) * 5)
            .opacity(opacity)
    }

    /// `point`, moved just enough to keep the whole card on the screen.
    nonisolated static func clamped(_ point: CGPoint, in screen: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x, size.width / 2 + 12), screen.width - size.width / 2 - 12),
                y: min(max(point.y, size.height / 2 + 12), screen.height - size.height / 2 - 12))
    }
}
