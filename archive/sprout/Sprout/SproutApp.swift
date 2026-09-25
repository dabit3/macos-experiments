import SwiftUI

@main
struct SproutApp: App {
  @StateObject private var store = PlantStore()
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).tint(Palette.forest)
        .preferredColorScheme(.light)
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var store: PlantStore
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView {
      NavigationStack { ShelfView() }
        .tabItem { Label("My shelf", systemImage: "leaf") }
      NavigationStack { CareView() }
        .tabItem { Label("Care", systemImage: "drop") }
        .badge(store.due.count)
      NavigationStack { GuideView() }
        .tabItem { Label("Field guide", systemImage: "book.closed") }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.objectWillChange.send() }
    }
    .alert(
      "A little trouble saving",
      isPresented: Binding(
        get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
      )
    ) {
      Button("OK") { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? "")
    }
  }
}
