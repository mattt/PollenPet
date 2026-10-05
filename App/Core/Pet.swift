/// The robots the app can show. Each one has a bundled model, dialogue, voice, and animator.
enum PetID: String, CaseIterable, Identifiable, Sendable {
    case microduck
    case reachyMini = "reachy-mini"

    var id: Self { self }

    var name: String {
        switch self {
        case .microduck: "Microduck"
        case .reachyMini: "Reachy Mini"
        }
    }

    var voice: Voice {
        switch self {
        case .microduck: Microduck.voice
        case .reachyMini: ReachyMini.voice
        }
    }
}
