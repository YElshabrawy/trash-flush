import Foundation

/// Wraps samples in a 16-bit mono WAV file in memory, which AVAudioPlayer can
/// play directly with `AVAudioPlayer(data:)`.
public enum WAVEncoder {
    public static func encode(_ samples: [Float], sampleRate: Int = Int(GulpSynth.sampleRate)) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))  // PCM
        data.appendLittleEndian(UInt16(1))  // mono
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * bytesPerSample))
        data.appendLittleEndian(UInt16(bytesPerSample))
        data.appendLittleEndian(UInt16(16))

        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(UInt32(dataSize))
        for sample in samples {
            let clamped = min(max(sample, -1), 1)
            data.appendLittleEndian(Int16(clamped * Float(Int16.max)))
        }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
