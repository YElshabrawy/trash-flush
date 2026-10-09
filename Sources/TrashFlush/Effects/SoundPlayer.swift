import AVFoundation
import TrashFlushCore

/// Plays the synthesized flush sound for a theme. Each theme's clip is rendered
/// once (a few milliseconds) and kept as an in-memory WAV of about 300 KB.
@MainActor
final class SoundPlayer {
    private var clips: [FlushTheme: Data] = [:]
    private var player: AVAudioPlayer?

    /// Renders a theme's clip in the background so the first flush plays instantly.
    func prepare(_ theme: FlushTheme) {
        guard clips[theme] == nil else { return }
        Task {
            let data = await Task.detached(priority: .utility) { Self.render(theme) }.value
            clips[theme] = data
        }
    }

    func play(_ theme: FlushTheme) {
        let data = clips[theme] ?? Self.render(theme)
        clips[theme] = data
        player?.stop()
        player = try? AVAudioPlayer(data: data)
        player?.volume = 0.8
        player?.play()
    }

    private nonisolated static func render(_ theme: FlushTheme) -> Data {
        WAVEncoder.encode(FlushSynth.render(theme.sound))
    }
}
