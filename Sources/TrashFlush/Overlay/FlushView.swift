import SwiftUI
import TrashFlushCore

/// The flush: a swirling bowl of water with your files spiraling down the drain.
///
/// The bowl is one `Canvas` driven by `TimelineView(.animation)`, which redraws
/// in sync with the display. `drawingGroup()` renders it with Metal, so the
/// CPU only computes about a thousand points per frame.
struct FlushView: View {
    let event: FlushEvent
    let theme: FlushTheme
    let start: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let symbolNames = event.sampleNames.map(FileKind.symbolName(for:))
        let renderer = VortexRenderer(palette: theme.palette, fileCount: symbolNames.count, reduceMotion: reduceMotion)

        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            VStack(spacing: 20) {
                Canvas { context, size in
                    renderer.draw(in: &context, size: size, time: t)
                } symbols: {
                    ForEach(symbolNames.indices, id: \.self) { index in
                        Image(systemName: symbolNames[index])
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                            .tag(index)
                    }
                }
                .frame(width: 380, height: 380)
                .drawingGroup()

                caption
                    .opacity(FlushTimeline.caption(t))
                    .offset(y: 10 * (1 - FlushTimeline.caption(t)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }

    private var caption: some View {
        VStack(spacing: 2) {
            Text(event.itemCount == 1 ? "Flushed 1 item" : "Flushed \(event.itemCount) items")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if event.bytes > 0 {
                Text("\(event.bytes.formatted(.byteCount(style: .file))) freed")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
