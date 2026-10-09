import Foundation

/// Parameters for a synthesized flush. No audio files ship with the app: the
/// sound is generated in a few milliseconds, which keeps the binary tiny and
/// makes themes cheap.
public struct SoundRecipe: Sendable, Hashable {
    public var duration: Double
    /// Low-pass cutoff (Hz) of the water noise at the start and at the end.
    /// Sweeping it down sounds like water draining away.
    public var startCutoff: Double
    public var endCutoff: Double
    /// 0...1 amount of deep rumble from the pipes.
    public var rumble: Double
    /// Speed (Hz) of the swirling wobble, speeding up like a vortex.
    public var swirlRate: ClosedRange<Double>
    public var bubbles: Int
    public var bubblePitch: ClosedRange<Double>
    public var seed: UInt64

    public init(duration: Double, startCutoff: Double, endCutoff: Double, rumble: Double,
                swirlRate: ClosedRange<Double>, bubbles: Int, bubblePitch: ClosedRange<Double>, seed: UInt64) {
        self.duration = duration
        self.startCutoff = startCutoff
        self.endCutoff = endCutoff
        self.rumble = rumble
        self.swirlRate = swirlRate
        self.bubbles = bubbles
        self.bubblePitch = bubblePitch
        self.seed = seed
    }
}

public enum FlushSynth {
    public static let sampleRate = 44_100.0

    /// Renders mono samples in -1...1.
    public static func render(_ recipe: SoundRecipe, sampleRate: Double = sampleRate) -> [Float] {
        var rng = SplitMix64(seed: recipe.seed)
        var samples = waterBed(recipe, sampleRate: sampleRate, rng: &rng)
        normalize(&samples, to: 0.6)
        addHandleClick(to: &samples, sampleRate: sampleRate, rng: &rng)
        addBubbles(to: &samples, recipe: recipe, sampleRate: sampleRate, rng: &rng)
        normalize(&samples, to: 0.85, onlyIfLouder: true)
        return samples
    }

    /// Filtered noise whose brightness falls and whose wobble speeds up.
    private static func waterBed(_ r: SoundRecipe, sampleRate sr: Double, rng: inout SplitMix64) -> [Float] {
        let count = Int(r.duration * sr)
        var out = [Float](repeating: 0, count: count)
        var low1 = 0.0, low2 = 0.0, rumble = 0.0, swirlPhase = 0.0
        let rumbleCoeff = 1 - exp(-2 * .pi * 110 / sr)
        let ratio = r.endCutoff / r.startCutoff

        for i in 0..<count {
            let u = Double(i) / Double(count)
            let white = rng.nextSigned()

            let cutoff = r.startCutoff * pow(ratio, u)
            let coeff = 1 - exp(-2 * .pi * cutoff / sr)
            low1 += coeff * (white - low1)
            low2 += coeff * (low1 - low2)
            rumble += rumbleCoeff * (white - rumble)

            let rate = r.swirlRate.lowerBound + (r.swirlRate.upperBound - r.swirlRate.lowerBound) * u
            swirlPhase += 2 * .pi * rate / sr
            let swirl = 0.72 + 0.28 * sin(swirlPhase)

            out[i] = Float((low2 + rumble * r.rumble * 3) * swirl * envelope(u))
        }
        return out
    }

    /// Fast swell, long body, smooth tail.
    static func envelope(_ u: Double) -> Double {
        let attack = smoothstep(0, 0.07, u)
        let swell = 0.75 + 0.25 * smoothstep(0.05, 0.3, u)
        let release = 1 - smoothstep(0.6, 1.0, u)
        return attack * swell * release
    }

    /// The handle: a short noisy click with a low thump.
    private static func addHandleClick(to out: inout [Float], sampleRate sr: Double, rng: inout SplitMix64) {
        let length = min(out.count, Int(0.04 * sr))
        for i in 0..<length {
            let t = Double(i) / sr
            let decay = exp(-t * 140)
            out[i] += Float((rng.nextSigned() * 0.35 + sin(2 * .pi * 85 * t) * 0.55) * decay)
        }
    }

    /// Bubbles are sine chirps rising in pitch, clustered toward the final gulp.
    private static func addBubbles(to out: inout [Float], recipe r: SoundRecipe, sampleRate sr: Double, rng: inout SplitMix64) {
        let total = Double(out.count) / sr
        for _ in 0..<r.bubbles {
            let start = (0.15 + 0.7 * pow(rng.nextUnit(), 0.6)) * total
            let length = 0.03 + 0.07 * rng.nextUnit()
            let pitch = r.bubblePitch.lowerBound + (r.bubblePitch.upperBound - r.bubblePitch.lowerBound) * rng.nextUnit()
            let amplitude = 0.08 + 0.18 * rng.nextUnit()

            let first = Int(start * sr)
            let n = Int(length * sr)
            var phase = 0.0
            for j in 0..<n where first + j < out.count {
                let p = Double(j) / Double(n)
                phase += 2 * .pi * pitch * (1 + 1.8 * p) / sr
                let shape = sin(.pi * p)
                out[first + j] += Float(amplitude * shape * shape * sin(phase))
            }
        }
    }

    private static func normalize(_ samples: inout [Float], to target: Float, onlyIfLouder: Bool = false) {
        let peak = samples.reduce(0) { max($0, abs($1)) }
        guard peak > 0, !onlyIfLouder || peak > target else { return }
        let gain = target / peak
        for i in samples.indices { samples[i] *= gain }
    }

    static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Tiny deterministic RNG, so each theme always sounds the same.
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

    mutating func nextSigned() -> Double {
        nextUnit() * 2 - 1
    }
}
