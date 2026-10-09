import SwiftUI
import TrashFlushCore

/// The flush: a toilet rises beside the Dock's Trash, your files arc into it,
/// and it flushes them away.
///
/// Everything is one `Canvas` driven by `TimelineView(.animation)`, which
/// redraws in sync with the display. `drawingGroup()` renders it with Metal.
struct FlushView: View {
    let event: FlushEvent
    /// One per name in `event.sampleNames`.
    let icons: [FileIconCache.Icon]
    let theme: FlushTheme
    let scene: FlushScene
    let start: Date

    /// More than this and the bowl gets crowded.
    private static let maxFiles = 12

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let icons = Array(icons.prefix(Self.maxFiles))
        let renderer = ToiletRenderer(palette: theme.palette, scene: scene,
                                      fileCount: icons.count, reduceMotion: reduceMotion)

        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    renderer.draw(in: &context, time: t)
                } symbols: {
                    ForEach(icons.indices, id: \.self) { index in
                        FileIconView(icon: icons[index])
                            .tag(index)
                    }
                }
                .drawingGroup()

                caption
                    .fixedSize()
                    .position(scene.captionCenter)
                    .opacity(FlushTimeline.caption(t))
                    .offset(y: 8 * (1 - FlushTimeline.caption(t)))
            }
            .frame(width: scene.size.width, height: scene.size.height)
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
    }

    private var caption: some View {
        VStack(spacing: 2) {
            Text(event.itemCount == 1 ? "Flushed 1 item" : "Flushed \(event.itemCount) items")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            if event.bytes > 0 {
                Text("\(event.bytes.formatted(.byteCount(style: .file))) freed")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// A file as Finder shows it: its icon, or a content preview in a thin white
/// frame for photos and documents.
private struct FileIconView: View {
    let icon: FileIconCache.Icon

    var body: some View {
        if icon.isThumbnail {
            Image(nsImage: icon.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(1.5)
                .background(.white, in: RoundedRectangle(cornerRadius: 3))
                .frame(maxWidth: 28, maxHeight: 28)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        } else {
            Image(nsImage: icon.image)
                .resizable()
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }
}
