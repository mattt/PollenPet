import SwiftUI

struct ReplyOption: Identifiable, Equatable {
    let id: Int
    let text: String
}

/// Native buttons retain their activation and accessibility actions. The menu
/// adds arrow navigation and keeps pointer, keyboard, and accessibility selection aligned.
struct ReplyMenu: View {
    let title: String
    let options: [ReplyOption]
    let onSelect: (Int) -> Void
    @State private var selection: Int?
    @FocusState private var focusedOption: Int?
    @AccessibilityFocusState private var accessibleOption: Int?
    @Environment(\.reducePetMotion) private var reducedMotion
    private var ink: Color { AppTheme.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button { onSelect(option.id) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)").font(AppTypography.label(13))
                            .frame(width: 24, height: 24)
                            .background(AppTheme.yellow, in: RoundedRectangle(cornerRadius: 6))
                        Text(option.text).font(AppTypography.interface(16))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(ink)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(selection == option.id ? AppTheme.yellow.opacity(0.35) : .clear,
                                in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(selection == option.id ? ink : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .focusable()
                .focusEffectDisabled()
                .focused($focusedOption, equals: option.id)
                .accessibilityLabel(option.text)
                .accessibilityValue("\(index + 1) of \(options.count)")
                .accessibilityAddTraits(selection == option.id ? .isSelected : [])
                .accessibilityFocused($accessibleOption, equals: option.id)
                .onHover { over in if over { focus(option.id) } }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
            }
        }
        .padding(12)
        .comicPanel()
        .background(CompanionShapeRegion(shape: RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)))
        .animation(reducedMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onAppear { focus(options.first?.id) }
        .onChange(of: options) { _, _ in focus(options.first?.id) }
        .onChange(of: focusedOption) { _, id in if let id { selection = id } }
        .onChange(of: accessibleOption) { _, id in
            if let id { selection = id; focusedOption = id }
        }
        .onMoveCommand { direction in
            switch direction {
            case .up: move(-1)
            case .down: move(1)
            default: break
            }
        }
        .onKeyPress(.return, phases: .down) { _ in activate() }
        .onKeyPress(.space, phases: .down) { _ in activate() }
    }

    private func focus(_ id: Int?) {
        selection = id
        focusedOption = id
        if accessibleOption != nil { accessibleOption = id }
    }

    private func move(_ offset: Int) {
        guard !options.isEmpty else { return }
        let current = options.firstIndex { $0.id == selection } ?? 0
        let next = min(options.count - 1, max(0, current + offset))
        focus(options[next].id)
    }

    private func activate() -> KeyPress.Result {
        guard let selection, options.contains(where: { $0.id == selection }) else { return .ignored }
        onSelect(selection)
        return .handled
    }
}
