import Foundation
import Testing
@testable import PollenPet

@Suite("Authored performances")
struct PerformanceTests {
    @Test func repliesUseOnlyAClosingQuestionAccent() throws {
        for text in ["Ready?", "Ready?!?", "‘Ready？’  "] {
            let performance = PerformanceCompiler.compile(.init(.init(text)), for: .microduck)
            let question = try #require(performance.accents.last { $0.kind == .question })
            #expect(performance.replyPresentationTime == question.start)
            #expect(performance.replyPresentationTime < performance.duration)
        }
        for text in ["Ready? One more thing.", "Hello there.", "Ready? 日", "Ready? 🐢"] {
            let performance = PerformanceCompiler.compile(.init(.init(text)), for: .microduck)
            #expect(performance.replyPresentationTime == performance.duration)
        }
    }

    @Test(arguments: PetID.allCases)
    func mouthOpensOncePerThreeLetters(pet: PetID) {
        let performance = PerformanceCompiler.compile(.init(.init("abcdefghi")), for: pet)
        #expect(performance.chirps.count == 3)
        for (chirp, first) in zip(performance.chirps, stride(from: 0, to: 9, by: 3)) {
            #expect(chirp.start == performance.units[first].start)
            #expect(performance.mouth(at: chirp.start + chirp.duration / 2) > 0.99)
        }
        #expect(performance.mouth(at: performance.duration) == 0)
    }

    @Test func mouthClosesForWordBoundariesAndRests() {
        let performance = PerformanceCompiler.compile(.init(.init("ab cd…ef")), for: .microduck)
        #expect(performance.chirps.count == 3)
        for unit in performance.units where unit.text == " " || unit.text == "…" {
            #expect(performance.mouth(at: unit.start + 0.001) == 0)
        }
    }

    @Test func punctuationAndDelivery() {
        let normal = PerformanceCompiler.compile(.init(.init("a,b…c!d")), for: .microduck)
        #expect(normal.units[2].start - normal.units[1].start >= 0.159)
        #expect(normal.units[4].start - normal.units[3].start >= 0.519)
        #expect(normal.units[6].start - normal.units[5].start >= 0.319)
        let plain = PerformanceCompiler.compile(.init(.init("hello")), for: .microduck)
        let gentle = PerformanceCompiler.compile(.init(.init("hello", delivery: .gentle)), for: .microduck)
        #expect(plain.units.last!.start < gentle.units.last!.start)
    }

    @Test func graphemesAndDeterminism() {
        let text = "Office café e\u{301} 👨‍👩‍👧‍👦 🐢\nこんにちは！"
        let line = DialogueLine(.init(text, effect: .bounce))
        let result = PerformanceCompiler.compile(line, for: .microduck)
        #expect(result.units.count == text.count)
        #expect(result.units.map(\.text).joined() == text)
        #expect(result.units.contains(where: { $0.text == "👨‍👩‍👧‍👦" }))
        #expect(result == PerformanceCompiler.compile(line, for: .microduck))
        #expect(Set(result.units.map(\.id)).count == result.units.count)
    }

    @Test(arguments: PetID.allCases) func everyAuthoredLineRenders(pet: PetID) throws {
        for sceneID in SceneID.allCases {
            let scene = SceneLibrary.scene(sceneID, for: pet)
            for line in [scene.opening] + scene.choices.flatMap(\.response) {
                let result = PerformanceCompiler.compile(line, for: pet)
                #expect(result.duration.isFinite)
                #expect(result.duration > result.units.last!.start)
                #expect(result.units.map(\.text).joined() == line.text)
                for pair in zip(result.chirps, result.chirps.dropFirst()) {
                    #expect(pair.0.start + pair.0.duration <= pair.1.start + 0.000_001)
                }
                let samples = try VoiceRenderer.render(result)
                #expect(samples.count == Int(ceil(result.duration * VoiceRenderer.sampleRate)))
                #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 0.6 })
            }
        }
    }

    @Test func audioRestsAndMouth() throws {
        let result = PerformanceCompiler.compile(.init(.init("a…b", effect: .bounce)), for: .microduck)
        let samples = try VoiceRenderer.render(result)
        let a = result.chirps[0]
        let b = result.chirps[1]
        #expect(a.start + a.duration <= result.units[1].start)
        let silenceStart = Int(ceil(result.units[1].start * VoiceRenderer.sampleRate))
        let silenceEnd = Int(b.start * VoiceRenderer.sampleRate)
        #expect(samples[silenceStart..<silenceEnd].allSatisfy { $0 == 0 })
        #expect(result.mouth(at: (a.start + a.duration + b.start) / 2) == 0)
        #expect(result.mouth(at: a.start + a.duration / 2) > 0.99)
    }
}
