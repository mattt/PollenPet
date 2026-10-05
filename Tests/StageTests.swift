import AppKit
import Foundation
import RealityKit
import Testing
import simd
@testable import PollenPet

@Suite("Stage", .serialized) @MainActor
struct StageTests {
    @Test(arguments: PetID.allCases)
    func loadsAndPosesTheHeadAboveTheStage(pet: PetID) async throws {
        let stage = try await Stage(pet: pet)
        let performance = PerformanceCompiler.compile(SceneLibrary.scene(.hello, for: pet).opening, for: pet)
        stage.update(performance, id: UUID(), time: 0.6, motionTime: 1, state: .playing, reducedMotion: false)
        #expect((stage.headBounds?.max.y ?? 0) > 1.5)
        stage.setViewportSize(Stage.viewportSize)
        stage.stop()
    }

    @Test(arguments: PetID.allCases)
    func reactionsFrameTheProjectedHead(pet: PetID) async throws {
        let stage = try await Stage(pet: pet)
        let view = ARView(frame: CGRect(origin: .zero, size: Stage.viewportSize))
        view.scene.addAnchor(stage.scene)
        let overlay = ReactionHostingView(rootView: .init(performance: nil, time: 0,
            active: false, reducedMotion: true, head: .zero, scale: 1))
        overlay.sizingOptions = []
        view.addSubview(overlay)
        for size in [Stage.viewportSize, CGSize(width: 364, height: 219), CGSize(width: 900, height: 520)] {
            view.setFrameSize(size)
            overlay.frame = view.bounds
            stage.setViewportSize(size)
            let bounds = try #require(stage.headBounds)
            let head = try #require(overlay.projectedRect(bounds, in: view))
            let feet = try #require(overlay.projectedAnchor(SIMD3<Float>(0, 0, 0), in: view))
            #expect(head.minY > 0)
            #expect(head.midY < size.height / 2)
            #expect(feet.y > size.height / 2)
            #expect(head.maxY < feet.y)
            #expect(abs(head.midX - size.width / 2) < size.width * 0.1)
            // Converting view coordinates must also respect an inset overlay frame.
            overlay.frame.origin.x += 12
            overlay.frame.origin.y += 8
            let inset = try #require(overlay.projectedRect(bounds, in: view))
            #expect(abs(inset.minX - (head.minX - 12)) < 0.001)
            #expect(abs(inset.minY - (head.minY + 8)) < 0.001)
        }
    }

    @Test(arguments: PetID.allCases)
    func wholeBodyFollowsPointerAndReturnsToRest(pet: PetID) async throws {
        let stage = try await Stage(pet: pet)
        let performance = PerformanceCompiler.compile(SceneLibrary.scene(.hello, for: pet).opening, for: pet)
        let id = UUID()
        func forwardX() -> Float {
            stage.character.orientation.act(SIMD3<Float>(0, 0, 1)).x
        }
        func advance(_ frames: ClosedRange<Int>, reducedMotion: Bool = false) {
            for frame in frames {
                stage.update(performance, id: id, time: 0, motionTime: Double(frame) / 10,
                             state: .idle, reducedMotion: reducedMotion)
            }
        }

        let restingX = forwardX()
        stage.setCursorPosition(SIMD2(1, 0))
        advance(0...15)
        #expect(forwardX() > restingX + 0.15)

        stage.setCursorPosition(SIMD2(-1, 0))
        advance(16...31)
        #expect(forwardX() < restingX - 0.15)

        stage.setCursorPosition(nil)
        advance(32...47)
        #expect(abs(forwardX() - restingX) < 0.01)

        stage.setCursorPosition(SIMD2(1, 0))
        advance(48...55)
        advance(56...56, reducedMotion: true)
        #expect(abs(forwardX() - restingX) < 0.0001)
    }
}
