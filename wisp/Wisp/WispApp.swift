import SwiftUI

@main
struct WispApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .tint(.ink)
                .preferredColorScheme(app.settings.appearance.colorScheme)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            if app.hasKey {
                ChatScreen()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: app.hasKey)
        .overlay {
            if scenePhase != .active { PrivacyShield() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: app.sceneDidEnterBackground()
            case .active: app.sceneDidBecomeActive()
            default: break
            }
        }
    }
}

/// Covers the transcript in the app switcher and system snapshots.
private struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            WispMark(size: 44)
        }
        .accessibilityHidden(true)
    }
}
