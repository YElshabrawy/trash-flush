import AppKit
import SwiftUI
import TrashFlushCore

/// "Find Junk" in the menu panel: one click scans, you review the list and
/// move what you picked to the Trash, ready to flush.
struct SuggestionsSection: View {
    @Bindable var suggestions: FlushSuggestions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch suggestions.phase {
            case .idle:
                findButton
            case .scanning, .review, .moving:
                results
            case .moved(let bytes, let failures):
                moved(bytes: bytes, failures: failures)
            }
        }
        .animation(.snappy, value: suggestions.phase)
        .animation(.snappy, value: suggestions.categories)
    }

    private var findButton: some View {
        Button { suggestions.start() } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Find Junk").fontWeight(.semibold)
                    Text("Old installers and screenshots, Xcode leftovers, big caches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Junk").font(.headline)
                if suggestions.phase == .scanning {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Button("Cancel") { suggestions.cancel() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }

            if suggestions.isEmpty {
                Text("Nothing to clean up. Nice and tidy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(suggestions.categories, id: \.self) { category in
                            CategoryRows(suggestions: suggestions, category: category)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !suggestions.isEmpty {
                Button(action: suggestions.moveSelectedToTrash) {
                    HStack(spacing: 6) {
                        if suggestions.phase == .moving { ProgressView().controlSize(.small) }
                        Text(moveTitle).fontWeight(.semibold).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(suggestions.phase != .review || suggestions.selected.isEmpty)
            }
        }
    }

    private var moveTitle: String {
        switch suggestions.phase {
        case .moving: return "Moving to Trash…"
        case .scanning: return "Looking…"
        default:
            let count = suggestions.selected.count
            guard count > 0 else { return "Nothing selected" }
            return "Move \(suggestions.selectedBytes.formatted(.byteCount(style: .file))) to Trash"
        }
    }

    private func moved(bytes: Int64, failures: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Moved \(bytes.formatted(.byteCount(style: .file))) to the Trash").fontWeight(.semibold)
                Text(failures == 0 ? "Flush it to free the space." :
                     "Flush it to free the space. \(failures) couldn't be moved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Done") { suggestions.cancel() }
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
    }
}

/// A category's header, a checkbox for all of it, and its items when expanded.
private struct CategoryRows: View {
    @Bindable var suggestions: FlushSuggestions
    let category: JunkCategory

    private var items: [JunkItem] { suggestions.items[category] ?? [] }
    private var isExpanded: Bool { suggestions.expanded.contains(category) }

    var body: some View {
        let chosen = items.filter { suggestions.selected.contains($0.url) }.count
        HStack(spacing: 6) {
            Checkbox(state: chosen == 0 ? .off : chosen == items.count ? .on : .mixed) {
                suggestions.toggle(category)
            }
            Button {
                if isExpanded { suggestions.expanded.remove(category) } else { suggestions.expanded.insert(category) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: category.symbol)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text(category.title)
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(suggestions.bytes(in: category).formatted(.byteCount(style: .file)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)

        if isExpanded {
            ForEach(items) { item in
                ItemRow(item: item, isSelected: suggestions.selected.contains(item.url)) {
                    suggestions.toggle(item)
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: JunkItem
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Checkbox(state: isSelected ? .on : .off, action: toggle)
            Image(nsImage: JunkLabels.icon(for: item))
                .resizable()
                .frame(width: 16, height: 16)
            Text(JunkLabels.title(for: item))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            Text(item.bytes.formatted(.byteCount(style: .file)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.leading, 22)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        .help(item.url.path)
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
        }
    }
}

private struct Checkbox: View {
    enum State { case on, off, mixed }
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
            .foregroundStyle(state == .off ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch state {
        case .on: "checkmark.square.fill"
        case .mixed: "minus.square.fill"
        case .off: "square"
        }
    }
}

extension JunkCategory {
    var title: String {
        switch self {
        case .installers: "Old installers"
        case .screenshots: "Old screenshots"
        case .xcode: "Xcode leftovers"
        case .caches: "Big caches"
        }
    }

    var symbol: String {
        switch self {
        case .installers: "shippingbox"
        case .screenshots: "camera.viewfinder"
        case .xcode: "hammer"
        case .caches: "archivebox"
        }
    }
}

/// Names and icons for the list. Cache folders are named after their app's
/// bundle ID, so they get the app's name and icon instead.
@MainActor
private enum JunkLabels {
    private static var apps: [String: URL?] = [:]
    private static var icons: [URL: NSImage] = [:]

    static func title(for item: JunkItem) -> String {
        guard item.category == .caches, let app = app(for: item) else { return item.title }
        return FileManager.default.displayName(atPath: app.path).replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for item: JunkItem) -> NSImage {
        let source = (item.category == .caches ? app(for: item) : nil) ?? item.url
        if let icon = icons[source] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: source.path)
        icons[source] = icon
        return icon
    }

    private static func app(for item: JunkItem) -> URL? {
        if let known = apps[item.title] { return known }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.title)
        apps[item.title] = url
        return url
    }
}
