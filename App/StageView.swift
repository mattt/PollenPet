import Combine
import SwiftUI
import RealityKit

/// The speech state that one rendered frame of the stage shows.
struct StageFrame {
    let performance: Performance
    let performanceID: UUID
    let time: Double
    let state: PlaybackState
}

/// Hosts the RealityKit stage and the reaction overlay above it.
struct StageView: NSViewRepresentable {
    let pet: PetID
    /// RealityKit reads this once per rendered frame, outside SwiftUI updates,
    /// so the character moves at the display's refresh rate.
    let frame: @MainActor () -> StageFrame
    let motionStart: TimeInterval
    let paused: Bool
    let appearance: MicroduckAppearance
    let onLoading: (PetID) -> Void
    let onLoad: (PetID, String?) -> Void
    @Environment(\.reducePetMotion) private var reducedMotion

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ARView {
        let view = StageARView(frame: .zero)
        view.environment.background = .color(.clear)
        view.setAccessibilityElement(false)
        configure(view, context: context)
        let overlay = ReactionHostingView(rootView: .init(performance: nil, time: 0, active: false,
            reducedMotion: false, head: .zero, scale: 1))
        overlay.sizingOptions = []
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.setAccessibilityElement(false)
        view.addSubview(overlay)
        context.coordinator.overlay = overlay
        context.coordinator.sceneUpdates = view.scene.subscribe(to: SceneEvents.Update.self) {
            [weak view, weak coordinator = context.coordinator] _ in
            guard let view, let coordinator, !coordinator.paused else { return }
            coordinator.render(in: view)
        }
        return view
    }

    func updateNSView(_ view: ARView, context: Context) {
        let coordinator = context.coordinator
        coordinator.frame = frame
        coordinator.motionStart = motionStart
        coordinator.paused = paused
        coordinator.reducedMotion = reducedMotion
        coordinator.appearance = appearance
        if coordinator.requestedPet != pet { configure(view, context: context) }
        coordinator.world?.applyAppearance(appearance)
    }

    static func dismantleNSView(_ view: ARView, coordinator: Coordinator) {
        coordinator.sceneUpdates?.cancel()
        coordinator.sceneUpdates = nil
        coordinator.world?.stop()
        coordinator.loadTask?.cancel()
        coordinator.requestedPet = nil
        view.scene.anchors.removeAll()
        coordinator.world = nil
        coordinator.frame = nil
        coordinator.overlay?.removeFromSuperview()
        coordinator.overlay = nil
    }

    private func configure(_ view: ARView, context: Context) {
        let coordinator = context.coordinator
        coordinator.loadTask?.cancel()
        coordinator.world?.stop()
        coordinator.world = nil
        coordinator.requestedPet = pet
        view.scene.anchors.removeAll()
        let selectedPet = pet
        coordinator.loadTask = Task { @MainActor [weak view, weak coordinator] in
            do {
                try Task.checkCancellation()
                onLoading(selectedPet)
                let world = try await Stage(pet: selectedPet)
                try Task.checkCancellation()
                guard let view, let coordinator, coordinator.requestedPet == selectedPet else { return }
                coordinator.world = world
                view.environment.lighting.resource = world.environment
                view.environment.lighting.intensityExponent = 1
                view.scene.addAnchor(world.scene)
                world.applyAppearance(coordinator.appearance)
                coordinator.render(in: view)
                // Asset loading completes before RealityKit's first GPU frame.
                // Wait for actual character pixels, including with Reduce Motion on.
                if let view = view as? StageARView {
                    try await view.waitForVisibleCharacter()
                }
                try Task.checkCancellation()
                guard coordinator.requestedPet == selectedPet else { return }
                onLoad(selectedPet, nil)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, coordinator?.requestedPet == selectedPet else { return }
                onLoad(selectedPet, "The character model could not be loaded: \(error.localizedDescription)")
            }
        }
    }

    @MainActor final class Coordinator {
        var world: Stage?
        var frame: (@MainActor () -> StageFrame)?
        var motionStart: TimeInterval = 0
        var paused = false
        var reducedMotion = false
        var appearance = MicroduckAppearance.cream
        var requestedPet: PetID?
        var loadTask: Task<Void, Never>?
        var sceneUpdates: (any Cancellable)?
        var overlay: ReactionHostingView?
        private var overlayShown = false

        func render(in view: ARView) {
            guard let world, let frame else { return }
            let stage = frame()
            world.setViewportSize(view.bounds.size)
            world.setCursorPosition((view as? StageARView)?.pointerPosition)
            world.update(stage.performance, id: stage.performanceID, time: stage.time,
                         motionTime: ProcessInfo.processInfo.systemUptime - motionStart,
                         state: stage.state, reducedMotion: reducedMotion)
            updateOverlay(stage, world: world, in: view)
        }

        /// The overlay is a SwiftUI hosting view. Leave it alone between reactions
        /// instead of rebuilding an empty canvas on every frame.
        private func updateOverlay(_ stage: StageFrame, world: Stage, in view: ARView) {
            guard let overlay else { return }
            let active = stage.state == .playing || stage.state == .paused
            let reacting = active && stage.performance.reactions.contains {
                stage.time >= $0.start && stage.time < $0.end
            }
            guard reacting || overlayShown, let bounds = world.headBounds,
                  let head = overlay.projectedRect(bounds, in: view) else { return }
            overlayShown = reacting
            overlay.rootView = .init(performance: stage.performance, time: stage.time, active: reacting,
                reducedMotion: reducedMotion, head: head, scale: min(1.3, max(0.7, view.bounds.height / 400)))
        }
    }
}

private final class StageARView: ARView, CompanionHitRegion {
    func waitForVisibleCharacter() async throws {
        while true {
            try Task.checkCancellation()
            if window?.isVisible == true, bounds.width > 0, bounds.height > 0 {
                let image: NSImage? = await withCheckedContinuation { continuation in
                    snapshot(saveToHDR: false) { continuation.resume(returning: $0) }
                }
                try Task.checkCancellation()
                if let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                   Self.containsVisiblePixels(cgImage) { return }
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// A tiny alpha thumbnail detects a rendered silhouette without reading every
    /// pixel of a Retina snapshot. The stage background itself is transparent.
    private static func containsVisiblePixels(_ image: CGImage) -> Bool {
        var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 32,
                bitsPerComponent: 8, bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 12 }
        }
    }

    /// Each rigid part carries a convex collision shape that follows its joint,
    /// so a raycast matches the current pose without reading back a frame.
    func acceptsCompanionHit(at point: NSPoint) -> Bool {
        let local = convert(point, from: nil)
        guard bounds.contains(local), !isHiddenOrHasHiddenAncestor else { return false }
        return !hitTest(local, query: .any).isEmpty
    }

    /// The pointer in stage coordinates from -1 to 1, or `nil` outside the stage.
    /// It reads the screen position, because the window ignores mouse events
    /// while the pointer is away from the robot and the dialogue.
    var pointerPosition: SIMD2<Float>? {
        guard let window, window.isVisible, bounds.width > 0, bounds.height > 0 else { return nil }
        let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        guard bounds.contains(point) else { return nil }
        return SIMD2(Float(point.x / bounds.width * 2 - 1), Float(point.y / bounds.height * 2 - 1))
    }
}
