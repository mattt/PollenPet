import Foundation
import RealityKit
import Testing
import simd
@testable import PollenPet

// MARK: - Microduck

@Suite("Microduck rigid assembly", .serialized) @MainActor
struct MicroduckTests {
    private func load() async throws -> Entity {
        let url = try #require(Bundle.main.url(forResource: "model", withExtension: "usdz", subdirectory: "Models/microduck"))
        return try await Entity(contentsOf: url)
    }

    @Test func assemblyKeepsItsMaterialsAndServoHierarchy() async throws {
        let root = try await load()
        let animator = try MicroduckAnimator(root: root)
        let head = try #require(animator.headEntity?.position(relativeTo: nil))
        let left = try #require(root.findEntity(named: "left_ankle"))
        let right = try #require(root.findEntity(named: "right_ankle"))
        #expect(head.y > left.position(relativeTo: nil).y + 0.1)
        #expect(head.y > right.position(relativeTo: nil).y + 0.1)
        #expect(abs(left.position(relativeTo: nil).y - right.position(relativeTo: nil).y) < 0.001)
        var meshes = 0
        func check(_ entity: Entity) {
            if let model = entity as? ModelEntity, let component = model.model {
                meshes += 1
                #expect(!component.materials.isEmpty)
            }
            for child in entity.children { check(child) }
        }
        check(root)
        #expect(meshes > 30)
    }

    @Test func seekingPauseReducedMotionAndStopKeepFeetPlanted() async throws {
        let root = try await load()
        let animator = try MicroduckAnimator(root: root)
        let pitch = try #require(root.findEntity(named: "head_pitch"))
        let yaw = try #require(root.findEntity(named: "head_yaw"))
        let foot = try #require(root.findEntity(named: "left_ankle"))
        let bind = pitch.transform
        let yawBind = yaw.transform
        let footBind = foot.transformMatrix(relativeTo: nil)
        let performance = PerformanceCompiler.compile(.init(.init("Hello there!", gesture: .welcome)), for: .microduck)
        let id = UUID()
        func update(_ time: Double, _ state: PlaybackState = .playing, reduced: Bool = false) {
            animator.update(performance, id: id, time: time, idleTime: 0, state: state, reducedMotion: reduced)
        }
        update(0.6)
        let playing = pitch.transform
        let turned = yaw.transform
        #expect(playing != bind)
        #expect(turned != yawBind)
        update(0.6, .paused)
        #expect(yaw.transform == turned)
        update(2)
        update(0.6)
        #expect(pitch.transform == playing)
        #expect(foot.transformMatrix(relativeTo: nil) == footBind)
        update(0.6, reduced: true)
        #expect(pitch.transform == bind)
        #expect(yaw.transform == yawBind)
        animator.stop()
        #expect(pitch.transform == bind)
        #expect(foot.transformMatrix(relativeTo: nil) == footBind)
    }

    @Test func mouthFollowsSpeechAndClosesDuringRestsAndPlaybackChanges() async throws {
        let root = try await load()
        let animator = try MicroduckAnimator(root: root)
        let mouth = try #require(root.findEntity(named: "mouth_hinge"))
        let jaw = try #require(root.findEntity(named: "jaw_12"))
        let pad = try #require(root.findEntity(named: "jaw_soft_3"))
        let upper = try #require(root.findEntity(named: "soft_mouth_top_10"))
        let head = try #require(root.findEntity(named: "head_roll"))
        #expect(jaw.parent === mouth)
        #expect(pad.parent === mouth)
        #expect(upper.parent === head)
        let closed = mouth.transform
        let upperRest = upper.transform
        let performance = PerformanceCompiler.compile(.init(.init("abcdef ghijkl")), for: .microduck)
        let id = UUID()
        let movement = try #require(performance.chirps.first)
        let peak = movement.start + movement.duration / 2
        func update(_ time: Double, _ state: PlaybackState = .playing, reduced: Bool = false) {
            animator.update(performance, id: id, time: time, idleTime: 0,
                            state: state, reducedMotion: reduced)
        }
        update(peak)
        let open = mouth.transform
        #expect(open != closed)
        #expect(abs(mouth.orientation.angle - 0.28) < 0.001)
        #expect(upper.transform == upperRest)
        // The head frame has X up and Z toward the back. The beak tip moves down.
        let tip = SIMD3<Float>(-0.0202, 0, -0.058)
        #expect(mouth.convert(position: tip, to: head).x < closed.matrix.columns.3.x + tip.x - 0.01)
        update(performance.units[7].start - 0.01) // Between words.
        #expect(mouth.transform == closed)
        update(peak)
        #expect(mouth.transform == open)
        for state in [PlaybackState.paused, .finished, .idle, .preparing] {
            update(peak, state)
            #expect(mouth.transform == closed)
        }
        update(peak, reduced: true)
        #expect(mouth.transform == closed)
        update(peak)
        #expect(mouth.transform == open)
        animator.stop()
        #expect(mouth.transform == closed)
    }
}

// MARK: - Reachy Mini

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
