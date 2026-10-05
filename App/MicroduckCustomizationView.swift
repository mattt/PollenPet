import SwiftUI

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
