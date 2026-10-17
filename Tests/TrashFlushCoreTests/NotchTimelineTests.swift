import Foundation
import Testing
@testable import TrashFlushCore

@Suite struct NotchTimelineTests {
    @Test(arguments: [1, 5, 12, 13, 100])
    func filesLaunchInOrderAndTheIslandWaitsForTheLast(itemCount: Int) {
        let timeline = NotchTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let main = timeline.flights.filter { !$0.isMini }
        let stream = timeline.flights.filter(\.isMini)
        #expect(main.count == min(itemCount, NotchTimeline.maxFlights))
        #expect(stream.count == min(max(itemCount - NotchTimeline.maxFlights, 0), NotchTimeline.maxStream))
        for (a, b) in zip(timeline.flights, timeline.flights.dropFirst()) {
            #expect(a.start < b.start)
        }
        let lastArrival = timeline.flights.map(\.arrival).max()!
        #expect(timeline.islandStart > lastArrival)
        #expect(timeline.contentStart < timeline.contentEnd)
        #expect(timeline.collapse < timeline.total)
    }

    @Test func peekingTrashDelaysTheFirstLaunch() {
        let shown = NotchTimeline(itemCount: 3, peeksTrash: false, reduceMotion: false)
        let hidden = NotchTimeline(itemCount: 3, peeksTrash: true, reduceMotion: false)
        #expect(hidden.flights[0].start > shown.flights[0].start)
        #expect(hidden.trashReturn > hidden.flights.last!.start)
    }

    @Test func reduceMotionShowsOnlyTheIsland() {
        let timeline = NotchTimeline(itemCount: 12, peeksTrash: true, reduceMotion: true)
        #expect(timeline.flights.isEmpty)
        #expect(timeline.confettiStart == nil)
        #expect(!timeline.peeksTrash)
    }

    @Test func notchOpensForEachFileThenBecomesTheIslandAndSettlesBack() {
        let timeline = NotchTimeline(itemCount: 6, peeksTrash: false, reduceMotion: false)
        let style = NotchStyle.notch(width: 200, height: 32)

        #expect(NotchMotion.state(at: 0, timeline: timeline, style: style).size == style.rest)

        let firstAlmostIn = timeline.flights[0].start + timeline.flights[0].duration * 0.8
        #expect(NotchMotion.shape(at: firstAlmostIn, timeline: timeline, style: style) == style.mouth)

        let island = NotchMotion.state(at: timeline.contentEnd - 0.1, timeline: timeline, style: style)
        #expect(abs(island.size.width - style.island.width) < 1)
        #expect(abs(island.size.height - style.island.height) < 1)
        #expect(island.contentOpacity > 0.99)

        let end = NotchMotion.state(at: timeline.total, timeline: timeline, style: style)
        #expect(abs(end.size.width - style.rest.width) < 2)
        #expect(end.contentOpacity < 0.01)
    }

    @Test func pillAppearsOnlyDuringTheAnimation() {
        let timeline = NotchTimeline(itemCount: 3, peeksTrash: false, reduceMotion: false)
        #expect(NotchMotion.state(at: 0, timeline: timeline, style: .pill).opacity == 0)
        #expect(NotchMotion.state(at: timeline.islandStart, timeline: timeline, style: .pill).opacity > 0.99)
        #expect(NotchMotion.state(at: timeline.total + 0.5, timeline: timeline, style: .pill).opacity < 0.05)
    }

    @Test func standInTrashPeeksAndReturns() {
        let timeline = NotchTimeline(itemCount: 4, peeksTrash: true, reduceMotion: false)
        let style = NotchStyle.notch(width: 200, height: 32)
        #expect(NotchMotion.state(at: 0, timeline: timeline, style: style).trashOffset == 1)
        #expect(abs(NotchMotion.state(at: timeline.flights[0].start, timeline: timeline, style: style).trashOffset) < 0.1)
        #expect(NotchMotion.state(at: timeline.total, timeline: timeline, style: style).trashOffset > 0.95)
    }

    @Test func trashOnlyPuffsUpAndSettles() {
        let timeline = NotchTimeline(itemCount: 6, peeksTrash: false, reduceMotion: false)
        let style = NotchStyle.notch(width: 200, height: 32)
        let samples = stride(from: 0.0, through: timeline.total, by: 0.01).map {
            NotchMotion.state(at: $0, timeline: timeline, style: style).trashPuff
        }
        #expect(samples.allSatisfy { $0 >= 0 })
        #expect(NotchMotion.state(at: timeline.flights[0].start + 0.06, timeline: timeline, style: style).trashPuff > 0.05)
        #expect(samples.last! < 0.01)
    }

    @Test func filesClimbOutOfTheTrashBeforeTheyLaunch() {
        let flight = NotchTimeline(itemCount: 1, peeksTrash: false, reduceMotion: false).flights[0]
        #expect(flight.start - NotchTimeline.emergeDuration >= 0)
        #expect(flight.emergence(at: flight.start - NotchTimeline.emergeDuration) == 0)
        #expect(flight.emergence(at: flight.start) == 1)
        #expect(flight.progress(at: flight.start) == 0)
    }

    @Test func flightsRunFromTrashToNotch() {
        let trash = FlightPath.Point(x: 1100, y: 940)
        let notch = FlightPath.Point(x: 756, y: 14)
        let control = FlightPath.control(index: 0, from: trash, to: notch, away: .init(x: 0, y: -1), isMini: false)
        #expect(FlightPath.position(progress: 0, from: trash, control: control, to: notch) == trash)
        #expect(FlightPath.position(progress: 1, from: trash, control: control, to: notch) == notch)
        #expect(FlightPath.scale(progress: 1, isMini: false) < 0.35)
        #expect(FlightPath.scale(progress: 0.5, isMini: false) == 1)
        for u in stride(from: 0.0, to: 1.0, by: 0.01) {
            #expect(FlightPath.eased(u + 0.01) > FlightPath.eased(u))
        }
    }

    @Test func neighbouringFilesFanOutToOppositeSides() {
        let trash = FlightPath.Point(x: 756, y: 940)
        let notch = FlightPath.Point(x: 756, y: 14)
        let left = FlightPath.control(index: 0, from: trash, to: notch, away: .init(x: 0, y: -1), isMini: false)
        let right = FlightPath.control(index: 1, from: trash, to: notch, away: .init(x: 0, y: -1), isMini: false)
        #expect((left.x - 756) * (right.x - 756) < 0)
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
