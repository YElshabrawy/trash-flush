import Testing
@testable import TrashFlushCore

@Suite struct ToiletTimelineTests {
    @Test(arguments: [1, 5, 12, 40, 500])
    func happensInOrder(itemCount: Int) {
        let timeline = ToiletTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let lastArrival = timeline.flights.map(\.arrival).max() ?? 0
        #expect(timeline.flights.allSatisfy { $0.start > timeline.appear })
        #expect(timeline.flush > lastArrival)
        #expect(timeline.flushed == timeline.flush + ToiletTimeline.flushLength)
        #expect(timeline.leave > timeline.flushed)
        #expect(timeline.receiptStart > timeline.leave)
        #expect(timeline.total >= timeline.receiptEnd)
        #expect(timeline.total < 8)
    }

    @Test func throwsAtMostTwelveFilesThenAStream() {
        let timeline = ToiletTimeline(itemCount: 500, peeksTrash: false, reduceMotion: false)
        #expect(timeline.flights.filter { !$0.isMini }.count == NotchTimeline.maxFlights)
        #expect(timeline.flights.filter(\.isMini).count == NotchTimeline.maxStream)
    }

    @Test func popsUpOvershootsAndShrinksAway() {
        let timeline = ToiletTimeline(itemCount: 3, peeksTrash: false, reduceMotion: false)
        #expect(ToiletMotion.state(at: 0, timeline: timeline).size == 0)
        let sizes = stride(from: timeline.appear, to: timeline.appear + 0.4, by: 0.01).map {
            ToiletMotion.state(at: $0, timeline: timeline).size
        }
        #expect(sizes.max()! > 1.02)
        #expect(abs(ToiletMotion.state(at: timeline.flush, timeline: timeline).size - 1) < 0.05)
        #expect(ToiletMotion.state(at: timeline.leave + 0.6, timeline: timeline).size < 0.05)
    }

    @Test func rumblesOnlyWhileFlushing() {
        let timeline = ToiletTimeline(itemCount: 6, peeksTrash: false, reduceMotion: false)
        #expect(ToiletMotion.state(at: timeline.flush - 0.05, timeline: timeline).rumble == 0)
        #expect(ToiletMotion.state(at: timeline.flushed + 0.05, timeline: timeline).rumble == 0)
        let rumbles = stride(from: timeline.flush, to: timeline.flushed, by: 0.005).map {
            abs(ToiletMotion.state(at: $0, timeline: timeline).rumble)
        }
        #expect(rumbles.max()! > 1.5)
    }

    @Test func showsTheReceipt() {
        let timeline = ToiletTimeline(itemCount: 2, peeksTrash: false, reduceMotion: false)
        #expect(ToiletMotion.state(at: timeline.receiptStart + 0.6, timeline: timeline).receiptOpacity > 0.95)
        #expect(ToiletMotion.state(at: timeline.total, timeline: timeline).receiptOpacity < 0.05)
    }

    @Test func standInTrashPeeksUpAndGoesBack() {
        let timeline = ToiletTimeline(itemCount: 4, peeksTrash: true, reduceMotion: false)
        #expect(ToiletMotion.state(at: 0, timeline: timeline).trashOffset == 1)
        #expect(ToiletMotion.state(at: timeline.flights[0].start, timeline: timeline).trashOffset < 0.1)
        #expect(ToiletMotion.state(at: timeline.trashReturn + 0.8, timeline: timeline).trashOffset > 0.95)
    }

    @Test func reduceMotionOnlyShowsTheReceipt() {
        let timeline = ToiletTimeline(itemCount: 20, peeksTrash: true, reduceMotion: true)
        #expect(timeline.flights.isEmpty)
        #expect(!timeline.peeksTrash)
        let state = ToiletMotion.state(at: 1, timeline: timeline)
        #expect(state.size == 0)
        #expect(state.rumble == 0)
        #expect(state.receiptOpacity > 0.95)
    }

    @Test(arguments: [1, 12, 40])
    func soundIsAudibleAndDoesNotClip(itemCount: Int) {
        let timeline = ToiletTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let samples = ToiletSynth.render(timeline, sampleRate: 22_050)
        let peak = samples.reduce(0) { max($0, abs($1)) }
        #expect(peak > 0.2)
        #expect(peak <= 0.801)
    }
}
