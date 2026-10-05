import Foundation

/// One grapheme cluster of dialogue and the moment it appears.
struct RevealUnit: Sendable, Equatable {
    let id: Int
    let text: String
    let start: Double
    let effect: TextEffect
    /// When the span's text effect has settled.
    let effectEnd: Double
}

/// A burst of up to three letters, voiced as one pitch glide while the mouth opens.
struct Chirp: Sendable, Equatable {
    let start: Double
    let duration: Double
    let emphasis: Double
}

/// A tone for sentence punctuation, timed to the mark's reveal.
struct VoiceAccent: Sendable, Equatable {
    enum Kind: Sendable {
        case question, surprise, ending

        init?(_ character: Character) {
            switch character {
            case "?", "？", "¿", "⁇", "‽", "⁉": self = .question
            case "!", "！", "¡", "‼": self = .surprise
            case ".", "。": self = .ending
            default: return nil
            }
        }
    }

    let kind: Kind
    let start: Double

    var duration: Double {
        switch kind {
        case .question: 0.24
        case .surprise: 0.22
        case .ending: 0.18
        }
    }
}

struct GestureCue: Sendable, Equatable {
    let start: Double
    let gesture: PetGesture
}

struct ReactionCue: Sendable, Equatable {
    let start: Double
    let reaction: PetReaction
    var end: Double { start + reaction.duration }
}

/// A dialogue line compiled to one timeline that drives text, voice, and motion.
struct Performance: Sendable, Equatable {
    let pet: PetID
    let units: [RevealUnit]
    let chirps: [Chirp]
    let accents: [VoiceAccent]
    let gestures: [GestureCue]
    let reactions: [ReactionCue]
    /// Whether the line opens with an acknowledgment of the person's reply.
    let acknowledgesReply: Bool
    let duration: Double

    /// Offer replies on the closing question accent, before its audio tail and
    /// text effects finish. Questions followed by more dialogue wait.
    var replyPresentationTime: Double {
        guard let questionStart = accents.last(where: { $0.kind == .question })?.start,
              units.filter({ $0.start > questionStart }).allSatisfy({ unit in
                  unit.text.allSatisfy { character in
                      character.isWhitespace || character.unicodeScalars.allSatisfy {
                          CharacterSet.punctuationCharacters.contains($0)
                      }
                  }
              }) else { return duration }
        return questionStart
    }

    /// How far the mouth is open, from 0 to 1. The mouth opens once per chirp
    /// and stays closed between words and during accents.
    func mouth(at time: Double) -> Double {
        guard let chirp = chirps.last(where: { $0.start <= time }),
              time < chirp.start + chirp.duration else { return 0 }
        return sin(.pi * (time - chirp.start) / chirp.duration)
    }
}

enum PerformanceCompiler {
    /// The pause before a response's first line while the robot acknowledges the reply.
    static let acknowledgmentDuration = 0.58

    static func compile(_ line: DialogueLine, for pet: PetID, acknowledgingReply: Bool = false) -> Performance {
        let voice = pet.voice
        var time = (acknowledgingReply ? acknowledgmentDuration : 0) + (line.spans.first?.gesture == nil ? 0.12 : 0.34)
        var units: [RevealUnit] = []
        var chirps: [Chirp] = []
        var accents: [VoiceAccent] = []
        var gestures: [GestureCue] = acknowledgingReply ? [.init(start: 0, gesture: .acknowledge)] : []
        var reactions: [ReactionCue] = []
        var burstStart = time
        var burstLetters = 0
        var burstEmphasis = 0.8
        var burstEnd = time
        func flush() {
            guard burstLetters > 0 else { return }
            // Each burst lasts at most three letters, with a short quiet tail.
            chirps.append(.init(start: burstStart, duration: max(0.025, (burstEnd - burstStart) * 0.82),
                                emphasis: burstEmphasis))
            burstLetters = 0
        }
        var previousAccent = false
        for span in line.spans where !span.text.isEmpty {
            if let gesture = span.gesture { gestures.append(.init(start: max(0, time - 0.28), gesture: gesture)) }
            if let reaction = span.reaction { reactions.append(.init(start: time, reaction: reaction)) }
            let firstUnit = units.count
            let interval = voice.letterInterval * span.delivery.speed
            // Each unit is a whole extended grapheme cluster, including emoji sequences.
            for character in span.text {
                units.append(.init(id: units.count, text: String(character), start: time, effect: span.effect, effectEnd: 0))
                if character.isLetter || character.isNumber {
                    previousAccent = false
                    if burstLetters == 0 { burstStart = time; burstEmphasis = span.effect == .none ? 0.8 : 1 }
                    burstLetters += 1
                    time += interval
                    burstEnd = time
                    if burstLetters == 3 { flush() }
                } else {
                    flush()
                    if let kind = VoiceAccent.Kind(character) {
                        if previousAccent, let last = accents.last {
                            // A mixed ?! cluster keeps one question accent at the cluster start.
                            if kind == .question && last.kind != .question {
                                accents[accents.count - 1] = .init(kind: .question, start: last.start)
                            }
                            time += 0.04
                        } else {
                            let accent = VoiceAccent(kind: kind, start: time)
                            accents.append(accent)
                            time += accent.duration + 0.10
                        }
                        previousAccent = true
                    } else {
                        previousAccent = false
                        if character.isWhitespace { time += 0.085 }
                        else if character == "…" { time += 0.52 }
                        else if ",;:、".contains(character) { time += 0.16 }
                        else if "—–".contains(character) { time += 0.25 }
                        else { time += interval }
                    }
                }
            }
            flush()
            let end = time + 0.65
            for index in firstUnit..<units.count {
                let unit = units[index]
                units[index] = .init(id: unit.id, text: unit.text, start: unit.start, effect: unit.effect, effectEnd: end)
            }
        }
        // Let the last text effect, gesture, and reaction settle before the clock stops.
        let gestureEnd = gestures.map { $0.start + GestureLibrary.clip($0.gesture, for: pet).duration }.max() ?? 0
        let duration = max(time + 0.15, units.map(\.effectEnd).max() ?? 0,
                           gestureEnd + 0.15, reactions.map(\.end).max() ?? 0)
        return Performance(pet: pet, units: units, chirps: chirps, accents: accents, gestures: gestures,
                           reactions: reactions, acknowledgesReply: acknowledgingReply, duration: duration)
    }
}
