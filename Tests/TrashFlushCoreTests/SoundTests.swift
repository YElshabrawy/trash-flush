import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct SoundTests {
    @Test(arguments: FlushTheme.allCases)
    func everyThemeRendersAnAudibleClipThatDoesNotClip(theme: FlushTheme) {
        let samples = FlushSynth.render(theme.sound, sampleRate: 22_050)
        let peak = samples.reduce(0) { max($0, abs($1)) }
        #expect(samples.count == Int(theme.sound.duration * 22_050))
        #expect(peak > 0.3)
        #expect(peak <= 0.851)
    }

    @Test func renderingIsDeterministic() {
        let recipe = FlushTheme.classic.sound
        #expect(FlushSynth.render(recipe, sampleRate: 8_000) == FlushSynth.render(recipe, sampleRate: 8_000))
    }

    @Test func wavHeaderIsValid() {
        let data = WAVEncoder.encode([0, 0.5, -0.5, 1], sampleRate: 44_100)
        #expect(data.count == 44 + 8)
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: data[36..<40], as: UTF8.self) == "data")
    }
}
