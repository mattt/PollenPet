import Foundation
import RealityKit
import Testing
@testable import PollenPet

@Suite("Reachy Mini model", .serialized) @MainActor
struct ReachyMiniTests {
    @Test func headMovesWhileBodyRemainsFixed() async throws {
        let model = try #require(Bundle.main.url(forResource: "model", withExtension: "usdz", subdirectory: "Models/reachy-mini"))
        let root = try await Entity(contentsOf: model)
        let animator = try ReachyMiniAnimator(root: root)
        let head = try #require(root.findEntity(named: "Head"))
        let body = try #require(root.findEntity(named: "Body"))
        let headBind = head.transform
        let bodyBind = body.transformMatrix(relativeTo: nil)
        let performance = PerformanceCompiler.compile(
            .init(.init("Hello there!", gesture: .welcome)), for: .reachyMini)
        let id = UUID()

        animator.update(performance, id: id, time: 0.6, idleTime: 0,
                        state: .playing, reducedMotion: false)
        #expect(head.transform != headBind)
        #expect(body.transformMatrix(relativeTo: nil) == bodyBind)
        animator.update(performance, id: id, time: 0.6, idleTime: 0,
                        state: .playing, reducedMotion: true)
        #expect(head.transform == headBind)
        animator.stop()
        #expect(head.transform == headBind)
        #expect(body.transformMatrix(relativeTo: nil) == bodyBind)
    }
}
