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
        #expect(steps.first?.opacity == 1)
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

    @Test func flightArcsFromTrashIntoBowl() {
        let trash = Flight.Point(x: 300, y: 400)
        let bowl = Flight.Point(x: 150, y: 250)
        let control = Flight.Point(x: 225, y: 100)
        #expect(Flight.position(progress: 0, from: trash, control: control, to: bowl) == trash)
        #expect(Flight.position(progress: 1, from: trash, control: control, to: bowl) == bowl)
        let middle = Flight.position(progress: 0.5, from: trash, control: control, to: bowl)
        #expect(middle.y < bowl.y)
        #expect(Flight.scale(progress: 1) == 1)
        #expect(Flight.scale(progress: 0.5) > 1)
    }

    @Test func timelineRunsInOrder() {
        #expect(FlushTimeline.appear(0) == 0)
        #expect(FlushTimeline.exit(FlushTimeline.total) == 1)
        #expect(FlushTimeline.caption(FlushTimeline.total) == 0)
        #expect(FlushTimeline.waterLevel(0) == 1)
        #expect(FlushTimeline.waterLevel(FlushTimeline.total) == 1)

        for count in [1, 5, 18] {
            let last = count - 1
            #expect(FlushTimeline.flightProgress(index: 0, count: count, at: 0.3) == 0)
            #expect(FlushTimeline.flightProgress(index: last, count: count, at: FlushTimeline.flushStart) == 1)
            #expect(FlushTimeline.sinkProgress(index: 0, count: count, at: FlushTimeline.flushStart) == 0)
            #expect(FlushTimeline.sinkProgress(index: last, count: count, at: 3.4) == 1)
        }
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
}
