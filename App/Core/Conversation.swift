import Observation
import Foundation

@MainActor @Observable final class Conversation {
    private(set) var pet: PetID = .microduck
    private(set) var sceneID: SceneID = .hello
    private(set) var line: DialogueLine
    private(set) var performance: Performance
    private(set) var performanceID = UUID()
    private(set) var response: [DialogueLine] = []
    private(set) var responseIndex = -1
    let playback: PlaybackController
    var instantText = false
    private(set) var isCharacterLoading = true
    /// Whether the companion window is open. Closing it ends the presentation.
    private(set) var isPresenting = true

    @ObservationIgnored private var preparation: Task<Void, Never>?

    init(playback: PlaybackController) {
        self.playback = playback
        playback.setPresentationReady(false)
        let line = SceneLibrary.scene(.hello, for: .microduck).opening
        self.line = line
        performance = PerformanceCompiler.compile(line, for: .microduck)
    }

    var scene: DialogueScene { SceneLibrary.scene(sceneID, for: pet) }
    var choicesVisible: Bool {
        guard !isCharacterLoading, responseIndex == -1 else { return false }
        return playback.isComplete ||
            ((playback.state == .playing || playback.state == .paused) && playback.reachedReplyTime)
    }
    var hasNext: Bool { responseIndex >= 0 && responseIndex + 1 < response.count }
    var sceneFinished: Bool { playback.isComplete && responseIndex >= 0 && !hasNext }

    func select(pet: PetID) {
        if self.pet != pet {
            isCharacterLoading = true
            playback.setPresentationReady(false)
        }
        self.pet = pet
        replay()
    }

    func select(scene: SceneID) {
        sceneID = scene
        replay()
    }

    func replay() {
        isPresenting = true
        playback.setPresentationReady(!isCharacterLoading)
        response = []
        responseIndex = -1
        show(scene.opening)
    }

    func choose(_ choice: DialogueChoice) {
        guard choicesVisible, scene.choices.contains(where: { $0.id == choice.id }) else { return }
        response = choice.response
        responseIndex = 0
        if let first = response.first { show(first, acknowledgingReply: true) }
    }

    func advance() {
        guard !isCharacterLoading, !choicesVisible else { return }
        guard playback.isComplete else {
            preparation?.cancel()
            playback.revealAll()
            return
        }
        guard hasNext else { return }
        responseIndex += 1
        show(response[responseIndex])
    }

    func close() {
        isPresenting = false
        playback.setPresentationReady(false)
        preparation?.cancel()
        playback.stop()
        // A window can close while minimized. Clear that suspension so that
        // the next presentation does not start paused.
        playback.resume()
    }

    func characterWillStartLoading(_ pet: PetID) {
        guard self.pet == pet else { return }
        isCharacterLoading = true
        playback.setPresentationReady(false)
    }

    /// Also releases the dialogue fallback if a model fails to load.
    func characterDidFinishLoading(_ pet: PetID) {
        guard isPresenting, self.pet == pet else { return }
        isCharacterLoading = false
        playback.setPresentationReady(true)
    }

    private func show(_ line: DialogueLine, acknowledgingReply: Bool = false) {
        preparation?.cancel()
        playback.stop()
        self.line = line
        performanceID = UUID()
        performance = PerformanceCompiler.compile(line, for: pet, acknowledgingReply: acknowledgingReply)
        let performance = performance
        let instant = instantText
        preparation = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.playback.start(performance, instant: instant)
        }
    }
}
