import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct SoundTests {
    @Test(arguments: [1, 12, 40])
    func rendersAnAudibleClipThatDoesNotClip(itemCount: Int) {
        let timeline = NotchTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let samples = GulpSynth.render(timeline, sampleRate: 22_050)
        let peak = samples.reduce(0) { max($0, abs($1)) }
        #expect(samples.count == Int((timeline.total + 0.6) * 22_050))
        #expect(peak > 0.2)
        #expect(peak <= 0.801)
    }

    @Test func isSilentBeforeTheFirstFileLeaves() {
        let timeline = NotchTimeline(itemCount: 5, peeksTrash: true, reduceMotion: false)
        let samples = GulpSynth.render(timeline, sampleRate: 8_000)
        let firstLaunch = Int(timeline.flights[0].start * 8_000)
        #expect(samples[..<firstLaunch].allSatisfy { $0 == 0 })
    }

    @Test func gulpsClimbTheScale() {
        #expect(GulpSynth.scale == GulpSynth.scale.sorted())
        #expect(GulpSynth.scale.count == NotchTimeline.maxFlights)
        #expect(abs(GulpSynth.note(12) - 2 * GulpSynth.note(0)) < 1e-9)
    }

    @Test func renderingIsDeterministic() {
        let timeline = NotchTimeline(itemCount: 12, peeksTrash: false, reduceMotion: false)
        #expect(GulpSynth.render(timeline, sampleRate: 8_000) == GulpSynth.render(timeline, sampleRate: 8_000))
    }

    @Test func wavHeaderIsValid() {
        let data = WAVEncoder.encode([0, 0.5, -0.5, 1], sampleRate: 44_100)
        #expect(data.count == 44 + 8)
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: data[36..<40], as: UTF8.self) == "data")
    }
}
