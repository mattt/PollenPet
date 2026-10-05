import AppKit
import RealityKit

@MainActor enum StageLighting {
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
