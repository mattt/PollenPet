import Foundation
import Testing
@testable import PollenPet

@MainActor private final class TestClock: PlaybackClock {
    var now: TimeInterval = 0
}

@MainActor private final class TestAudio: AudioOutput {
    var elapsed: TimeInterval?
    var isMuted = false
    var fails = false
    var stops = 0
    var plays = 0
    var pauses = 0
    func prepare(samples: [Float]) throws {
        if fails { throw Failure.unavailable }
    }
    func play() throws {
        if fails { throw Failure.unavailable }
        plays += 1
    }
    func pause() { pauses += 1 }
    func stop() { stops += 1; elapsed = nil }
    enum Failure: Error { case unavailable }
}

@Suite("Playback and conversation") @MainActor
struct PlaybackTests {
    @Test func repliesAppearAtTheQuestionWithoutStoppingItsSound() async throws {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.characterDidFinishLoading(.microduck)
        let performance = conversation.performance
        await player.start(performance)
        let question = try #require(performance.accents.last { $0.kind == .question })
        audio.elapsed = question.start - 0.001
        player.tick()
        #expect(!conversation.choicesVisible)
        player.isMuted = true // The presentation clock also works when muted.
        let stops = audio.stops
        audio.elapsed = question.start
        player.tick()
        #expect(conversation.choicesVisible)
        #expect(!player.isComplete)
        #expect(audio.stops == stops)
        conversation.advance() // Background clicks must not cut off the accent.
        #expect(player.state == .playing)
        #expect(audio.stops == stops)
        player.pause()
        #expect(conversation.choicesVisible)
        player.resume()
        #expect(conversation.choicesVisible)
        let choice = conversation.scene.choices[0]
        conversation.choose(choice)
        #expect(conversation.responseIndex == 0)
        #expect(!conversation.choicesVisible)
        conversation.replay()
        #expect(!conversation.choicesVisible)
        conversation.close()
    }

    private var example: Performance {
        PerformanceCompiler.compile(.init(.init("Well… hello there! Really?")), for: .microduck)
    }

    @Test func audioClockMuteAndReveal() async {
        let clock = TestClock()
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, clock: clock, automaticTick: false)
        await player.start(example)
        clock.now = 0.9
        audio.elapsed = 0.4
        player.tick()
        #expect(player.elapsed == 0.4)
        player.isMuted = true
        #expect(audio.isMuted)
        audio.elapsed = 0.6
        player.tick()
        #expect(player.elapsed == 0.6)
        let previousStops = audio.stops
        player.revealAll()
        #expect(player.isComplete)
        #expect(player.elapsed == example.duration)
        #expect(audio.stops == previousStops + 1)
        clock.now = 10
        player.tick()
        #expect(player.elapsed == example.duration)
    }

    @Test func presentationTimeReadsTheClockBetweenTicks() async {
        let clock = TestClock()
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, clock: clock, automaticTick: false)
        await player.start(example)
        audio.elapsed = 0.4
        #expect(player.presentationTime == 0.4)
        #expect(player.elapsed == 0)
        player.tick()
        audio.elapsed = 0.3 // A late audio report never rewinds the frame.
        #expect(player.presentationTime == 0.4)
        player.pause()
        audio.elapsed = 0.8
        #expect(player.presentationTime == 0.4)
        player.revealAll()
        #expect(player.presentationTime == example.duration)
    }

    @Test func replyCueFlagFollowsTheClockAndResets() async throws {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let performance = PerformanceCompiler.compile(SceneLibrary.scene(.hello, for: .microduck).opening, for: .microduck)
        await player.start(performance)
        let replyTime = performance.replyPresentationTime
        audio.elapsed = replyTime - 0.001
        player.tick()
        #expect(!player.reachedReplyTime)
        audio.elapsed = replyTime
        player.tick()
        #expect(player.reachedReplyTime)
        player.stop()
        #expect(!player.reachedReplyTime)
        await player.start(performance)
        #expect(!player.reachedReplyTime)
    }

    @Test func fallbackPauseResumeAndCompletion() async {
        let clock = TestClock()
        let audio = TestAudio()
        audio.fails = true
        let player = PlaybackController(audio: audio, clock: clock, automaticTick: false)
        await player.start(example)
        #expect(player.audioUnavailable)
        clock.now = 0.5
        player.tick()
        #expect(player.elapsed == 0.5)
        player.pause()
        clock.now = 30
        player.tick()
        #expect(player.elapsed == 0.5)
        player.resume()
        clock.now = 30.25
        player.tick()
        #expect(player.elapsed == 0.75)
        clock.now = 100
        player.tick()
        #expect(player.isComplete)
        #expect(player.elapsed == example.duration)
    }

    @Test func stopAndReplayReset() async {
        let clock = TestClock()
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, clock: clock, automaticTick: false)
        await player.start(example)
        clock.now = 1
        player.tick()
        player.stop()
        #expect(player.state == .idle)
        #expect(player.performance == nil)
        #expect(player.elapsed == 0)
        await player.start(example)
        #expect(player.state == .playing)
        #expect(player.elapsed == 0)
        #expect(audio.plays == 2)
        player.stop()
    }

    @Test func instantSkipsAudioAndSuspensionSurvivesPreparation() async {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        await player.start(example, instant: true)
        #expect(player.isComplete)
        #expect(audio.plays == 0)
        player.pause()
        await player.start(example)
        #expect(player.state == .paused)
        #expect(audio.plays == 0)
        player.resume()
        #expect(player.state == .playing)
        #expect(audio.plays == 1)
        player.stop()
    }

    @Test func cancelledPreparationCannotRestart() async {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let long = PerformanceCompiler.compile(.init(.init(String(repeating: "hello ", count: 700))), for: .microduck)
        let task = Task { await player.start(long) }
        while player.state != .preparing { await Task.yield() }
        player.stop()
        task.cancel()
        await task.value
        #expect(player.state == .idle)
        #expect(player.performance == nil)
        #expect(audio.plays == 0)
    }

    @Test func characterReadinessHoldsPreparedAudioAndRespectsWindowPause() async {
        let clock = TestClock()
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, clock: clock, automaticTick: false)
        player.setPresentationReady(false)
        await player.start(example)
        #expect(player.state == .paused)
        #expect(audio.plays == 0)
        clock.now = 10
        player.resume() // Waking the window cannot bypass the character gate.
        player.tick()
        #expect(player.elapsed == 0)
        #expect(audio.plays == 0)
        player.pause()
        player.setPresentationReady(true)
        #expect(player.state == .paused)
        #expect(audio.plays == 0)
        player.resume()
        #expect(audio.plays == 1)
        #expect(player.elapsed == 0)
        clock.now = 10.25
        player.tick()
        #expect(player.elapsed == 0.25)
        player.setPresentationReady(true)
        #expect(audio.plays == 1)
        player.stop()
    }

    @Test func loadingGatesInstantTextSwitchingAndStaleCompletions() async {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.instantText = true
        conversation.replay()
        for _ in 0..<100 where player.state != .preparing { await Task.yield() }
        conversation.advance()
        #expect(!player.isComplete)
        #expect(conversation.isCharacterLoading)
        #expect(!conversation.choicesVisible)
        conversation.select(pet: .reachyMini)
        conversation.characterDidFinishLoading(.microduck)
        #expect(conversation.isCharacterLoading)
        conversation.characterDidFinishLoading(.reachyMini)
        await settle(player)
        #expect(conversation.choicesVisible)
        #expect(!conversation.isCharacterLoading)
        #expect(audio.plays == 0)
        conversation.replay() // Same-character replay does not require another load.
        await settle(player)
        conversation.select(pet: .microduck)
        conversation.close()
        conversation.characterDidFinishLoading(.microduck)
        #expect(player.state == .idle)
        #expect(conversation.isCharacterLoading)
    }

    @Test func reopeningRetainedAndRecreatedStagesUsesCurrentReadiness() async {
        let player = PlaybackController(audio: TestAudio(), automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.instantText = true
        conversation.characterDidFinishLoading(.microduck)
        conversation.replay()
        await settle(player)
        conversation.close()
        conversation.replay() // A retained native view already has its character.
        await settle(player)
        conversation.close()
        conversation.characterWillStartLoading(.microduck) // A recreated view must render again.
        conversation.replay()
        for _ in 0..<100 where player.state != .preparing { await Task.yield() }
        #expect(conversation.isCharacterLoading)
        #expect(!player.isComplete)
        conversation.characterDidFinishLoading(.microduck)
        await settle(player)
        conversation.close()
    }

    @Test func everyBranchEndsAndSwitchingResets() async {
        let player = PlaybackController(audio: TestAudio(), automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.instantText = true
        for pet in PetID.allCases {
            conversation.select(pet: pet)
            conversation.characterDidFinishLoading(pet)
            for scene in SceneID.allCases {
                conversation.select(scene: scene)
                for choice in conversation.scene.choices {
                    conversation.replay()
                    await settle(player)
                    #expect(conversation.choicesVisible)
                    #expect(conversation.responseIndex == -1)
                    conversation.choose(choice)
                    await settle(player)
                    #expect(conversation.responseIndex == 0)
                    #expect(conversation.hasNext)
                    conversation.advance()
                    await settle(player)
                    #expect(conversation.responseIndex == 1)
                    #expect(conversation.sceneFinished)
                    #expect(!conversation.choicesVisible)
                }
            }
        }
        conversation.select(pet: .microduck)
        conversation.characterDidFinishLoading(.microduck)
        await settle(player)
        #expect(conversation.responseIndex == -1)
        #expect(conversation.response.isEmpty)
        #expect(conversation.choicesVisible)
        conversation.close()
        #expect(player.state == .idle)
    }

    @Test func choosingAcknowledgesOnlyTheFirstResponseAndReplayCancelsIt() async {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.characterDidFinishLoading(.microduck)
        conversation.instantText = true
        conversation.select(scene: .package)
        await settle(player)
        conversation.choose(conversation.scene.choices[0])
        await settle(player)
        #expect(conversation.performance.acknowledgesReply)
        #expect(audio.plays == 0)
        conversation.advance()
        await settle(player)
        #expect(!conversation.performance.acknowledgesReply)
        conversation.replay()
        await settle(player)
        #expect(!conversation.performance.acknowledgesReply)
        conversation.instantText = false
        conversation.choose(conversation.scene.choices[1])
        conversation.select(pet: .microduck)
        conversation.characterDidFinishLoading(.microduck)
        for _ in 0..<100 where player.state != .playing { await Task.yield() }
        #expect(conversation.performance.pet == .microduck)
        #expect(!conversation.performance.acknowledgesReply)
        conversation.close()
        #expect(player.state == .idle)
    }

    @Test func closingWhileSuspendedDoesNotPauseTheNextPresentation() async throws {
        let audio = TestAudio()
        let player = PlaybackController(audio: audio, automaticTick: false)
        let conversation = Conversation(playback: player)
        conversation.characterDidFinishLoading(.microduck)
        player.pause() // The window is minimized,
        conversation.close() // and then closed.
        #expect(!conversation.isPresenting)
        conversation.replay() // Reopening the window starts the scene again.
        #expect(conversation.isPresenting)
        for _ in 0..<200 where player.state != .playing { try await Task.sleep(for: .milliseconds(10)) }
        #expect(player.state == .playing)
        #expect(audio.plays == 1)
        conversation.close()
    }

    private func settle(_ player: PlaybackController) async {
        for _ in 0..<100 where !player.isComplete { await Task.yield() }
        #expect(player.isComplete)
    }
}
