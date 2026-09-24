import SwiftUI

enum Screen: Hashable {
    case home
    case cards
    case battle
    case results
}

enum Theme {
    static let background = Color(red: 0.07, green: 0.10, blue: 0.20)
    static let panel = Color(red: 0.13, green: 0.17, blue: 0.30)
    static let accent = Color(red: 1.0, green: 0.72, blue: 0.20)
    static let elixir = Color(red: 0.86, green: 0.30, blue: 0.95)
    static let player = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let enemy = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let grass = Color(red: 0.36, green: 0.62, blue: 0.30)
    static let grassDark = Color(red: 0.31, green: 0.56, blue: 0.26)
    static let river = Color(red: 0.25, green: 0.55, blue: 0.85)
    static let bridge = Color(red: 0.62, green: 0.45, blue: 0.25)
}

@main
struct TowerTussleApp: App {
    @StateObject private var profile = PlayerProfile()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var profile: PlayerProfile
    @State private var screen: Screen = .home
    @State private var engine: BattleEngine? = nil
    @State private var lastResult: MatchResult? = nil

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch screen {
            case .home:
                HomeView(onBattle: startBattle, onCards: { screen = .cards })
                    .transition(.opacity)
            case .cards:
                CardsView(onBack: { screen = .home }, onBattle: startBattle)
                    .transition(.move(edge: .trailing))
            case .battle:
                if let engine {
                    BattleView(engine: engine, onFinished: { result in
                        profile.apply(result)
                        lastResult = result
                        screen = .results
                    }, onQuit: {
                        engine.surrender()
                    })
                }
            case .results:
                if let lastResult {
                    ResultsView(result: lastResult, onHome: { screen = .home }, onCards: { screen = .cards }, onRematch: startBattle)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
    }

    private func startBattle() {
        let e = BattleEngine(deck: profile.deck)
        engine = e
        screen = .battle
    }
}
