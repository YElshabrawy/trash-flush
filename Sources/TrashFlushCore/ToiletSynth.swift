import Foundation

/// The sound of a toilet flush, rendered to line up with its `ToiletTimeline`.
///
/// Clean tones only, like `GulpSynth`. Water is little bubbles: very short
/// sines that glide up, which is the sound a real bubble makes.
/// - A soft pop as the toilet appears.
/// - A "plop" sliding down in pitch for each file landing in the bowl, each a
///   step higher on the same pentatonic scale as the gulps.
/// - The flush: a rush of bubbles over a long, wobbling gurgle that falls in
///   pitch, then the bell arpeggio.
public enum ToiletSynth {
    public static func render(_ timeline: ToiletTimeline, sampleRate: Double = GulpSynth.sampleRate) -> [Float] {
        var out = [Float](repeating: 0, count: Int((timeline.total + 0.6) * sampleRate))

        if !timeline.reduceMotion {
            GulpSynth.addBloop(at: timeline.appear, frequency: 520, gain: 0.18, decay: 0.05, to: &out, sampleRate: sampleRate)
        }

        var plops = 0, sparkles = 0
        for flight in timeline.flights.sorted(by: { $0.arrival < $1.arrival }) {
            let scale = GulpSynth.scale
            if flight.isMini {
                let step = scale[(scale.count - 5) + sparkles % 5]
                addPlop(at: flight.arrival, frequency: GulpSynth.note(step), gain: 0.1, length: 0.07,
                        to: &out, sampleRate: sampleRate)
                sparkles += 1
            } else {
                let step = scale[min(plops, scale.count - 1)]
                addPlop(at: flight.arrival, frequency: GulpSynth.note(step), gain: 0.36, length: 0.13,
                        to: &out, sampleRate: sampleRate)
                plops += 1
            }
        }

        if !timeline.reduceMotion {
            addGurgle(from: timeline.flush, to: timeline.flushed, to: &out, sampleRate: sampleRate)
            var rng = SplitMix64(seed: 42)
            var t = timeline.flush
            while t < timeline.flushed {
                let busy = sin(.pi * (t - timeline.flush) / ToiletTimeline.flushLength)
                GulpSynth.addBloop(at: t, frequency: 600 + 1000 * rng.nextUnit(), gain: 0.05 + 0.06 * busy * rng.nextUnit(),
                                   decay: 0.02, to: &out, sampleRate: sampleRate)
                t += 0.015 + 0.04 * rng.nextUnit()
            }
        }

        for (i, step) in [12, 16, 19].enumerated() {
            GulpSynth.addBell(at: timeline.receiptStart + Double(i) * 0.045, frequency: GulpSynth.note(step), gain: 0.2,
                              to: &out, sampleRate: sampleRate)
        }

        GulpSynth.addEcho(to: &out, delay: 0.11, amount: 0.18, sampleRate: sampleRate)
        GulpSynth.normalize(&out, to: 0.8)
        return out
    }

    /// A drop of pitch from a third above the note to a fifth below it, like
    /// something landing in water.
    private static func addPlop(at start: Double, frequency f: Double, gain: Double, length: Double,
                                to out: inout [Float], sampleRate sr: Double) {
        GulpSynth.render(at: start, length: length * 2.5, into: &out, sampleRate: sr) { t, phase in
            let glide = min(t / length, 1)
            let pitch = f * (1.26 - 0.59 * (1 - pow(1 - glide, 2)))
            phase += 2 * .pi * pitch / sr
            let envelope = min(1, t / 0.006) * exp(-t / (length * 0.6))
            return gain * envelope * (sin(phase) + 0.15 * sin(2 * phase))
        }
    }

    /// The water going down: a low tone sliding down, wobbling as it goes.
    private static func addGurgle(from start: Double, to end: Double, to out: inout [Float], sampleRate sr: Double) {
        let length = end - start
        GulpSynth.render(at: start, length: length + 0.2, into: &out, sampleRate: sr) { t, phase in
            let u = min(t / length, 1)
            phase += 2 * .pi * (300 - 210 * u) / sr
            let wobble = 0.55 + 0.45 * sin(2 * .pi * (10 + 9 * u) * t)
            let envelope = min(1, t / 0.08) * (t < length ? 1 - 0.3 * u : 0.7 * exp(-(t - length) / 0.06))
            return 0.24 * envelope * wobble * sin(phase)
        }
    }
}
