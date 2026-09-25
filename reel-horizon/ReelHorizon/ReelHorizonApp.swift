import SwiftUI

@main
struct ReelHorizonApp: App {
  @StateObject private var store = GameStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
  }
}

struct RootView: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    ZStack {
      Theme.night.ignoresSafeArea()
      switch store.screen {
      case .home: HomeView().transition(.opacity)
      case .location(let id): LocationView(waterway: WaterwayCatalog.find(id)).transition(.move(edge: .trailing))
      case .shop: ShopView().transition(.move(edge: .bottom))
      case .missions: MissionsView().transition(.move(edge: .bottom))
      case .profile: ProfileView().transition(.move(edge: .bottom))
      case .fishing: FishingView().transition(.opacity)
      case .daySummary: DaySummaryView().transition(.opacity)
      }
      ToastStack()
      if let level = store.levelUpTo {
        LevelUpOverlay(level: level) { store.levelUpTo = nil }
      }
      if store.showTutorial && store.screen == .home {
        TutorialOverlay {
          store.showTutorial = false
          store.profile.tutorialSeen = true
          store.save()
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("root.\(screenID)")
  }

  private var screenID: String {
    switch store.screen {
    case .home: return "home"
    case .location: return "location"
    case .shop: return "shop"
    case .missions: return "missions"
    case .profile: return "profile"
    case .fishing: return "fishing"
    case .daySummary: return "summary"
    }
  }
}

/// Top chrome shared by menu screens: back button, title, level/XP, currencies.
struct HeaderBar: View {
  @EnvironmentObject var store: GameStore
  let title: String
  var back: Screen? = .home

  var body: some View {
    HStack(spacing: 12) {
      if let back {
        Button { store.go(back) } label: {
          Image(systemName: "chevron.left").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panelLight))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))
        }
        .accessibilityIdentifier("header.back")
      }
      Text(title).font(Theme.display(24)).textCase(.uppercase).kerning(1.5).foregroundStyle(Theme.ink)
        .lineLimit(1).fixedSize()
        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
        .accessibilityIdentifier("header.title")
      Spacer()
      PlayerStrip()
    }
  }
}

struct PlayerStrip: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    HStack(spacing: 10) {
      LevelBadge(level: store.profile.level)
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(store.profile.name).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
          Text("LVL \(store.profile.level)").font(Theme.mono(10)).foregroundStyle(Theme.inkDim)
        }
        .lineLimit(1)
        MeterBar(value: store.profile.levelProgress, height: 6).frame(width: 120)
      }
      Divider().frame(height: 26).overlay(Theme.panelStroke)
      CurrencyChip(kind: .credits, amount: store.profile.credits).accessibilityIdentifier("strip.credits")
      CurrencyChip(kind: .baitcoins, amount: store.profile.baitcoins)
    }
    .lineLimit(1)
    .fixedSize()
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.panel))
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.panelStroke))
    .layoutPriority(1)
  }
}

struct ToastStack: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    VStack {
      Spacer()
      VStack(spacing: 6) {
        ForEach(store.toasts) { toast in
          Text(toast.text)
            .font(Theme.body(14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(
              Capsule().fill(
                toast.kind == .success ? Theme.greenDeep : toast.kind == .warning ? Color(red: 0.6, green: 0.15, blue: 0.1) : Theme.cyanDeep
              ).opacity(0.95))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .padding(.bottom, 70)
    }
    .animation(.spring(response: 0.35), value: store.toasts)
    .allowsHitTesting(false)
  }
}

struct LevelUpOverlay: View {
  let level: Int
  let dismiss: () -> Void
  @State private var appear = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: dismiss)
      VStack(spacing: 14) {
        Text("LEVEL UP").font(Theme.display(38)).kerning(3).foregroundStyle(Theme.gold)
          .shadow(color: Theme.gold.opacity(0.8), radius: 12)
        LevelBadge(level: level, size: 90)
        let unlocked = WaterwayCatalog.all.filter { $0.requiredLevel == level }
        let gear = TackleCatalog.all.filter { $0.requiredLevel == level }
        if let w = unlocked.first {
          Text("New waterway unlocked: \(w.name)").font(Theme.body(15)).foregroundStyle(Theme.ink)
        }
        if !gear.isEmpty {
          Text("\(gear.count) new item\(gear.count == 1 ? "" : "s") available in the shop").font(Theme.body(14)).foregroundStyle(Theme.inkDim)
        }
        ChromeButton(title: "Continue", tone: .gold, action: dismiss).accessibilityIdentifier("levelup.continue")
      }
      .padding(28)
      .panel(padding: 24, radius: 16, light: true)
      .scaleEffect(appear ? 1 : 0.7)
      .opacity(appear ? 1 : 0)
    }
    .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appear = true } }
  }
}

struct TutorialOverlay: View {
  let dismiss: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.7).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        Text("WELCOME TO REEL HORIZON").font(Theme.display(28)).kerning(2).foregroundStyle(Theme.cyan)
        tip("map", "Pick a waterway on the map. Lone Pine Lake is free and your 3-day license is already paid.")
        tip("cart", "Spend credits in the shop on rods, reels, line, lures and bait. Better tackle unlocks with your level.")
        tip("hand.tap", "Hold CAST and release at the right moment. When the float dips, hit STRIKE within the window.")
        tip("gauge.with.needle", "Hold REEL to bring the fish in and keep the line meter out of the red. Let go when the fish runs.")
        tip("dollarsign.circle", "Keep or release your catch, then sell the keepnet at the end of the day for credits and XP.")
        HStack { Spacer(); ChromeButton(title: "Let's fish", tone: .green, action: dismiss).accessibilityIdentifier("tutorial.dismiss") }
      }
      .frame(maxWidth: 560)
      .panel(padding: 22, radius: 14, light: true)
    }
  }

  private func tip(_ icon: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.gold).frame(width: 22)
      Text(text).font(Theme.body(14, weight: .medium)).foregroundStyle(Theme.ink)
    }
  }
}
