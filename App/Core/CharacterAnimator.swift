import Foundation
import RealityKit
import simd

@MainActor protocol CharacterAnimator: AnyObject {
    /// The entity whose subtree is the moving head. Reactions are placed beside it.
    var headEntity: Entity? { get }
    /// Poses the model for one rendered frame. `attention` turns the head toward the pointer.
    func update(_ performance: Performance, id: UUID, time: Double, idleTime: Double,
                state: PlaybackState, reducedMotion: Bool, attention: SIMD3<Double>)
    /// Returns every joint to its rest pose.
    func stop()
}

private enum RigError: Error {
    case missingJoint(String)
}

// MARK: - Microduck

/// Animates rigid robot parts around the source model's local servo axes.
/// The leg joints stay planted.
@MainActor final class MicroduckAnimator: CharacterAnimator {
    private struct Joint {
        let entity: Entity
        let bind: Transform
    }

    private var joints: [String: Joint] = [:]
    private var acting = HeadActing(pet: .microduck, settleDuration: 0.24)

    init(root: Entity) throws {
        for name in ["neck_pitch", "head_pitch", "head_yaw", "head_roll", "mouth_hinge"] {
            guard let entity = root.findEntity(named: name) else { throw RigError.missingJoint(name) }
            joints[name] = Joint(entity: entity, bind: entity.transform)
        }
    }

    var headEntity: Entity? { joints["head_roll"]?.entity }

    func update(_ performance: Performance, id: UUID, time: Double, idleTime: Double,
                state: PlaybackState, reducedMotion: Bool, attention: SIMD3<Double> = .zero) {
        let gesture = acting.angles(for: performance, id: id, time: time, idleTime: idleTime,
                                    state: state, reducedMotion: reducedMotion)
        var pose = SIMD3<Double>.zero
        var neck = 0.0
        var mouth = 0.0
        if !reducedMotion {
            pose = gesture + attention
            pose.y += sin(idleTime * 0.63) * 0.045
            pose.z += sin(idleTime * 1.12) * 0.025
            neck = sin(idleTime * 1.7) * 0.012
            if state == .playing {
                mouth = performance.mouth(at: time)
                pose.x += mouth * 0.035
            }
        }
        rotate("neck_pitch", by: neck)
        rotate("head_pitch", by: pose.x - neck)
        rotate("head_yaw", by: pose.y)
        rotate("head_roll", by: pose.z)
        rotate("mouth_hinge", by: mouth * 0.28, axis: [0, 1, 0])
    }

    func stop() {
        for joint in joints.values { joint.entity.transform = joint.bind }
        acting.reset()
    }

    private func rotate(_ name: String, by angle: Double, axis: SIMD3<Float> = [0, 0, 1]) {
        guard let joint = joints[name] else { return }
        joint.entity.orientation = joint.bind.rotation * simd_quatf(angle: Float(angle), axis: axis)
    }
}

// MARK: - Reachy Mini

/// Moves the visualization model's head while its base stays on the desk.
@MainActor final class ReachyMiniAnimator: CharacterAnimator {
    private let head: Entity
    private let bind: Transform
    private var acting = HeadActing(pet: .reachyMini, settleDuration: 0.25)

    init(root: Entity) throws {
        guard let head = root.findEntity(named: "Head") else { throw RigError.missingJoint("Head") }
        self.head = head
        bind = head.transform
    }

    var headEntity: Entity? { head }

    func update(_ performance: Performance, id: UUID, time: Double, idleTime: Double,
                state: PlaybackState, reducedMotion: Bool, attention: SIMD3<Double> = .zero) {
        let gesture = acting.angles(for: performance, id: id, time: time, idleTime: idleTime,
                                    state: state, reducedMotion: reducedMotion)
        var pose = SIMD3<Double>.zero
        var speechPulse = 0.0
        if !reducedMotion {
            pose = gesture + attention
            pose.y += sin(idleTime * 0.74) * 0.035
            pose.z += sin(idleTime * 1.07) * 0.025
            if state == .playing {
                // The model has no jaw, so speech lifts and tilts the whole head.
                speechPulse = performance.mouth(at: time)
                pose.x += speechPulse * 0.035
            }
        }
        let pitch = simd_quatf(angle: Float(pose.x), axis: [1, 0, 0])
        let yaw = simd_quatf(angle: Float(pose.y), axis: [0, 1, 0])
        let roll = simd_quatf(angle: Float(pose.z), axis: [0, 0, 1])
        head.orientation = bind.rotation * yaw * pitch * roll
        head.position = bind.translation + SIMD3(0, Float(speechPulse * 0.008), 0)
    }

    func stop() {
        head.transform = bind
        acting.reset()
    }
}
