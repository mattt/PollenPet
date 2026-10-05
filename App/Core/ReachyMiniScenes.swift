import Foundation

/// Original desktop dialogue inspired by Reachy Mini's expressive head and antennas.
enum ReachyMiniScenes {
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
}
