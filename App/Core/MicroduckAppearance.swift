import Foundation
import Observation

/// Stable IDs keep saved colors independent of display names and mesh names.
enum MicroduckColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case cream, graphite, lavender, sky, orange, yellow
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
    static let presets: [Self] = [.cream, .graphite, .lavender, .sky]
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
            switch part { case .head: head; case .body: body; case .beak: beak; case .feet: feet }
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

@MainActor @Observable final class MicroduckAppearanceStore {
    static let key = "microduckAppearance"
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
