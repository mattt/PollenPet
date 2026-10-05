import Foundation

/// How a robot speaks. Pitches are authored in Microduck's register.
struct Voice: Sendable {
    /// Seconds per letter at normal delivery.
    let letterInterval: Double
    /// Scales every pitch. Values below 1 sound lower.
    let register: Double
    /// Strength of the second harmonic. Higher values sound buzzier.
    let overtone: Double
}

/// Synthesizes a performance's chirps, accents, and cues into one mono buffer,
/// so that playback controls and the speech clock share a single source.
enum VoiceRenderer {
    static let sampleRate = 48_000.0

    static func render(_ performance: Performance) throws -> [Float] {
        try Task.checkCancellation()
        let voice = performance.pet.voice
        var samples = [Float](repeating: 0, count: Int(ceil(performance.duration * sampleRate)))
        func tone(start: Double, duration: Double, from: Double, to: Double, level: Double) throws {
            try VoiceRenderer.tone(into: &samples, start: start, duration: duration,
                                   from: from * voice.register, to: to * voice.register,
                                   overtone: voice.overtone, level: level)
        }
        for (index, chirp) in performance.chirps.enumerated() {
            // Cycle through five pitches and alternate rising and falling glides.
            let pitch = 520 + Double(index % 5) * 42
            try tone(start: chirp.start, duration: chirp.duration,
                     from: pitch, to: pitch * (index % 2 == 0 ? 1.12 : 0.9), level: 0.24 * chirp.emphasis)
        }
        for accent in performance.accents {
            switch accent.kind {
            case .question:
                try tone(start: accent.start, duration: accent.duration, from: 570, to: 860, level: 0.19)
            case .surprise:
                try tone(start: accent.start, duration: 0.085, from: 710, to: 770, level: 0.17)
                try tone(start: accent.start + 0.12, duration: 0.1, from: 880, to: 930, level: 0.17)
            case .ending:
                try tone(start: accent.start, duration: accent.duration, from: 560, to: 380, level: 0.14)
            }
        }
        if performance.acknowledgesReply {
            try tone(start: 0.015, duration: 0.09, from: 620, to: 700, level: 0.13)
        }
        for cue in performance.reactions {
            switch cue.reaction {
            case .surprise: try tone(start: cue.start, duration: 0.16, from: 740, to: 980, level: 0.06)
            case .thought: try tone(start: cue.start, duration: 0.16, from: 390, to: 580, level: 0.06)
            }
        }
        return samples.map { max(-0.6, min(0.6, $0)) }
    }

    /// Adds a linear pitch glide with a sine-squared envelope.
    private static func tone(into samples: inout [Float], start: Double, duration: Double,
                             from: Double, to: Double, overtone: Double, level: Double) throws {
        let offset = Int((start * sampleRate).rounded())
        let count = Int(duration * sampleRate)
        guard count > 1 else { return }
        for frame in 0..<count where offset + frame >= 0 && offset + frame < samples.count {
            if frame % 4096 == 0 { try Task.checkCancellation() }
            let t = Double(frame) / sampleRate
            let phase = 2 * Double.pi * (from * t + (to - from) * t * t / (2 * duration))
            let envelope = pow(sin(Double.pi * Double(frame) / Double(count - 1)), 2)
            let signal = sin(phase) + overtone * sin(phase * 2)
            samples[offset + frame] += Float(signal * envelope * level)
        }
    }
}
