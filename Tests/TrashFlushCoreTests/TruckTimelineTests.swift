import Testing
@testable import TrashFlushCore

@Suite struct TruckTimelineTests {
    @Test(arguments: [1, 5, 12, 40, 500])
    func happensInOrder(itemCount: Int) {
        let timeline = TruckTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let lastArrival = timeline.flights.map(\.arrival).max() ?? 0
        #expect(timeline.arrive < timeline.stop)
        #expect(timeline.flights.allSatisfy { $0.start > timeline.stop })
        #expect(timeline.chomps.count == 2)
        #expect(timeline.chomps[0] > lastArrival)
        #expect(timeline.chomps[1] > timeline.chomps[0] + TruckTimeline.chompLength)
        #expect(timeline.depart > timeline.chomps[1] + TruckTimeline.chompLength)
        #expect(timeline.receiptStart > timeline.depart)
        #expect(timeline.total >= timeline.gone)
        #expect(timeline.total >= timeline.receiptEnd)
        #expect(timeline.total < 9)
    }

    @Test func throwsAtMostTwelveFilesThenAStream() {
        let timeline = TruckTimeline(itemCount: 500, peeksTrash: false, reduceMotion: false)
        #expect(timeline.flights.filter { !$0.isMini }.count == NotchTimeline.maxFlights)
        #expect(timeline.flights.filter(\.isMini).count == NotchTimeline.maxStream)
    }

    @Test func drivesInBrakesAndDrivesOff() {
        let timeline = TruckTimeline(itemCount: 3, peeksTrash: false, reduceMotion: false)
        #expect(timeline.approach(at: 0) == 0)
        #expect(timeline.approach(at: timeline.stop) == 1)
        #expect(timeline.departure(at: timeline.depart) == 0)
        #expect(timeline.departure(at: timeline.gone + 0.01) == 1)
        let early = timeline.approach(at: timeline.arrive + 0.2) - timeline.approach(at: timeline.arrive + 0.1)
        let late = timeline.approach(at: timeline.stop - 0.1) - timeline.approach(at: timeline.stop - 0.2)
        #expect(early > late)
    }

    @Test func bouncesAndSettlesWhileStopped() {
        let timeline = TruckTimeline(itemCount: 6, peeksTrash: false, reduceMotion: false)
        let braking = TruckMotion.state(at: timeline.stop + 0.08, timeline: timeline)
        #expect(braking.pitch > 0.5)
        let chomping = TruckMotion.state(at: timeline.chomps[0] + TruckTimeline.chompLength * 0.7, timeline: timeline)
        #expect(chomping.chomp > 0.6)
        let waiting = TruckMotion.state(at: timeline.depart - 0.05, timeline: timeline)
        #expect(abs(waiting.sag) < 1)
        #expect(waiting.chomp < 0.1)
    }

    @Test func showsTheReceipt() {
        let timeline = TruckTimeline(itemCount: 2, peeksTrash: false, reduceMotion: false)
        #expect(TruckMotion.state(at: timeline.receiptStart + 0.6, timeline: timeline).receiptOpacity > 0.95)
        #expect(TruckMotion.state(at: timeline.total, timeline: timeline).receiptOpacity < 0.05)
    }

    @Test func reduceMotionOnlyShowsTheReceipt() {
        let timeline = TruckTimeline(itemCount: 20, peeksTrash: true, reduceMotion: true)
        #expect(timeline.flights.isEmpty)
        #expect(!timeline.peeksTrash)
        #expect(timeline.approach(at: 0) == 1)
        #expect(TruckMotion.state(at: 1, timeline: timeline).receiptOpacity > 0.95)
    }

    @Test(arguments: [1, 12, 40])
    func soundIsAudibleAndDoesNotClip(itemCount: Int) {
        let timeline = TruckTimeline(itemCount: itemCount, peeksTrash: false, reduceMotion: false)
        let samples = TruckSynth.render(timeline, sampleRate: 22_050)
        let peak = samples.reduce(0) { max($0, abs($1)) }
        #expect(samples.count == Int((timeline.total + 0.6) * 22_050))
        #expect(peak > 0.2)
        #expect(peak <= 0.801)
    }
}
