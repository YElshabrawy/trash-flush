import AVFoundation
import TrashFlushCore

/// Plays the synthesized gulps for one flush. The clip is rendered to match
/// that flush's timeline (a few milliseconds) and played from memory as a WAV.
@MainActor
final class SoundPlayer {
    private var player: AVAudioPlayer?

    func play(_ timeline: NotchTimeline) {
        player?.stop()
        player = try? AVAudioPlayer(data: WAVEncoder.encode(GulpSynth.render(timeline)))
        player?.volume = 0.8
        player?.play()
    }
}
