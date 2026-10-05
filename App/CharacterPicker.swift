import AppKit
import SwiftUI

struct CharacterPicker: View {
    @Bindable var conversation: Conversation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("CHOOSE A CHARACTER")
                    .font(AppTypography.heading(22))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close character picker")
                .accessibilityLabel("Close character picker")
            }

            HStack(spacing: 16) {
                ForEach(PetID.allCases) { pet in
                    Button {
                        if conversation.pet != pet { conversation.select(pet: pet) }
                        dismiss()
                    } label: {
                        characterCard(for: pet)
                    }
                    .buttonStyle(QuietButtonStyle())
                    .help("Choose \(pet.name)")
                    .accessibilityLabel(pet.name)
                    .accessibilityValue(conversation.pet == pet ? "Current character" : "")
                    .accessibilityAddTraits(conversation.pet == pet ? .isSelected : [])
                }
            }
        }
        .padding(20)
        .frame(width: 448)
        .comicPanel()
        .padding(6)
        .font(AppTypography.interface(13))
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.ink)
        .preferredColorScheme(.light)
        .onExitCommand { dismiss() }
    }

    private func characterCard(for pet: PetID) -> some View {
        let selected = conversation.pet == pet
        return VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(pet.tagColor.opacity(0.55))
                CharacterPortrait(pet: pet)
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppTheme.paper, AppTheme.ink)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 152)

            Text(pet.name)
                .font(AppTypography.heading(21))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 12)
            Text(selected ? "CURRENT CHARACTER" : "CHOOSE CHARACTER")
                .font(AppTypography.label(10))
                .foregroundStyle(AppTheme.ink.opacity(0.7))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(selected ? AppTheme.yellow.opacity(0.35) : .white.opacity(0.7))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppTheme.ink, lineWidth: selected ? 3 : 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct CharacterPortrait: View {
    private static let images: [PetID: NSImage] = Dictionary(uniqueKeysWithValues: PetID.allCases.compactMap { pet in
        Bundle.main.url(forResource: pet.rawValue, withExtension: "png", subdirectory: "Portraits")
            .flatMap(NSImage.init(contentsOf:)).map { (pet, $0) }
    })

    let pet: PetID

    var body: some View {
        if let image = Self.images[pet] {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        }
    }
}

struct CharacterAvatar: View {
    let pet: PetID
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(pet.tagColor.gradient)
            CharacterPortrait(pet: pet)
                .padding(size * 0.09)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
