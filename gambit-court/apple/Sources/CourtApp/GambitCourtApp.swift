import CourtCore
import SwiftUI

@main
struct GambitCourtApp: App {
    @StateObject private var store: CourtStore
    private let feedback = CourtFeedback()

    init() {
        Launch.registerFonts()
        let identity: String
        var identityError: String?
        do { identity = try Launch.identity() }
        catch { identity = UUID().uuidString; identityError = error.localizedDescription }
        let store = CourtStore(
            clientId: identity,
            endpoint: Launch.value("GC_SERVER") ?? UserDefaults.standard.string(forKey: "endpoint") ?? "ws://127.0.0.1:8765/ws",
            name: Launch.value("GC_NAME"),
            platform: Launch.platform,
            automation: Launch.value("GC_AUTOMATION") == "true"
        )
        if let theme = Launch.value("GC_THEME") {
            store.theme = theme
        }
        store.notice = identityError
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        #if os(macOS)
            Window("Gambit Court", id: "court") { content.frame(minWidth: 620, minHeight: 620) }
                .defaultSize(width: 1180, height: 850)
                .commands { courtCommands }
        #else
            WindowGroup { content }
        #endif
    }

    private var content: some View {
        CourtRoot(store: store)
            .preferredColorScheme(store.theme == "system" ? nil : store.theme == "light" ? .light : .dark)
            .font(.custom("Manrope-Regular", size: 14, relativeTo: .body))
            .tint(Arcade.royal)
            .task {
                store.feedback = { [weak store, feedback] effect in
                    guard let store else { return }
                    feedback.play(effect, sound: store.sound, haptics: store.haptics)
                }
                if store.connection.phase == .offline {
                    store.connect()
                }
            }
    }

    #if os(macOS)
        @CommandsBuilder private var courtCommands: some Commands {
            CommandMenu("Court") {
                Button("Flip board") { store.flipped.toggle() }.keyboardShortcut("f", modifiers: [.command])
                Button("Previous move") { store.step(-1) }.keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Next move") { store.step(1) }.keyboardShortcut(.rightArrow, modifiers: [.command])
                Button("Live position") { store.view(nil) }.keyboardShortcut(.downArrow, modifiers: [.command])
                Divider()
                Button("Copy PGN") { Launch.copy(store.pgn) }.keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Reconnect") { store.connect() }.keyboardShortcut("r", modifiers: [.command])
            }
        }
    #endif
}
