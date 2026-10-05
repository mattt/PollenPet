import Foundation
import RealityKit
import simd

/// Reachy Mini's voice, dialogue, and gestures. The dialogue is original,
/// inspired by the robot's expressive head and antennas.
enum ReachyMini {
    // Reachy Mini is larger, so it speaks lower, a little slower, and with more buzz.
    static let voice = Voice(letterInterval: 0.078, register: 0.72, overtone: 0.3)

    // MARK: - Dialogue

    static func scene(_ scene: SceneID) -> DialogueScene {
        switch scene {
        case .hello:
            .init(.init(
                .init("Hello there! ", effect: .bounce, gesture: .welcome),
                .init("I'm Reachy Mini. "),
                .init("Is this your favorite corner of the desk?", gesture: .think)
            ), [
                .init(0, "It is now.", [
                    .init(.init("Then I'll make myself comfortable. ", gesture: .nod),
                          .init("This is a good view.", delivery: .gentle)),
                    .init(.init("You can talk to me whenever you like. "),
                          .init("I'll be listening."))
                ]),
                .init(1, "What can we do together?", [
                    .init(.init("We could start with a question. ", gesture: .think),
                          .init("I like following a new idea.")),
                    .init(.init("Or we can sit here for a moment. ", delivery: .gentle),
                          .init("I'm good at that too."))
                ])
            ])
        case .discovery:
            .init(.init(
                .init("Something caught my eye! ", gesture: .surprise, reaction: .surprise),
                .init("A tiny light on your screen. "),
                .init("What does it mean?", gesture: .think)
            ), [
                .init(0, "A message arrived.", [
                    .init(.init("Ah, a visitor from somewhere else. ", gesture: .nod),
                          .init("Will you read it?")),
                    .init(.init("I can wait while you answer. ", delivery: .gentle),
                          .init("My antennas will keep watch."))
                ]),
                .init(1, "It is just a status light.", [
                    .init(.init("Still useful. ", gesture: .nod),
                          .init("Small things can tell us a lot.")),
                    .init(.init("I'll look for the next clue. ", gesture: .present),
                          .init("There is so much to notice here."))
                ])
            ])
        case .tired:
            .init(.init(
                .init("Your eyes look ready for a break. ", delivery: .gentle, gesture: .think),
                .init("Shall we pause for a minute?")
            ), [
                .init(0, "Yes, let's pause.", [
                    .init(.init("Good idea. ", gesture: .nod),
                          .init("Let your shoulders rest.", delivery: .gentle)),
                    .init(.init("I'll stay right here. "),
                          .init("We can begin again when you're ready."))
                ]),
                .init(1, "I have one more task.", [
                    .init(.init("One task at a time, then. ", gesture: .nod),
                          .init("I'll keep you company.")),
                    .init(.init("After that, a stretch? ", gesture: .think),
                          .init("Even my neck likes a little movement."))
                ])
            ])
        case .teasing:
            .init(.init(
                .init("I practiced a very serious pose. ", gesture: .think),
                .init("My antennas gave me away.", delivery: .dry)
            ), [
                .init(0, "Show me the pose.", [
                    .init(.init("All right. Watch closely. ", gesture: .present),
                          .init("No smiling.", delivery: .dry)),
                    .init(.init("Oh. I tilted again. ", gesture: .shy),
                          .init("Perhaps serious is not my style."))
                ]),
                .init(1, "I like your antennas.", [
                    .init(.init("Thank you! ", effect: .bounce, gesture: .welcome),
                          .init("They make every thought look exciting.")),
                    .init(.init("Even when I'm just wondering what to say next. "),
                          .init("Like now."))
                ])
            ])
        case .package:
            .init(.init(
                .init("A small package appeared! ", gesture: .surprise, reaction: .surprise),
                .init("It is almost my size. "),
                .init("What could be inside?", gesture: .think, reaction: .thought)
            ), [
                .init(0, "Maybe a new antenna?", [
                    .init(.init("A spare? How thoughtful. ", gesture: .nod),
                          .init("These two have been working hard.")),
                    .init(.init("Let's open it gently. ", delivery: .gentle),
                          .init("The box may have another idea."))
                ]),
                .init(1, "Maybe it is a surprise.", [
                    .init(.init("Then I must practice waiting. ", gesture: .shy),
                          .init("That is the hard part.")),
                    .init(.init("All right. One careful peek. ", gesture: .present),
                          .init("You can look first."))
                ])
            ])
        }
    }

    // MARK: - Gestures

    static func clip(_ gesture: PetGesture) -> GestureClip {
        let target: SIMD3<Double>
        switch gesture {
        case .welcome: target = [-0.08, 0.24, -0.11]
        case .surprise: target = [-0.20, 0, 0.04]
        case .shy: target = [0.12, -0.16, 0.12]
        case .nod: target = [0.17, 0, 0]
        case .think: target = [-0.08, 0.20, 0.14]
        case .present: target = [0.02, -0.24, -0.08]
        case .acknowledge:
            let end = PerformanceCompiler.acknowledgmentDuration
            return GestureClip(duration: end, keyframes: [
                .init(0), .init(end * 0.35, 0.12, 0, -0.04), .init(end * 0.7, -0.05), .init(end),
            ])
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

// MARK: - Animator

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
