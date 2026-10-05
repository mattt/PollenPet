import Foundation
import RealityKit
import simd

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
