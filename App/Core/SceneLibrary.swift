enum SceneID: String, CaseIterable, Identifiable, Sendable {
    case hello, discovery, tired, teasing, package

    var id: Self { self }

    var title: String {
        switch self {
        case .hello: "Say hello"
        case .discovery: "A little discovery"
        case .tired: "A long day"
        case .teasing: "A little teasing"
        case .package: "A mysterious package"
        }
    }
}

enum SceneLibrary {
    static func scene(_ scene: SceneID, for pet: PetID) -> DialogueScene {
        switch pet {
        case .microduck: MicroduckScenes.scene(scene)
        case .reachyMini: ReachyMiniScenes.scene(scene)
        }
    }
}

// MARK: - Microduck

/// Original dialogue for Microduck, independent of the robot's firmware.
private enum MicroduckScenes {
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
}

// MARK: - Reachy Mini

/// Original desktop dialogue inspired by Reachy Mini's expressive head and antennas.
private enum ReachyMiniScenes {
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
