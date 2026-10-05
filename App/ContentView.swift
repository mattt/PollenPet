import SwiftUI

struct ContentView: View {
    private static let dialogueWidth = Stage.viewportSize.width
    private static let dialoguePadding: CGFloat = 28
    private static let endReplies = ["Let's talk about something else.", "Let's start again."]
    @Bindable var conversation: Conversation
    let appDelegate: AppDelegate
    @Binding var characterPickerRequested: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @AppStorage("instantText") private var instantText = false
    @AppStorage("muted") private var muted = false
    @State private var characterPickerPresented = false
    @State private var customizationPresented = false
    @State private var speech: SpeechText?
    @State private var modelError: String?
    @State private var stageSuspended = false
    @State private var motionStart = ProcessInfo.processInfo.systemUptime
    private var pet: PetID { conversation.pet }
    private var player: PlaybackController { conversation.playback }
    @Environment(MicroduckAppearanceStore.self) private var appearanceStore
    private var motionReduced: Bool { reducedMotion || ProcessInfo.processInfo.arguments.contains("--reduce-motion") }
    private var speechLineWidth: CGFloat { Self.dialogueWidth - 2 * Self.dialoguePadding }

    var body: some View {
        VStack(spacing: 12) {
            StageView(pet: pet,
                frame: { [conversation, player] in
                    StageFrame(performance: conversation.performance, performanceID: conversation.performanceID,
                               time: player.presentationTime, state: player.state)
                },
                motionStart: motionStart, paused: stageSuspended, appearance: appearanceStore.appearance,
                onLoading: { conversation.characterWillStartLoading($0) },
                onLoad: { loadedPet, error in
                    guard loadedPet == conversation.pet else { return }
                    modelError = error
                    conversation.characterDidFinishLoading(loadedPet)
                })
            .frame(width: Stage.viewportSize.width, height: Stage.viewportSize.height)
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents()
            .help("Drag the character to move the window")
            // Keep the entire robot above the dialogue panel.
            dialogueBox
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 12) {
                if conversation.choicesVisible {
                    replyMenu
                        .transition(replyTransition)
                } else if conversation.sceneFinished {
                    endMenu
                        .transition(replyTransition)
                }
                if let modelError {
                    Text(modelError).font(AppTypography.interface(12)).padding(16)
                        .background(AppTheme.paper, in: RoundedRectangle(cornerRadius: 18))
                        .background(CompanionShapeRegion(shape: RoundedRectangle(cornerRadius: 18)))
                }
            }
            .frame(width: 280, alignment: .trailing)
            .animation(replyAnimation, value: conversation.choicesVisible)
            .animation(replyAnimation, value: conversation.sceneFinished)

            // Keep replies above the dialogue text, with a small overlap at its rim.
            .alignmentGuide(.top) { dimensions in dimensions[.bottom] - 416 }
        }
        .padding(16)
        .frame(width: 760)
        .fixedSize(horizontal: false, vertical: true)
        .font(AppTypography.interface(13))
        .foregroundStyle(AppTheme.ink).tint(AppTheme.ink)
        .background(WindowLifecycle(
            onAttach: { appDelegate.registerCompanionWindow($0) },
            onPause: { stageSuspended = true; player.pause() },
            onResume: { stageSuspended = false; player.resume() },
            onClose: { stageSuspended = true; conversation.close() },
            onSpace: {
                // Replies handle Space themselves.
                guard !conversation.choicesVisible, !conversation.sceneFinished else { return false }
                conversation.advance()
                return true
            }))
        .onAppear {
            stageSuspended = false
            conversation.instantText = instantText || ProcessInfo.processInfo.arguments.contains("--instant")
            player.isMuted = muted
            let arguments = ProcessInfo.processInfo.arguments
            if let argument = arguments.first(where: { $0.hasPrefix("--pet=") }),
               let selected = PetID(rawValue: String(argument.dropFirst(6))) { conversation.select(pet: selected) }
            if let argument = arguments.first(where: { $0.hasPrefix("--scene=") }),
               let selected = SceneID(rawValue: String(argument.dropFirst(8))) { conversation.select(scene: selected) }
            speech = SpeechText(conversation.performance, lineWidth: speechLineWidth)
            conversation.replay()
        }
        .onChange(of: characterPickerRequested, initial: true) { _, requested in
            guard requested else { return }
            characterPickerRequested = false
            // Wait a turn, so that a reopened window is on screen before the popover attaches.
            Task { characterPickerPresented = true }
        }
        .onChange(of: conversation.performance) { _, performance in
            speech = SpeechText(performance, lineWidth: speechLineWidth)
        }
        // VoiceOver does not read label changes, so announce each line and the replies.
        .onChange(of: conversation.performanceID) { announceLine() }
        .onChange(of: conversation.isCharacterLoading) { announceLine() }
        .onChange(of: conversation.choicesVisible) { _, visible in
            if visible { announceReplies("Choose a reply", conversation.scene.choices.map(\.text)) }
        }
        .onChange(of: conversation.sceneFinished) { _, finished in
            if finished { announceReplies("Continue the conversation", Self.endReplies) }
        }
        .onChange(of: pet) { _, _ in modelError = nil }
        .onChange(of: muted) { _, value in player.isMuted = value }
        .onChange(of: instantText) { _, value in
            conversation.instantText = value
            if value && !player.isComplete { conversation.advance() }
        }
        .environment(\.reducePetMotion, motionReduced)
        .preferredColorScheme(.light)
    }

    private var dialogueBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                SpeechLine(text: speech?.text ?? Text(conversation.line.text), player: player)
                    .opacity(conversation.isCharacterLoading ? 0 : 1)
                    .accessibilityHidden(conversation.isCharacterLoading)
                if conversation.isCharacterLoading {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text("Here comes \(pet.name)…")
                            .font(AppTypography.interface(19))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(conversation.isCharacterLoading ? "Loading \(pet.name)" : conversation.line.text)
                .accessibilityAddTraits(.isStaticText)
            HStack {
                Spacer()
                Button { conversation.advance() } label: {
                    DialogueAdvanceMarker(active: player.isComplete && conversation.hasNext && !stageSuspended)
                        .opacity(player.isComplete ? 1 : 0).frame(width: 48, height: 26)
                        .animation(.easeOut(duration: 0.16), value: player.isComplete)
                }.buttonStyle(QuietButtonStyle())
                    .accessibilityLabel(player.isComplete ? "Continue dialogue" : "Reveal full line")
                    .disabled(conversation.isCharacterLoading || conversation.choicesVisible || conversation.sceneFinished)
                Spacer()
            }
        }.padding(.horizontal, Self.dialoguePadding).padding(.top, 52).padding(.bottom, 14).frame(width: Self.dialogueWidth)
            .comicPanel()
            .overlay(alignment: .topLeading) {
                HStack(spacing: 12) {
                    Button { characterPickerPresented.toggle() } label: {
                        HStack(spacing: 8) {
                            Text(pet.name)
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .font(AppTypography.heading(22)).foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .comicPanel(AppTheme.orange, radius: 10)
                    }
                        .buttonStyle(NameTagButtonStyle())
                        .help("Choose a character")
                        .accessibilityLabel("Choose a character, current character: \(pet.name)")
                        .popover(isPresented: $characterPickerPresented, arrowEdge: .top) {
                            CharacterPicker(conversation: conversation)
                        }
                        .background(CompanionShapeRegion(shape: RoundedRectangle(cornerRadius: 10)))
                    Spacer(minLength: 0)
                    if pet == .microduck {
                        Button { customizationPresented.toggle() } label: {
                            Label("Customize…", systemImage: "paintpalette")
                                .font(AppTypography.interface(13)).padding(12)
                                .comicPanel(AppTheme.yellow, radius: 10)
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel("Customize Microduck")
                        .popover(isPresented: $customizationPresented, arrowEdge: .top) {
                            MicroduckCustomizationView()
                        }
                        .background(CompanionShapeRegion(shape: RoundedRectangle(cornerRadius: 10)))
                    }
                }.frame(width: speechLineWidth).offset(x: 24, y: -18)
            }
            .background(CompanionShapeRegion(shape: RoundedRectangle(cornerRadius: AppTheme.radius)))
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.radius)).onTapGesture { conversation.advance() }
    }

    private func announceLine() {
        guard !conversation.isCharacterLoading else { return }
        var announcement = AttributedString(conversation.line.text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func announceReplies(_ title: String, _ replies: [String]) {
        let options = replies.enumerated().map { "\($0.offset + 1): \($0.element)" }
        AccessibilityNotification.Announcement("\(title). " + options.joined(separator: " ")).post()
    }

    private var replyMenu: some View {
        ReplyMenu(title: "Choose a reply", options: conversation.scene.choices.map { .init(id: $0.id, text: $0.text) }) { id in
            if let choice = conversation.scene.choices.first(where: { $0.id == id }) {
                conversation.choose(choice)
            }
        }
    }

    private var replyTransition: AnyTransition {
        .asymmetric(insertion: motionReduced ? .opacity :
            .scale(scale: 0.94, anchor: .bottomTrailing).combined(with: .opacity),
            removal: .opacity)
    }

    private var replyAnimation: Animation {
        motionReduced ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.82)
    }

    private var endMenu: some View {
        ReplyMenu(title: "Continue the conversation", options: Self.endReplies.enumerated().map {
            .init(id: $0.offset, text: $0.element)
        }) { id in
            if id == 0 {
                let scenes = SceneID.allCases
                conversation.select(scene: scenes[((scenes.firstIndex(of: conversation.sceneID) ?? 0) + 1) % scenes.count])
            } else {
                conversation.replay()
            }
        }
    }
}

/// Redraws only the dialogue text at the display's refresh rate while speech plays.
private struct SpeechLine: View {
    let text: Text
    let player: PlaybackController

    var body: some View {
        TimelineView(.animation(paused: player.state != .playing)) { _ in
            ExpressiveText(text: text, time: player.presentationTime, complete: player.isComplete)
        }
    }
}

private struct DialogueAdvanceMarker: View {
    let active: Bool
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(AppTheme.ink)
            .opacity(active ? 1 : 0.4)
            .accessibilityHidden(true)
    }
}
