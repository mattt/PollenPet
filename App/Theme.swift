import SwiftUI

enum AppTypography {
    static func heading(_ size: CGFloat) -> Font { .custom("Anton-Regular", size: size) }
    static func dialogue(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    static func interface(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    static func label(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

enum AppTheme {
    static let paper = Color(hex: 0xFFF8E8)
    static let ink = Color(hex: 0x101018)
    static let orange = Color(hex: 0xFF7A2F)
    static let yellow = Color(hex: 0xFFD23F)
    static let border: CGFloat = 2
    static let radius: CGFloat = 18
    static let shadow: CGFloat = 4
}

extension View {
    func comicPanel(_ fill: Color = AppTheme.paper, radius: CGFloat = AppTheme.radius) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius)
                .fill(AppTheme.ink).offset(x: AppTheme.shadow, y: AppTheme.shadow)
            RoundedRectangle(cornerRadius: radius).fill(fill)
            RoundedRectangle(cornerRadius: radius).strokeBorder(AppTheme.ink, lineWidth: AppTheme.border)
        }
    }
}

extension EnvironmentValues {
    @Entry var reducePetMotion = false
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension PetID {
    /// The background behind the character's portrait.
    var tagColor: Color {
        switch self {
        case .microduck: Color(hex: 0xF7C632)
        case .reachyMini: Color(hex: 0xD6E5ED)
        }
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.reducePetMotion) private var reducedMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

struct NameTagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}
