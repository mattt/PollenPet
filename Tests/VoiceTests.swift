import Foundation
import Testing
@testable import PollenPet

@Suite("Synthesized voices")
struct VoiceTests {
    @Test(arguments: PetID.allCases)
    func burstsFollowWordsAndMouthClosesInGaps(pet: PetID) throws {
        let performance = PerformanceCompiler.compile(.init(.init("abcdef hi")), for: pet)
        #expect(performance.chirps.count == 3)
        let samples = try VoiceRenderer.render(performance)
        for chirp in performance.chirps {
            #expect(performance.mouth(at: chirp.start + chirp.duration / 2) > 0.99)
        }
        for pair in zip(performance.chirps, performance.chirps.dropFirst()) {
            let end = pair.0.start + pair.0.duration
            #expect(end < pair.1.start)
            #expect(performance.mouth(at: (end + pair.1.start) / 2) == 0)
            let startFrame = Int(ceil(end * VoiceRenderer.sampleRate)) + 1
            let endFrame = Int(pair.1.start * VoiceRenderer.sampleRate) - 1
            #expect(samples[startFrame..<endFrame].allSatisfy { $0 == 0 })
        }
    }

    @Test(arguments: PetID.allCases)
    func accentsAreExplicitAndClustered(pet: PetID) throws {
        let performance = PerformanceCompiler.compile(.init(.init("Oh!!! Really?! Done.")), for: pet)
        #expect(performance.accents.map(\.kind) == [.surprise, .question, .ending])
        for accent in performance.accents {
            #expect(performance.units.contains { $0.start == accent.start })
            #expect(accent.start + accent.duration < performance.duration)
            #expect(!performance.chirps.contains { $0.start < accent.start + accent.duration && $0.start + $0.duration > accent.start })
        }
    }

    @Test func accentMarksIncludeUnicodeVariants() {
        for character in "?？¿⁇‽⁉" { #expect(VoiceAccent.Kind(character) == .question) }
        for character in "!！¡‼" { #expect(VoiceAccent.Kind(character) == .surprise) }
        for character in ".。" { #expect(VoiceAccent.Kind(character) == .ending) }
        for character in "…,;:'’\"— \n\t~@#🐢" { #expect(VoiceAccent.Kind(character) == nil) }
    }

    @Test(arguments: PetID.allCases)
    func renderingIsBoundedAndDeterministic(pet: PetID) throws {
        let performance = PerformanceCompiler.compile(.init(.init("Hello!")), for: pet)
        let first = try VoiceRenderer.render(performance)
        #expect(first == (try VoiceRenderer.render(performance)))
        #expect(first.contains { abs($0) > 0.01 })
        #expect(first.allSatisfy { $0.isFinite && abs($0) <= 0.6 })
    }

    @Test func robotsHaveDistinctVoices() throws {
        let line = DialogueLine(.init("Hello there"))
        let duck = PerformanceCompiler.compile(line, for: .microduck)
        let reachy = PerformanceCompiler.compile(line, for: .reachyMini)
        #expect(PetID.reachyMini.voice.register < PetID.microduck.voice.register)
        #expect(reachy.units.last!.start > duck.units.last!.start)
        #expect(try VoiceRenderer.render(duck) != VoiceRenderer.render(reachy))
    }

    @Test func renderingHonorsCancellation() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            let performance = PerformanceCompiler.compile(.init(.init("Hello")), for: .microduck)
            #expect(throws: CancellationError.self) { try VoiceRenderer.render(performance) }
        }
        await task.value
    }
}
