/// Motion applied to a span's letters as they appear.
enum TextEffect: Sendable {
    case none, bounce
}

/// The pace of a span, relative to the voice's normal letter interval.
enum Delivery: Sendable {
    case normal, gentle, dry

    var speed: Double {
        switch self {
        case .normal: 1
        case .gentle: 1.2
        case .dry: 1.15
        }
    }
}

/// A decorative cue drawn beside the robot's head.
enum PetReaction: Sendable, CaseIterable {
    case surprise, thought

    var duration: Double {
        switch self {
        case .surprise: 1.1
        case .thought: 1.8
        }
    }
}

struct DialogueSpan: Sendable {
    let text: String
    let effect: TextEffect
    let delivery: Delivery
    let gesture: PetGesture?
    let reaction: PetReaction?

    init(_ text: String, effect: TextEffect = .none, delivery: Delivery = .normal,
         gesture: PetGesture? = nil, reaction: PetReaction? = nil) {
        self.text = text
        self.effect = effect
        self.delivery = delivery
        self.gesture = gesture
        self.reaction = reaction
    }
}

struct DialogueLine: Sendable {
    let spans: [DialogueSpan]
    var text: String { spans.map(\.text).joined() }
    init(_ spans: DialogueSpan...) { self.spans = spans }
}

struct DialogueChoice: Sendable {
    let id: Int
    let text: String
    let response: [DialogueLine]

    init(_ id: Int, _ text: String, _ response: [DialogueLine]) {
        self.id = id
        self.text = text
        self.response = response
    }
}

/// An opening line and two replies, each followed by two lines of response.
struct DialogueScene: Sendable {
    let opening: DialogueLine
    let choices: [DialogueChoice]

    init(_ opening: DialogueLine, _ choices: [DialogueChoice]) {
        self.opening = opening
        self.choices = choices
    }
}
