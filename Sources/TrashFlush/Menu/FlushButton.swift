import SwiftUI

/// "Flush Now" with a two-click confirmation instead of a modal alert: the
/// first click arms it, the second (within 3 seconds) empties the Trash.
struct FlushButton: View {
    let model: AppModel
    @State private var armed = false
    @State private var disarmTask: Task<Void, Never>?

    private var itemCount: Int { model.monitor.snapshot.count }
    private var canFlush: Bool {
        model.monitor.access == .granted && itemCount > 0 && !model.isEmptying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: tap) {
                HStack(spacing: 8) {
                    if model.isEmptying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: armed ? "exclamationmark.triangle.fill" : "drop.fill")
                    }
                    Text(title).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(armed ? .red : .accentColor)
            .disabled(!canFlush)

            if armed {
                Text("Items will be deleted permanently.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: armed)
    }

    private var title: String {
        if model.isEmptying { return "Flushing…" }
        switch model.monitor.access {
        case .denied: return "Grant access to flush"
        case .unknown: return "Flush Now"
        case .granted:
            if itemCount == 0 { return "Nothing to flush" }
            if armed { return itemCount == 1 ? "Click again to flush 1 item" : "Click again to flush \(itemCount) items" }
            return "Flush Now"
        }
    }

    private func tap() {
        disarmTask?.cancel()
        if armed {
            armed = false
            model.flushNow()
        } else {
            armed = true
            disarmTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { armed = false }
            }
        }
    }
}
