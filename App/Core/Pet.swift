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
        case .microduck: Voice(letterInterval: 0.075, register: 1, overtone: 0.12)
        // Reachy Mini is larger, so it speaks lower, a little slower, and with more buzz.
        case .reachyMini: Voice(letterInterval: 0.078, register: 0.72, overtone: 0.3)
        }
    }
}
