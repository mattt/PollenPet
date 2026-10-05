import SwiftUI

struct SettingsView: View {
    @Bindable var conversation: Conversation
    @State private var characterPickerPresented = false
    @State private var customizationPresented = false
    @AppStorage("instantText") private var instantText = false
    @AppStorage("muted") private var muted = false

    var body: some View {
        TabView {
            Form {
                Section("Conversation") {
                    LabeledContent("Character") {
                        Button { characterPickerPresented.toggle() } label: {
                            HStack(spacing: 8) {
                                CharacterAvatar(pet: conversation.pet, size: 26)
                                Text(conversation.pet.name)
                                Image(systemName: "chevron.down").font(.caption)
                            }
                        }
                        .popover(isPresented: $characterPickerPresented) {
                            CharacterPicker(conversation: conversation)
                        }
                    }
                    if conversation.pet == .microduck {
                        Button("Customize Microduck…") { customizationPresented.toggle() }
                            .popover(isPresented: $customizationPresented) {
                                MicroduckCustomizationView()
                            }
                        Link("Microduck by Pollen Robotics", destination: URL(string: "https://pollen-robotics.com/microduck/")!)
                            .font(.callout)
                        Text("The model is licensed for noncommercial use.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else if conversation.pet == .reachyMini {
                        Link("Reachy Mini by Pollen Robotics", destination: URL(string: "https://pollen-robotics.com/reachy-mini/")!)
                            .font(.callout)
                        Text("Visualization model by Clément Plays. Licensed under Apache 2.0.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Picker("Scene", selection: Binding(
                        get: { conversation.sceneID },
                        set: { conversation.select(scene: $0) })) {
                        ForEach(SceneID.allCases) { scene in
                            Text(scene.title).tag(scene)
                        }
                    }
                    Button("Replay scene") { conversation.replay() }
                }

                Section("At your own pace") {
                    Toggle("Show text instantly", isOn: $instantText)
                    Toggle("Mute sound", isOn: $muted)
                    Text("Respects your Mac’s Reduce Motion setting.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Section("Controls") {
                    Text("Drag the character to move the window. Click the dialogue or press Space to reveal or continue. Use ↑ / ↓ and Return, or 1 / 2, to choose a reply.")
                    Text("⌘R replays the scene. ⌘K chooses a character. ⌘, opens Settings.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            ScrollView { CreditsView() }
                .tabItem { Label("Credits", systemImage: "info.circle") }
        }
        .padding(16)
        .frame(width: 580, height: 440)
    }
}

private struct CreditsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("POLLEN PET").font(AppTypography.heading(24))
            Text("Microduck model by Pollen Robotics, converted from microduck_rl. Hardware design files: Creative Commons BY-SA-NC (version not specified upstream). Noncommercial use only; no affiliation or endorsement. Conversion details and source hashes are in ThirdParty/microduck-sources.json.")
            Link("Microduck source and license notice", destination: URL(string: "https://github.com/pollen-robotics/microduck_rl")!)
            Text("Reachy Mini visualization model and rig by Clément Plays for Pollen Robotics. Converted from reachy_mini_blender under Apache 2.0. Conversion details and source hashes are in ThirdParty/reachy-mini-sources.json.")
            Link("Reachy Mini source and license notice", destination: URL(string: "https://github.com/pollen-robotics/reachy_mini_blender")!)
            Text("Both voices are synthesized in the app. Dialogue is original. The interface takes its colors and comic-panel style from the Microduck website.").font(.system(size: 11))
            Text("Anton by Vernon Adams is licensed under the SIL Open Font License 1.1. Dialogue and controls use the system font.").font(.system(size: 11))
        }.font(.system(size: 13)).padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }
}
