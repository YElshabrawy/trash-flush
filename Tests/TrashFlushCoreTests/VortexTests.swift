import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct VortexTests {
    @Test func particlesSpiralInwardAndSpeedUp() {
        let steps = stride(from: 0.0, through: 1.0, by: 0.05).map {
            Vortex.particle(progress: $0, startAngle: 0, startRadius: 0.9)
        }
        for (a, b) in zip(steps, steps.dropFirst()) {
            #expect(b.radius <= a.radius)
            #expect(b.angle >= a.angle)
        }
        #expect(steps.first?.radius == 0.9)
        #expect(steps.last?.radius == 0)
        #expect(steps.last?.opacity == 0)
        let earlySpin = steps[2].angle - steps[1].angle
        let lateSpin = steps[19].angle - steps[18].angle
        #expect(lateSpin > earlySpin)
    }

    @Test func armsRunFromRimToDrain() {
        #expect(abs(Vortex.armPoint(u: 0, phase: 0).radius - 0.97) < 1e-9)
        #expect(Vortex.armPoint(u: 1, phase: 0).radius == 0)
    }

    @Test func timelineFadesOutCompletely() {
        #expect(FlushTimeline.opacity(0) == 1)
        #expect(FlushTimeline.opacity(FlushTimeline.total) == 0)
        #expect(FlushTimeline.particleProgress(index: 9, count: 10, at: 2.71) == 1)
        #expect(FlushTimeline.particleProgress(index: 0, count: 1, at: 0) == 0)
    }

    @Test func statsAccumulate() {
        var stats = FlushStats()
        stats.record(FlushEvent(itemCount: 3, bytes: 300, sampleNames: []))
        stats.record(FlushEvent(itemCount: 2, bytes: 50, sampleNames: []))
        #expect(stats.flushCount == 2)
        #expect(stats.itemsFlushed == 5)
        #expect(stats.bytesFlushed == 350)
        #expect(stats.lastFlush != nil)
    }

    @Test func fileKindsPickSensibleIcons() {
        #expect(FileKind.symbolName(for: "Holiday.HEIC") == "photo.fill")
        #expect(FileKind.symbolName(for: "Old Project") == "folder.fill")
        #expect(FileKind.symbolName(for: "notes.weird") == "doc.fill")
    }
}
