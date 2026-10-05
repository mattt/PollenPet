import Foundation
import Testing
@testable import PollenPet

@Suite("Reactions and reply acknowledgments")
struct CueTests {
    @Test(arguments: PetID.allCases) func acknowledgmentShiftsEverySpeechCue(pet: PetID) throws {
        let line = DialogueLine(.init("Oh! A present.", gesture: .present, reaction: .surprise))
        let plain = PerformanceCompiler.compile(line, for: pet)
        let reply = PerformanceCompiler.compile(line, for: pet, acknowledgingReply: true)
        let shift = PerformanceCompiler.acknowledgmentDuration
        #expect(!plain.acknowledgesReply && reply.acknowledgesReply)
        #expect(reply == PerformanceCompiler.compile(line, for: pet, acknowledgingReply: true))
        #expect(reply.units.first!.start >= shift)
        #expect(reply.gestures.first == GestureCue(start: 0, gesture: .acknowledge))
        func shifted(_ a: [Double], _ b: [Double]) -> Bool {
            a.count == b.count && zip(a, b).allSatisfy { abs($1 - $0 - shift) < 0.00001 }
        }
        #expect(shifted(plain.units.map(\.start), reply.units.map(\.start)))
        #expect(shifted(plain.chirps.map(\.start), reply.chirps.map(\.start)))
        #expect(shifted(plain.accents.map(\.start), reply.accents.map(\.start)))
        #expect(shifted(plain.gestures.map(\.start), reply.gestures.dropFirst().map(\.start)))
        #expect(shifted(plain.reactions.map(\.start), reply.reactions.map(\.start)))
        // The acknowledgment chirps before the line begins.
        let samples = try VoiceRenderer.render(reply)
        #expect(samples.prefix(Int(shift * VoiceRenderer.sampleRate)).contains { abs($0) > 0.01 })
        let clip = GestureLibrary.clip(.acknowledge, for: pet)
        #expect(clip.duration == shift)
        #expect(clip.keyframes.first?.angles == .zero)
        #expect(clip.keyframes.last?.angles == .zero)
        #expect(clip.keyframes.last?.time == shift)
    }

    @Test(arguments: PetID.allCases) func reactionsAreAuthoredAndContained(pet: PetID) {
        for id in SceneID.allCases {
            let scene = SceneLibrary.scene(id, for: pet)
            for line in [scene.opening] + scene.choices.flatMap(\.response) {
                let performance = PerformanceCompiler.compile(line, for: pet)
                #expect(performance.reactions.count == line.spans.filter { $0.reaction != nil }.count)
                for cue in performance.reactions {
                    #expect(performance.units.contains { abs($0.start - cue.start) < 0.00001 })
                    #expect(cue.start >= 0 && cue.end <= performance.duration)
                }
            }
        }
        #expect(PerformanceCompiler.compile(.init(.init("Wow!!!")), for: pet).reactions.isEmpty)
    }

    @Test(arguments: PetReaction.allCases) func reactionToneIsBoundedAndShort(reaction: PetReaction) throws {
        let cue = ReactionCue(start: 0.3, reaction: reaction)
        let performance = Performance(pet: .microduck, units: [], chirps: [], accents: [], gestures: [],
                                      reactions: [cue], acknowledgesReply: false, duration: 3)
        let samples = try VoiceRenderer.render(performance)
        let start = Int(cue.start * VoiceRenderer.sampleRate)
        #expect(samples.prefix(start).allSatisfy { $0 == 0 })
        #expect(samples.contains { abs($0) > 0.01 })
        #expect(samples.allSatisfy { $0.isFinite && abs($0) < 0.1 })
        #expect(samples.suffix(from: start + Int(0.2 * VoiceRenderer.sampleRate)).allSatisfy { $0 == 0 })
    }

    @Test(arguments: PetID.allCases) func gesturesReturnToRest(pet: PetID) {
        for gesture in PetGesture.allCases {
            let clip = GestureLibrary.clip(gesture, for: pet)
            #expect(clip.angles(at: 0) == .zero)
            #expect(clip.angles(at: clip.duration) == .zero)
            if gesture != .acknowledge { #expect(clip.angles(at: clip.duration * 0.3) != .zero) }
        }
    }
}
