import AppKit
import RealityKit

/// Holds references once, then changes only the selected outer materials.
@MainActor final class MicroduckMaterials {
    private let parts: [MicroduckPart: [ModelEntity]]
    private var applied: MicroduckAppearance?

    init(root: Entity) throws {
        var parts: [MicroduckPart: [ModelEntity]] = [:]
        for part in MicroduckPart.allCases {
            parts[part] = try part.meshNames.sorted().map { name in
                guard let model = root.findEntity(named: name) as? ModelEntity,
                      let materials = model.model?.materials, !materials.isEmpty,
                      materials.allSatisfy({ $0 is PhysicallyBasedMaterial }) else {
                    throw MaterialError.invalidMesh(name)
                }
                return model
            }
        }
        self.parts = parts
    }

    func apply(_ appearance: MicroduckAppearance) {
        guard appearance != applied else { return }
        for part in MicroduckPart.allCases where applied?[part] != appearance[part] {
            let rgb = appearance[part].rgb
            let color = NSColor(srgbRed: Double((rgb >> 16) & 255) / 255,
                                green: Double((rgb >> 8) & 255) / 255,
                                blue: Double(rgb & 255) / 255, alpha: 1)
            for entity in parts[part] ?? [] {
                guard var model = entity.model else { continue }
                model.materials = model.materials.map { original in
                    guard var material = original as? PhysicallyBasedMaterial else { return original }
                    material.baseColor = .init(tint: color)
                    return material
                }
                entity.model = model
            }
        }
        applied = appearance
    }

    enum MaterialError: Error { case invalidMesh(String) }
}
