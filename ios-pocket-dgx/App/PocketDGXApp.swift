import SwiftUI

@main
struct PocketDGXApp: App {
  @StateObject private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .statusBarHidden(store.screen == .rig)
    }
  }
}

struct RootView: View {
  @EnvironmentObject var store: AppStore

  var body: some View {
    ZStack {
      switch store.screen {
      case .title:
        TitleView().transition(.opacity.combined(with: .scale(scale: 1.04)))
      case .rig:
        if let scene = store.scene {
          RigView(scene: scene).transition(.opacity)
        }
      }
      if let toast = store.toast {
        VStack {
          Spacer()
          Text(toast).font(.label(13)).tracking(2).foregroundStyle(Palette.mint).panel(glow: true)
            .padding(.bottom, 120)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
      }
    }
    .sheet(
      isPresented: Binding(get: { store.sharing != nil }, set: { if !$0 { store.sharing = nil } })
    ) {
      if let image = store.sharing {
        ShareSheet(items: [image, "\(store.caption) #PocketDGX"])
          .presentationDetents([.medium, .large])
      }
    }
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
