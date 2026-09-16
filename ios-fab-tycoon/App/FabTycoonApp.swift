import SwiftUI

@main
struct FabTycoonApp: App {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup {
      RootView(store: store)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { store.save() }
          if phase == .active { store.applyOffline() }
        }
    }
  }
}

enum Screen { case title, game }
enum GameTab: String, CaseIterable {
  case fabs = "Fabs"
  case upgrades = "Upgrades"
  case research = "R&D"
  case market = "Market"
  case awards = "Awards"
  var symbol: String {
    ["cpu.fill", "arrow.up.circle.fill", "flask.fill", "chart.xyaxis.line", "rosette"][
      Self.allCases.firstIndex(of: self)!]
  }
}

struct RootView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    ZStack {
      CircuitBackground()
      if store.screen == .title { TitleView(store: store) } else { GameView(store: store) }
      ToastView(store: store)
      if store.flash {
        Theme.green.opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
          .transition(.opacity).animation(.easeOut(duration: 0.6), value: store.flash)
      }
    }
    .tint(Theme.green)
    .sheet(isPresented: $store.showingSettings) { SettingsView(store: store) }
    .sheet(
      item: Binding(
        get: { store.offlineReport.map(OfflineBox.init) }, set: { _ in store.offlineReport = nil })
    ) { box in
      OfflineSheet(report: box.report)
    }
  }
}

private struct OfflineBox: Identifiable {
  let id = UUID()
  let report: OfflineReport
  init(_ report: OfflineReport) { self.report = report }
}
