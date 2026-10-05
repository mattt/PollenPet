import Foundation

/// Original dialogue for Microduck, independent of the robot's firmware.
enum MicroduckScenes {
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
