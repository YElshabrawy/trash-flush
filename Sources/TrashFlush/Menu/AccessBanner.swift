import SwiftUI

/// Explains why we need Full Disk Access and links straight to the setting.
struct AccessBanner: View {
    let onCheckAgain: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Full Disk Access needed", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
            Text("macOS protects the Trash folder. Turn on Trash Flush in Privacy & Security › Full Disk Access, then check again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Settings") { SystemSettings.openFullDiskAccess() }
                Button("Show App") { SystemSettings.revealApp() }
                Spacer()
                Button("Check Again") { onCheckAgain() }
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
