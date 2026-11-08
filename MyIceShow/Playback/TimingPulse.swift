import Foundation

enum TimingPulse {
    static let beatsPerMinute: Double = 120

    static func audioData() -> Data {
        let sampleRate = 22_050
        let duration = Int(SkatingMotion.maximumDuration + 2)
        let beatFrames = sampleRate / 2
        let pulseFrames = sampleRate / 25
        var samples = [Int16](repeating: 0, count: sampleRate * duration)

        for beat in 0..<(duration * 2) {
            let frequency: Double = beat.isMultiple(of: 4) ? 880 : 660
            for frame in 0..<pulseFrames {
                let time = Double(frame) / Double(sampleRate)
                let envelope = pow(1 - Double(frame) / Double(pulseFrames), 3)
                samples[beat * beatFrames + frame] = Int16(
                    sin(2 * .pi * frequency * time) * envelope * 8_000
                )
            }
        }

        var data = Data()
        let byteCount = UInt32(samples.count * MemoryLayout<Int16>.size)
        data.append(contentsOf: "RIFF".utf8)
        append(byteCount + 36, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(byteCount, to: &data)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private static func append<Value: FixedWidthInteger>(_ value: Value, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}
