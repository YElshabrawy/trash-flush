import AVFoundation
import TrashFlushCore

/// Plays the synthesized sound for one flush. The clip is rendered to match
/// that flush's timeline (a few milliseconds) and played from memory as a WAV.
@MainActor
final class SoundPlayer {
    private var player: AVAudioPlayer?

    func play(_ timeline: any FlushTimeline) {
        player?.stop()
        player = try? AVAudioPlayer(data: WAVEncoder.encode(timeline.soundtrack()))
        player?.volume = 0.8
        player?.play()
    }
}
