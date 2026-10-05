import SwiftUI

@main
struct App: SwiftUI.App {
    static let companionWindowID = "companion"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var conversation = Conversation(playback: PlaybackController(audio: EngineAudioOutput()))
    @State private var appearanceStore = MicroduckAppearanceStore()
    @State private var characterPickerRequested = false

    var body: some Scene {
        Window("Pollen Pet", id: Self.companionWindowID) {
            ContentView(conversation: conversation, appDelegate: delegate,
                        characterPickerRequested: $characterPickerRequested)
                .environment(appearanceStore)
                .containerBackground(.clear, for: .window)
        }
        .defaultSize(width: 760, height: 634)
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Conversation") {
                ConversationCommands(conversation: conversation,
                                     characterPickerRequested: $characterPickerRequested)
            }
        }

        Settings {
            SettingsView(conversation: conversation).environment(appearanceStore)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Commands

/// These commands also work while the companion window is closed.
private struct ConversationCommands: View {
    let conversation: Conversation
    @Binding var characterPickerRequested: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // The companion window handles Space itself. As a menu key equivalent,
        // Space would take key presses from controls in Settings and popovers.
        Button("Reveal or Continue") { conversation.advance() }
            .disabled(!conversation.isPresenting || conversation.choicesVisible || conversation.sceneFinished)
        Button("Replay Scene") {
            // Opening the window starts the scene from the beginning.
            if conversation.isPresenting { conversation.replay() }
            else { openWindow(id: App.companionWindowID) }
        }
        .keyboardShortcut("r", modifiers: .command)
        Divider()
        Button("Choose Character…") {
            openWindow(id: App.companionWindowID)
            characterPickerRequested = true
        }
        .keyboardShortcut("k", modifiers: .command)
    }
}

// MARK: - App Delegate

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var companionWindow: NSWindow?

    func registerCompanionWindow(_ window: NSWindow) {
        companionWindow = window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard let companionWindow,
              companionWindow.isVisible || companionWindow.isMiniaturized else { return true }
        if companionWindow.isMiniaturized { companionWindow.deminiaturize(nil) }
        sender.activate(ignoringOtherApps: true)
        companionWindow.makeKeyAndOrderFront(nil)
        return false
    }
}
