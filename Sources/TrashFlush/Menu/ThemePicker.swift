import SwiftUI
import TrashFlushCore

/// A row of colored swatches, one per theme.
struct ThemePicker: View {
    @Binding var selection: FlushTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(FlushTheme.allCases) { theme in
                    swatch(theme)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func swatch(_ theme: FlushTheme) -> some View {
        let isSelected = theme == selection
        return Button {
            selection = theme
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(RadialGradient(colors: [theme.palette.deep, theme.palette.water, theme.palette.shallow],
                                         center: .center, startRadius: 0, endRadius: 15))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
                    .padding(3)
                    .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
