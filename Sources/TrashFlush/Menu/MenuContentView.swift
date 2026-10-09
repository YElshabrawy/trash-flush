import AppKit
import SwiftUI
import TrashFlushCore

/// The panel that opens from the menu bar icon.
struct MenuContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if model.monitor.access == .denied {
                AccessBanner { model.refresh() }
            }

            FlushButton(model: model)

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            StatsGrid(stats: model.stats) { model.resetStats() }

            Divider()

            ThemePicker(selection: $model.theme)

            VStack(spacing: 8) {
                SettingRow(title: "Flush sound", isOn: $model.soundEnabled)
                SettingRow(title: "Launch at login", isOn: $model.launchAtLogin)
                    .disabled(!LoginItem.isAvailable)
                    .help(LoginItem.isAvailable ? Text("Start Trash Flush when you log in")
                                                : Text("Available when running the built TrashFlush.app"))
                if !model.locatesTrashPrecisely {
                    HStack {
                        Text("Exact Dock Trash position")
                        Spacer()
                        Button("Allow…") { model.allowDockAccess() }
                            .controlSize(.small)
                    }
                    .help("The toilet appears next to the Trash in your Dock. Without Accessibility access its position is estimated.")
                }
            }

            Divider()

            HStack {
                Button("Preview Animation", systemImage: "play.circle") { model.preview() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { model.refresh() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: AppSymbol.toilet)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(model.theme.palette.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Trash Flush").font(.headline)
                Text(model.trashSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
    }
}

/// A label on the left, a small switch on the right.
private struct SettingRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
