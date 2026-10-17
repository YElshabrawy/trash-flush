import Foundation

/// The sound of a flush, rendered to line up with its `NotchTimeline`.
///
/// No audio files ship with the app, and there is no noise in the mix: only
/// clean tones, so it stays soft through headphones.
/// - A low thump as the first file leaves the Trash.
/// - A water-drop "bloop" for every gulp. Each one is a step higher on a
///   pentatonic scale, so a big empty plays a little rising melody.
/// - A warm bell arpeggio when the island opens.
public enum GulpSynth {
    public static let sampleRate = 44_100.0

    /// Semitones above the first gulp. Pentatonic, so any run of them sounds good.
    static let scale = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26]
    /// G4. The twelfth gulp lands on A6.
    static let baseFrequency = 392.0

    /// Renders mono samples in -1...1.
    public static func render(_ timeline: NotchTimeline, sampleRate: Double = sampleRate) -> [Float] {
        var out = [Float](repeating: 0, count: Int((timeline.total + 0.6) * sampleRate))

        if let first = timeline.flights.first {
            addThump(at: first.start, to: &out, sampleRate: sampleRate)
        }
        var gulps = 0, sparkles = 0
        for flight in timeline.flights.sorted(by: { $0.arrival < $1.arrival }) {
            if flight.isMini {
                let step = scale[(scale.count - 5) + sparkles % 5]
                addBloop(at: flight.arrival, frequency: note(step), gain: 0.12, decay: 0.05, to: &out, sampleRate: sampleRate)
                sparkles += 1
            } else {
                let step = scale[min(gulps, scale.count - 1)]
                addBloop(at: flight.arrival, frequency: note(step), gain: 0.42, decay: 0.11, to: &out, sampleRate: sampleRate)
                gulps += 1
            }
        }
        for (i, step) in [12, 16, 19].enumerated() {
            addBell(at: timeline.islandStart + Double(i) * 0.045, frequency: note(step), gain: 0.2,
                    to: &out, sampleRate: sampleRate)
        }

        addEcho(to: &out, delay: 0.11, amount: 0.18, sampleRate: sampleRate)
        normalize(&out, to: 0.8)
        return out
    }

    static func note(_ semitones: Int) -> Double {
        baseFrequency * pow(2, Double(semitones) / 12)
    }

    /// A sine that glides up into its pitch in about 20 ms: the shape of a
    /// water drop. A touch of octave gives it a rounder, marimba-like body.
    static func addBloop(at start: Double, frequency f: Double, gain: Double, decay: Double,
                                 to out: inout [Float], sampleRate sr: Double) {
        render(at: start, length: decay * 7, into: &out, sampleRate: sr) { t, phase in
            let pitch = f * (1 - 0.3 * exp(-t / 0.02))
            phase += 2 * .pi * pitch / sr
            let envelope = min(1, t / 0.004) * exp(-t / decay)
            return gain * envelope * (sin(phase) + 0.18 * sin(2 * phase) * exp(-t / (decay * 0.5)))
        }
    }

    static func addThump(at start: Double, to out: inout [Float], sampleRate sr: Double) {
        render(at: start, length: 0.25, into: &out, sampleRate: sr) { t, phase in
            phase += 2 * .pi * (110 + 60 * (1 - exp(-t / 0.03))) / sr
            return 0.3 * min(1, t / 0.006) * exp(-t / 0.05) * sin(phase)
        }
    }

    /// Partials at 1×, 2× and 3×, with the upper ones fading first.
    static func addBell(at start: Double, frequency f: Double, gain: Double,
                                to out: inout [Float], sampleRate sr: Double) {
        render(at: start, length: 1.6, into: &out, sampleRate: sr) { t, phase in
            phase += 2 * .pi * f / sr
            let body = sin(phase) + 0.3 * sin(2 * phase) * exp(-t / 0.25) + 0.08 * sin(3 * phase) * exp(-t / 0.12)
            return gain * min(1, t / 0.005) * exp(-t / 0.45) * body
        }
    }

    /// Adds `voice(time, &phase)` to `out` from `start` for `length` seconds.
    static func render(at start: Double, length: Double, into out: inout [Float], sampleRate sr: Double,
                               voice: (Double, inout Double) -> Double) {
        let first = Int(start * sr)
        guard first >= 0 else { return }
        var phase = 0.0
        for i in 0..<Int(length * sr) where first + i < out.count {
            out[first + i] += Float(voice(Double(i) / sr, &phase))
        }
    }

    /// One soft repeat, like a small room.
    static func addEcho(to out: inout [Float], delay: Double, amount: Float, sampleRate sr: Double) {
        let offset = Int(delay * sr)
        guard offset < out.count else { return }
        for i in offset..<out.count {
            out[i] += out[i - offset] * amount
        }
    }

    static func normalize(_ samples: inout [Float], to target: Float) {
        let peak = samples.reduce(0) { max($0, abs($1)) }
        guard peak > target else { return }
        let gain = target / peak
        for i in samples.indices { samples[i] *= gain }
    }
}

/// Tiny deterministic RNG, so the animation is the same on every run.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
