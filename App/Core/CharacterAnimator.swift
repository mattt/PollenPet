import Foundation
import RealityKit

@MainActor protocol CharacterAnimator: AnyObject {
    /// The entity whose subtree is the moving head. Reactions are placed beside it.
    var headEntity: Entity? { get }
    /// Poses the model for one rendered frame. `attention` turns the head toward the pointer.
    func update(_ performance: Performance, id: UUID, time: Double, idleTime: Double,
                state: PlaybackState, reducedMotion: Bool, attention: SIMD3<Double>)
    /// Returns every joint to its rest pose.
    func stop()
}

enum RigError: Error {
    case missingJoint(String)
}
