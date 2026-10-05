import Foundation

enum PetGesture: Sendable, CaseIterable {
    case welcome, surprise, shy, nod, think, present
    /// A short nod before the first line of a response to the person's reply.
    case acknowledge
}

/// Head angles over time, as pitch, yaw, and roll in radians added to the rest pose.
struct GestureClip: Sendable {
    struct Keyframe: Sendable {
        let time: Double
        let angles: SIMD3<Double>

        init(_ time: Double, _ pitch: Double = 0, _ yaw: Double = 0, _ roll: Double = 0) {
            self.time = time
            angles = SIMD3(pitch, yaw, roll)
        }
    }

    let duration: Double
    let keyframes: [Keyframe]

    func angles(at time: Double) -> SIMD3<Double> {
        guard let first = keyframes.first, let last = keyframes.last else { return .zero }
        if time <= first.time { return first.angles }
        if time >= last.time { return last.angles }
        for (a, b) in zip(keyframes, keyframes.dropFirst()) where time <= b.time {
            return a.angles + (b.angles - a.angles) * smoothstep((time - a.time) / (b.time - a.time))
        }
        return .zero
    }
}

/// Small authored clips. The performance compiler places them on the same clock as text and audio.
enum GestureLibrary {
    static func clip(_ gesture: PetGesture, for pet: PetID) -> GestureClip {
        if gesture == .acknowledge { return acknowledgment(for: pet) }
        switch pet {
        case .microduck:
            let target: SIMD3<Double> = switch gesture {
            case .welcome: [0.10, -0.16, 0.12]
            case .surprise: [-0.20, 0, -0.08]
            case .shy: [0.12, -0.18, -0.16]
            case .nod: [0.18, 0, 0]
            case .think: [-0.07, 0.20, 0.22]
            case .present: [-0.04, -0.25, 0.08]
            case .acknowledge: .zero
            }
            let duration = gesture == .nod ? 1.15 : 1.9
            return GestureClip(duration: duration, keyframes: [
                .init(0),
                .init(duration * 0.3, target.x, target.y, target.z),
                .init(duration * 0.6, target.x * 0.65, target.y * 0.8, target.z * 0.8),
                .init(duration),
            ])
        case .reachyMini:
            let target: SIMD3<Double> = switch gesture {
            case .welcome: [-0.08, 0.24, -0.11]
            case .surprise: [-0.20, 0, 0.04]
            case .shy: [0.12, -0.16, 0.12]
            case .nod: [0.17, 0, 0]
            case .think: [-0.08, 0.20, 0.14]
            case .present: [0.02, -0.24, -0.08]
            case .acknowledge: .zero
            }
            let duration = gesture == .nod ? 1.0 : 1.7
            return GestureClip(duration: duration, keyframes: [
                .init(0),
                .init(duration * 0.28, target.x, target.y, target.z),
                .init(duration * 0.62, target.x * 0.7, target.y * 0.7, target.z * 0.7),
                .init(duration),
            ])
        }
    }

    private static func acknowledgment(for pet: PetID) -> GestureClip {
        let end = PerformanceCompiler.acknowledgmentDuration
        return switch pet {
        case .microduck:
            GestureClip(duration: end, keyframes: [
                .init(0), .init(end * 0.3, -0.04, 0, 0.05), .init(end * 0.65, 0.12), .init(end),
            ])
        case .reachyMini:
            GestureClip(duration: end, keyframes: [
                .init(0), .init(end * 0.35, 0.12, 0, -0.04), .init(end * 0.7, -0.05), .init(end),
            ])
        }
    }
}

/// Plays a performance's gestures on one head, then eases back to rest after speech finishes.
struct HeadActing {
    private let pet: PetID
    private let settleDuration: Double
    private var performanceID: UUID?
    private var clips: [(start: Double, clip: GestureClip)] = []
    private var previousState: PlaybackState = .idle
    private var acting = SIMD3<Double>.zero
    private var settling = SIMD3<Double>.zero
    private var settleStart = 0.0

    init(pet: PetID, settleDuration: Double) {
        self.pet = pet
        self.settleDuration = settleDuration
    }

    /// The gesture angles at `time`. Reduce Motion returns the rest pose.
    mutating func angles(for performance: Performance, id: UUID, time: Double, idleTime: Double,
                         state: PlaybackState, reducedMotion: Bool) -> SIMD3<Double> {
        if performanceID != id {
            clips = performance.gestures.map { ($0.start, GestureLibrary.clip($0.gesture, for: pet)) }
            acting = .zero
            settling = .zero
            previousState = .idle
            performanceID = id
        }
        if state == .finished && previousState != .finished {
            settling = acting
            settleStart = idleTime
        }
        defer { previousState = state }
        acting = .zero
        guard !reducedMotion else { return acting }
        if state == .finished {
            acting = settling * (1 - smoothstep((idleTime - settleStart) / settleDuration))
        } else if state != .idle {
            for entry in clips {
                let local = time - entry.start
                guard local >= 0, local <= entry.clip.duration else { continue }
                acting += entry.clip.angles(at: local)
            }
        }
        return acting
    }

    mutating func reset() {
        performanceID = nil
        clips = []
        acting = .zero
        settling = .zero
        previousState = .idle
    }
}

func smoothstep(_ value: Double) -> Double {
    let t = min(1, max(0, value))
    return t * t * (3 - 2 * t)
}
