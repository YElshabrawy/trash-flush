import SwiftUI
import TrashFlushCore

struct StatsGrid: View {
    let stats: FlushStats
    let onReset: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                tile(value: stats.flushCount.formatted(), label: "Flushes")
                tile(value: stats.itemsFlushed.formatted(), label: "Items")
                tile(value: stats.bytesFlushed.formatted(.byteCount(style: .file)), label: "Freed")
            }
            Text(lastFlushText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Reset Stats", role: .destructive) { onReset() }
        }
    }

    private var lastFlushText: String {
        guard let last = stats.lastFlush else { return "No flushes yet. Empty the Trash to try it." }
        return "Last flush \(last.formatted(.relative(presentation: .named)))"
    }

    private func tile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
