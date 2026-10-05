import Foundation
import RealityKit
import simd

/// Microduck's voice, dialogue, and gestures. The dialogue is original
/// and independent of the robot's firmware.
enum Microduck {
    static let voice = Voice(letterInterval: 0.075, register: 1, overtone: 0.12)

    // MARK: - Dialogue

    static func scene(_ scene: SceneID) -> DialogueScene {
        switch scene {
        case .hello:
            .init(.init(
                .init("Oh! Hello. ", effect: .bounce, gesture: .welcome),
                .init("I've found a spot on your desk. "),
                .init("Is this a good place for a duck?", gesture: .think)
            ), [
                .init(0, "Make yourself at home.", [
                    .init(.init("Thank you! ", effect: .bounce, gesture: .nod), .init("I'll keep my feet off the keyboard.")),
                    .init(.init("If you need a second opinion, I'm right here. ", delivery: .gentle), .init("It might be a quack.", gesture: .shy))
                ]),
                .init(1, "Can you help me work?", [
                    .init(.init("I can listen while you explain the problem. ", gesture: .nod), .init("My head tilts are very encouraging.", gesture: .think)),
                    .init(.init("Start wherever you like. ", delivery: .gentle), .init("We can take it one step at a time."))
                ])
            ])
        case .discovery:
            .init(.init(
                .init("Something moved! ", gesture: .surprise, reaction: .surprise),
                .init("That little arrow on your screen. ", gesture: .think),
                .init("Does it live here too?")
            ), [
                .init(0, "That's my mouse pointer.", [
                    .init(.init("A mouse? ", gesture: .think), .init("I expected more whiskers.")),
                    .init(.init("I'll try to keep up with it. ", gesture: .present), .init("You two seem busy.", delivery: .gentle))
                ]),
                .init(1, "Would you like to say hello?", [
                    .init(.init("Hello, arrow! ", effect: .bounce, gesture: .welcome), .init("I'm the duck.")),
                    .init(.init("It went away. "), .init("I'll give it some space.", delivery: .gentle))
                ])
            ])
        case .tired:
            .init(.init(
                .init("I've been standing here for a while. ", delivery: .gentle, gesture: .think),
                .init("I'm getting quite good at it. "),
                .init("Shall we take a break?")
            ), [
                .init(0, "A break sounds good.", [
                    .init(.init("Good. We can leave that thought right there.", delivery: .gentle, gesture: .nod)),
                    .init(.init("It will still be here when you get back. "), .init("So will I.", delivery: .gentle))
                ]),
                .init(1, "Just one more thing.", [
                    .init(.init("All right. One thing. ", gesture: .nod), .init("I'll keep you company.", delivery: .gentle)),
                    .init(.init("Then perhaps a stretch? ", gesture: .think), .init("You have more joints to look after than I do."))
                ])
            ])
        case .teasing:
            .init(.init(
                .init("Someone called me a rubber duck. ", gesture: .think),
                .init("I checked. Mostly screws.", delivery: .dry)
            ), [
                .init(0, "You can still help me debug.", [
                    .init(.init("Of course. ", gesture: .nod), .init("Tell me what the code should do.")),
                    .init(.init("I'll look thoughtful until you find it. ", gesture: .think), .init("That's my part."))
                ]),
                .init(1, "Definitely not a bath toy.", [
                    .init(.init("Agreed! ", effect: .bounce, gesture: .surprise), .init("Let's keep the water over there.")),
                    .init(.init("A dry desk and a little conversation. ", delivery: .gentle), .init("That suits me."))
                ])
            ])
        case .package:
            .init(.init(
                .init("There's a tiny box here. ", gesture: .present),
                .init("It rattles when I nudge it. "),
                .init("What do you think is inside?", gesture: .think, reaction: .thought)
            ), [
                .init(0, "Spare screws?", [
                    .init(.init("Practical. Reassuring. ", gesture: .nod), .init("An excellent present for a duck like me.")),
                    .init(.init("Let's keep them somewhere safe. ", delivery: .gentle), .init("Perhaps a slightly larger box."))
                ]),
                .init(1, "Tiny roller skates?", [
                    .init(.init("For these feet? ", gesture: .surprise, reaction: .surprise), .init("Now I'm interested.")),
                    .init(.init("Let's open it before I plan a route. ", gesture: .think), .init("The edge of the desk is closer than it looks."))
                ])
            ])
        }
    }

    // MARK: - Gestures

    static func clip(_ gesture: PetGesture) -> GestureClip {
        let target: SIMD3<Double>
        switch gesture {
        case .welcome: target = [0.10, -0.16, 0.12]
        case .surprise: target = [-0.20, 0, -0.08]
        case .shy: target = [0.12, -0.18, -0.16]
        case .nod: target = [0.18, 0, 0]
        case .think: target = [-0.07, 0.20, 0.22]
        case .present: target = [-0.04, -0.25, 0.08]
        case .acknowledge:
            let end = PerformanceCompiler.acknowledgmentDuration
            return GestureClip(duration: end, keyframes: [
                .init(0), .init(end * 0.3, -0.04, 0, 0.05), .init(end * 0.65, 0.12), .init(end),
            ])
        }
        let duration = gesture == .nod ? 1.15 : 1.9
        return GestureClip(duration: duration, keyframes: [
            .init(0),
            .init(duration * 0.3, target.x, target.y, target.z),
            .init(duration * 0.6, target.x * 0.65, target.y * 0.8, target.z * 0.8),
            .init(duration),
        ])
    }
}

// MARK: - Animator

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
