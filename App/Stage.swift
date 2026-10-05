import AppKit
import RealityKit
import simd

/// One robot on a transparent stage, with its camera, lights, and animator.
@MainActor final class Stage {
    /// The stage's size in the companion window, in points.
    static let viewportSize = CGSize(width: 728, height: 438)

    private static let restingYaw: Float = -0.13
    private static let fieldOfView: Float = 35

    let scene = AnchorEntity(world: .zero)
    let character = Entity()
    let environment: EnvironmentResource
    private let camera = PerspectiveCamera()
    private let animator: any CharacterAnimator
    private var microduckMaterials: MicroduckMaterials?
    private var framingCorners: [SIMD3<Float>] = []
    private var cameraAspect: Float = 0
    private var cursorPosition = SIMD2<Float>.zero
    private var cursorAngles = SIMD2<Float>.zero
    private var bodyYaw: Float = 0
    private var lastMotionTime: Double?

    init(pet: PetID) async throws {
        guard let folder = Bundle.main.url(forResource: pet.rawValue, withExtension: nil, subdirectory: "Models") else {
            throw ModelError.missingModel(pet)
        }
        async let lighting = StageLighting.environment()
        async let mesh = Entity(contentsOf: folder.appendingPathComponent("model.usdz"))
        let (loadedLighting, model) = try await (lighting, mesh)
        environment = loadedLighting
        try Task.checkCancellation()
        let orientation = Entity()
        orientation.addChild(model)
        animator = switch pet {
        case .microduck: try MicroduckAnimator(root: orientation)
        case .reachyMini: try ReachyMiniAnimator(root: orientation)
        }
        let framing = try JSONDecoder().decode([String: [Float]].self, from: Data(contentsOf: folder.appendingPathComponent("framing.json")))
        guard let minimum = framing["min"], let maximum = framing["max"], minimum.count == 3, maximum.count == 3,
              maximum[1] > minimum[1] else { throw ModelError.invalidFraming }
        let low = SIMD3(minimum[0], minimum[1], minimum[2])
        let high = SIMD3(maximum[0], maximum[1], maximum[2])
        let center = (low + high) / 2
        let base = SIMD3(center.x, low.y, center.z)
        let scale = 1.95 / (high.y - low.y)
        character.orientation = simd_quatf(angle: Self.restingYaw, axis: [0, 1, 0])
        for x in [low.x, high.x] {
            for y in [low.y, high.y] {
                for z in [low.z, high.z] {
                    framingCorners.append(character.orientation.act((SIMD3(x, y, z) - base) * scale))
                }
            }
        }
        // The camera frames every character at the same height. Microduck then
        // grows into part of the reaction headroom and sits slightly lower,
        // which keeps its toes inside the stage.
        let (stageScale, lift): (Float, Float) = switch pet {
        case .microduck: (1.12, -0.06)
        case .reachyMini: (1, 0)
        }
        orientation.scale = .init(repeating: scale * stageScale)
        orientation.position = -base * scale * stageScale
        character.position.y = lift
        character.addChild(orientation)
        scene.addChild(character)
        if pet == .microduck { microduckMaterials = try MicroduckMaterials(root: model) }
        Self.addHitShapes(below: model)
        configureStage()
    }

    /// The posed head's world-space bounds. Reactions sit beside the head
    /// rather than above it, because a large character leaves little headroom.
    var headBounds: BoundingBox? { animator.headEntity?.visualBounds(relativeTo: nil) }

    func setCursorPosition(_ position: SIMD2<Float>?) {
        cursorPosition = position ?? .zero
    }

    func setViewportSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let aspect = Float(size.width / size.height)
        guard abs(aspect - cameraAspect) > 0.001 else { return }
        cameraAspect = aspect
        let target = SIMD3<Float>(0, 1.1, 0)
        let baseline = SIMD3<Float>(0, 2.0, 3.7)
        let forward = simd_normalize(target - baseline)
        let right = SIMD3<Float>(1, 0, 0)
        let up = simd_cross(right, forward)
        let vertical = tan(Float.pi * Self.fieldOfView / 360) * 0.9
        var distance = simd_distance(target, baseline)
        // Fit the full model bounds in 90% of the viewport, which leaves headroom for reactions.
        for corner in framingCorners {
            let relative = corner - target
            let depth = simd_dot(relative, forward)
            distance = max(distance, abs(simd_dot(relative, right)) / (vertical * aspect) - depth)
            distance = max(distance, abs(simd_dot(relative, up)) / vertical - depth)
        }
        camera.look(at: target, from: target - forward * distance, relativeTo: nil)
    }

    func update(_ performance: Performance, id: UUID, time: Double, motionTime: Double,
                state: PlaybackState, reducedMotion: Bool) {
        updateCursorAttention(at: motionTime, reducedMotion: reducedMotion)
        character.orientation = simd_quatf(angle: Self.restingYaw + bodyYaw, axis: [0, 1, 0])
        let attention = SIMD3<Double>(-Double(cursorAngles.y), Double(cursorAngles.x), 0)
        animator.update(performance, id: id, time: time, idleTime: motionTime,
                        state: state, reducedMotion: reducedMotion, attention: attention)
    }

    func applyAppearance(_ appearance: MicroduckAppearance) { microduckMaterials?.apply(appearance) }

    func stop() { animator.stop() }

    private func updateCursorAttention(at motionTime: Double, reducedMotion: Bool) {
        if reducedMotion {
            cursorAngles = .zero
            bodyYaw = 0
            lastMotionTime = motionTime
            return
        }
        let elapsed = min(0.1, max(0, motionTime - (lastMotionTime ?? motionTime - 1.0 / 30)))
        lastMotionTime = motionTime
        let target = SIMD2(cursorPosition.x * 0.10, cursorPosition.y * 0.055)
        let blend = Float(1 - exp(-elapsed / 0.18))
        cursorAngles += (target - cursorAngles) * blend
        let bodyTarget = cursorPosition.x * 0.24
        let bodyBlend = Float(1 - exp(-elapsed / 0.32))
        bodyYaw += (bodyTarget - bodyYaw) * bodyBlend
    }

    private func configureStage() {
        camera.camera.fieldOfViewInDegrees = Self.fieldOfView
        camera.camera.near = 0.1
        camera.camera.far = 80
        setViewportSize(Self.viewportSize)
        scene.addChild(camera)
        StageLighting.apply(to: scene)
    }

    /// Pointer hit tests raycast against these convex hulls, which follow each
    /// rigid part as it animates. The models have about 800,000 vertices, so
    /// each hull uses a sample of up to 2,000 of its part's vertices.
    private static func addHitShapes(below entity: Entity) {
        if let model = entity as? ModelEntity, let mesh = model.model?.mesh {
            var points: [SIMD3<Float>] = []
            for instance in mesh.contents.instances {
                guard let source = mesh.contents.models[instance.model] else { continue }
                for part in source.parts {
                    for position in part.positions.elements {
                        let point = instance.transform * SIMD4(position, 1)
                        points.append(SIMD3(point.x, point.y, point.z))
                    }
                }
            }
            let step = max(1, (points.count + 1999) / 2000)
            let sample = stride(from: 0, to: points.count, by: step).map { points[$0] }
            if !sample.isEmpty {
                model.components.set(CollisionComponent(shapes: [ShapeResource.generateConvex(from: sample)]))
            }
        }
        for child in entity.children { addHitShapes(below: child) }
    }

    private enum ModelError: Error { case missingModel(PetID), invalidFraming }
}

// MARK: - Lighting

@MainActor private enum StageLighting {
    // A broad sky/ground source avoids hard directional-light terminators across
    // curved heads. Share the prefiltered environment across character switches.
    private static var environmentTask: Task<EnvironmentResource, Error>?

    static func environment() async throws -> EnvironmentResource {
        if let environmentTask { return try await environmentTask.value }
        let task = Task { @MainActor in
            let width = 256, height = 128
            var pixels = [UInt8](repeating: 255, count: width * height * 4)
            for y in 0..<height {
                let t = Double(y) / Double(height - 1)
                let sky = SIMD3<Double>(0.78, 0.86, 0.98)
                let horizon = SIMD3<Double>(0.94, 0.93, 0.87)
                let ground = SIMD3<Double>(0.62, 0.68, 0.53)
                let color = t < 0.5 ? sky + (horizon - sky) * (t * 2) : horizon + (ground - horizon) * ((t - 0.5) * 2)
                for x in 0..<width {
                    let i = (y * width + x) * 4
                    pixels[i] = UInt8(color.x * 255)
                    pixels[i+1] = UInt8(color.y * 255)
                    pixels[i+2] = UInt8(color.z * 255)
                }
            }
            let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
            return try await EnvironmentResource(equirectangular: image)
        }
        environmentTask = task
        do { return try await task.value }
        catch { environmentTask = nil; throw error }
    }

    static func apply(to root: Entity) {
        let sun = DirectionalLight()
        sun.light.color = NSColor(srgbRed: 1, green: 0.95, blue: 0.85, alpha: 1)
        // A restrained key retains form and ground shadows; the environment
        // supplies the fill instead of a second hard light behind the character.
        sun.light.intensity = 500
        sun.shadow = .init()
        sun.look(at: [0, 0, 0], from: [3, 6, 4], relativeTo: nil)
        root.addChild(sun)
    }
}
