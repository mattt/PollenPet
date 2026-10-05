import AppKit
import Observation
import RealityKit
import SwiftUI

// MARK: - Appearance

/// Stable IDs keep saved colors independent of display names and mesh names.
enum MicroduckColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case cream, graphite, lavender, sky, orange, yellow

    static let presets: [Self] = [.cream, .graphite, .lavender, .sky]

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var rgb: UInt32 {
        switch self {
        case .cream: 0xEEE6D2
        case .graphite: 0x41434B
        case .lavender: 0xB6A4DA
        case .sky: 0x8DC4DF
        case .orange: 0xF18B42
        case .yellow: 0xF5CC4D
        }
    }
}

enum MicroduckPart: String, CaseIterable, Identifiable, Sendable {
    case head, body, beak, feet

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var meshNames: Set<String> {
        switch self {
        case .head: ["top_head_shell_5", "bottom_head_shell_14"]
        case .body: ["right_shell_1", "left_shell_10"]
        case .beak: ["soft_mouth_top_10", "jaw_soft_3", "jaw_12"]
        case .feet: ["foot_left_2", "foot_right_4"]
        }
    }
}

struct MicroduckAppearance: Codable, Equatable, Sendable {
    private(set) var schemaVersion = 1
    private(set) var preset: MicroduckColor?
    private(set) var head: MicroduckColor
    private(set) var body: MicroduckColor
    private(set) var beak: MicroduckColor
    private(set) var feet: MicroduckColor

    static let cream = Self(preset: .cream)

    init(preset: MicroduckColor) {
        precondition(MicroduckColor.presets.contains(preset), "\(preset) is not a preset")
        self.preset = preset
        head = preset
        body = preset
        beak = .orange
        feet = .orange
    }

    var title: String { preset?.title ?? "Custom" }

    subscript(part: MicroduckPart) -> MicroduckColor {
        get {
            switch part {
            case .head: head
            case .body: body
            case .beak: beak
            case .feet: feet
            }
        }
        set {
            guard self[part] != newValue else { return }
            preset = nil
            switch part {
            case .head: head = newValue
            case .body: body = newValue
            case .beak: beak = newValue
            case .feet: feet = newValue
            }
        }
    }

    static func restored(from data: Data?) -> Self {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data),
              value.schemaVersion == 1 else { return .cream }
        if let preset = value.preset {
            guard MicroduckColor.presets.contains(preset), value == Self(preset: preset) else { return .cream }
        }
        return value
    }
}

// MARK: - Store

@MainActor @Observable final class MicroduckAppearanceStore {
    private static let key = "microduckAppearance"

    private(set) var appearance: MicroduckAppearance
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = .restored(from: defaults.data(forKey: Self.key))
    }

    func save(_ value: MicroduckAppearance) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.key)
        appearance = value
    }
}

// MARK: - Materials

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

    private enum MaterialError: Error { case invalidMesh(String) }
}

// MARK: - Customization

struct MicroduckCustomizationView: View {
    @Environment(MicroduckAppearanceStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("MAKE IT YOURS").font(AppTypography.heading(21))
                Spacer()
                Text(store.appearance.title.uppercased()).font(AppTypography.label(11))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .comicPanel(AppTheme.yellow, radius: 7)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("FACTORY COLORS").font(AppTypography.label(11))
                HStack(spacing: 7) {
                    ForEach(MicroduckColor.presets) { color in
                        swatch(color, selected: store.appearance.preset == color,
                               label: "\(color.title) preset") {
                            store.save(.init(preset: color))
                        }
                    }
                }
            }

            Divider().overlay(AppTheme.ink)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(MicroduckPart.allCases) { part in
                    HStack(spacing: 6) {
                        Text(part.title).font(AppTypography.interface(13))
                            .frame(width: 38, alignment: .leading)
                        ForEach(MicroduckColor.allCases) { color in
                            swatch(color, selected: store.appearance[part] == color,
                                   label: "\(part.title): \(color.title)") {
                                var appearance = store.appearance
                                appearance[part] = color
                                store.save(appearance)
                            }
                        }
                    }
                }
            }

            HStack {
                Text("Colors are visual approximations.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("Reset colors") { store.save(.cream) }
                    .font(AppTypography.interface(12))
            }
        }
        .padding(16)
        .frame(width: 280)
        .comicPanel()
        .padding(6)
        .foregroundStyle(AppTheme.ink).tint(AppTheme.ink)
        .preferredColorScheme(.light)
        .onExitCommand { dismiss() }
    }

    private func swatch(_ color: MicroduckColor, selected: Bool, label: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 7).fill(Color(hex: color.rgb))
                .frame(width: 24, height: 26)
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(AppTheme.ink, lineWidth: selected ? 3 : 1) }
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color == .graphite ? .white : AppTheme.ink)
                    }
                }
        }
        .buttonStyle(.plain).help(label)
        .accessibilityLabel(label).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
