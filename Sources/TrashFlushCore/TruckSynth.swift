import Foundation

/// The sound of a garbage truck pickup, rendered to line up with its `TruckTimeline`.
///
/// Clean tones only, like `GulpSynth`:
/// - A soft engine rumble that idles while the truck is stopped and revs as it leaves.
/// - A wooden "tok" for each file landing in the hopper, climbing the same
///   pentatonic scale an octave lower than the gulps.
/// - Two deep clunks for the chomps, a friendly "beep beep", and the bell
///   arpeggio when the receipt pops up.
public enum TruckSynth {
    /// Renders mono samples in -1...1.
    public static func render(_ timeline: TruckTimeline, sampleRate: Double = GulpSynth.sampleRate) -> [Float] {
        var out = [Float](repeating: 0, count: Int((timeline.total + 0.6) * sampleRate))

        if !timeline.reduceMotion {
            addEngine(timeline, to: &out, sampleRate: sampleRate)
            GulpSynth.addThump(at: timeline.stop, to: &out, sampleRate: sampleRate)
        }

        var toks = 0, sparkles = 0
        for flight in timeline.flights.sorted(by: { $0.arrival < $1.arrival }) {
            let scale = GulpSynth.scale
            if flight.isMini {
                let step = scale[(scale.count - 5) + sparkles % 5]
                GulpSynth.addBloop(at: flight.arrival, frequency: GulpSynth.note(step) / 2, gain: 0.1, decay: 0.04,
                                   to: &out, sampleRate: sampleRate)
                sparkles += 1
            } else {
                let step = scale[min(toks, scale.count - 1)]
                GulpSynth.addBloop(at: flight.arrival, frequency: GulpSynth.note(step) / 2, gain: 0.34, decay: 0.07,
                                   to: &out, sampleRate: sampleRate)
                toks += 1
            }
        }

        for chomp in timeline.chomps {
            let shut = chomp + TruckTimeline.chompLength * 0.6
            GulpSynth.addThump(at: shut, to: &out, sampleRate: sampleRate)
            GulpSynth.addBloop(at: shut, frequency: 98, gain: 0.35, decay: 0.06, to: &out, sampleRate: sampleRate)
        }

        if !timeline.reduceMotion {
            addBeep(at: timeline.depart - 0.3, to: &out, sampleRate: sampleRate)
            addBeep(at: timeline.depart - 0.15, to: &out, sampleRate: sampleRate)
        }

        for (i, step) in [12, 16, 19].enumerated() {
            GulpSynth.addBell(at: timeline.receiptStart + Double(i) * 0.045, frequency: GulpSynth.note(step), gain: 0.2,
                              to: &out, sampleRate: sampleRate)
        }

        GulpSynth.addEcho(to: &out, delay: 0.11, amount: 0.18, sampleRate: sampleRate)
        GulpSynth.normalize(&out, to: 0.8)
        return out
    }

    /// A low hum with a gentle putter: louder while driving, quieter at idle,
    /// rising in pitch as the truck pulls away and fading as it leaves.
    private static func addEngine(_ timeline: TruckTimeline, to out: inout [Float], sampleRate sr: Double) {
        let start = timeline.arrive
        GulpSynth.render(at: start, length: timeline.gone - start, into: &out, sampleRate: sr) { local, phase in
            let t = start + local
            let leaving = timeline.departure(at: t)
            let driving = 1 - smoothstep(timeline.stop - 0.3, timeline.stop + 0.2, t)
            let revving = smoothstep(timeline.depart - 0.05, timeline.depart + 0.25, t)
            let level = min(1, local / 0.3) * (0.55 + 0.45 * max(driving, revving)) * (1 - leaving)
            let pitch = 40 + 8 * driving + 34 * sqrt(leaving)
            phase += 2 * .pi * pitch / sr
            var hum = 0.0
            for k in 1...5 { hum += sin(Double(k) * phase) / Double(k) }
            let putter = 0.8 + 0.2 * sin(2 * .pi * 9 * t)
            return 0.1 * level * putter * hum
        }
    }

    /// A short major third, like a small vehicle's horn.
    private static func addBeep(at start: Double, to out: inout [Float], sampleRate sr: Double) {
        GulpSynth.render(at: start, length: 0.11, into: &out, sampleRate: sr) { t, phase in
            phase += 2 * .pi * 440 / sr
            let envelope = min(1, t / 0.005) * min(1, (0.11 - t) / 0.02)
            return 0.13 * envelope * (sin(phase) + sin(phase * 1.26))
        }
    }
}
