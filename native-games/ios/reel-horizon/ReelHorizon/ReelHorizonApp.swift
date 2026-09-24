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
      case .location(let id): LocationView(waterway: WaterwayCatalog.find(id)).transition(Self.slide)
      case .shop: ShopView().transition(Self.slide)
      case .missions: MissionsView().transition(Self.slide)
      case .profile: ProfileView().transition(Self.slide)
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

  private static let slide = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .scale(scale: 1.03)),
    removal: .opacity
  )

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
  var subtitle: String? = nil
  var back: Screen? = .home

  var body: some View {
    HStack(spacing: 12) {
      if let back {
        Button { store.go(back) } label: {
          Image(systemName: "chevron.left").font(.system(size: 16, weight: .black)).foregroundStyle(Theme.ink)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Theme.panelLightTop))
            .overlay(Circle().strokeBorder(.white.opacity(0.18)))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("header.back")
      }
      VStack(alignment: .leading, spacing: 0) {
        if let subtitle {
          Text(subtitle).capsLabel(10, color: Theme.cyan).lineLimit(1)
        }
        Text(title).font(Theme.display(26)).textCase(.uppercase).kerning(1.5).foregroundStyle(Theme.ink)
          .lineLimit(1).minimumScaleFactor(0.7)
          .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
          .accessibilityIdentifier("header.title")
      }
      .layoutPriority(0)
      Spacer(minLength: 8)
      PlayerStrip()
    }
    .frame(height: 46)
  }
}

struct PlayerStrip: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    HStack(spacing: 10) {
      LevelBadge(level: store.profile.level, size: 32)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(store.profile.name).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
          Text("LVL \(store.profile.level)").font(Theme.mono(9)).foregroundStyle(Theme.cyan)
        }
        .lineLimit(1)
        MeterBar(value: store.profile.levelProgress, height: 5).frame(width: 110)
      }
      Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 26)
      CurrencyChip(kind: .credits, amount: store.profile.credits).accessibilityIdentifier("strip.credits")
      CurrencyChip(kind: .baitcoins, amount: store.profile.baitcoins)
    }
    .lineLimit(1)
    .fixedSize()
    .padding(.leading, 6)
    .padding(.trailing, 14)
    .padding(.vertical, 5)
    .background(Capsule().fill(Theme.panel).background(Capsule().fill(.ultraThinMaterial).opacity(0.4)))
    .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    .layoutPriority(1)
  }
}

struct ToastStack: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    VStack {
      VStack(spacing: 6) {
        ForEach(store.toasts) { toast in
          HStack(spacing: 8) {
            Image(systemName: icon(toast.kind)).font(.system(size: 13, weight: .bold)).foregroundStyle(tint(toast.kind))
            Text(toast.text).font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.ink)
          }
          .padding(.horizontal, 16).padding(.vertical, 9)
          .background(Capsule().fill(Theme.night.opacity(0.85)).background(Capsule().fill(.ultraThinMaterial)))
          .overlay(Capsule().strokeBorder(tint(toast.kind).opacity(0.6), lineWidth: 1))
          .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
          .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
        }
      }
      .padding(.top, 64)
      Spacer()
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.toasts)
    .allowsHitTesting(false)
  }

  private func tint(_ kind: Toast.Kind) -> Color {
    switch kind {
    case .success: return Theme.green
    case .warning: return Theme.orange
    default: return Theme.cyan
    }
  }

  private func icon(_ kind: Toast.Kind) -> String {
    switch kind {
    case .success: return "checkmark.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    default: return "info.circle.fill"
    }
  }
}

/// Rotating sunburst drawn behind celebratory cards.
struct Sunburst: View {
  var color: Color = Theme.gold
  var rays = 16
  @State private var spin = false

  var body: some View {
    Canvas { ctx, size in
      let c = CGPoint(x: size.width / 2, y: size.height / 2)
      let r = max(size.width, size.height)
      for i in 0..<rays {
        let a0 = Double(i) / Double(rays) * 2 * .pi
        let a1 = a0 + .pi / Double(rays) * 0.8
        var p = Path()
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
        p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
        p.closeSubpath()
        ctx.fill(p, with: .color(color.opacity(0.10)))
      }
    }
    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 10, endRadius: 260))
    .rotationEffect(.degrees(spin ? 360 : 0))
    .onAppear { withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true } }
    .allowsHitTesting(false)
  }
}

struct LevelUpOverlay: View {
  let level: Int
  let dismiss: () -> Void
  @State private var appear = false

  var body: some View {
    let unlocked = WaterwayCatalog.all.filter { $0.requiredLevel == level }
    let gear = TackleCatalog.all.filter { $0.requiredLevel == level }
    ZStack {
      Color.black.opacity(0.65).ignoresSafeArea().onTapGesture(perform: dismiss)
      Sunburst().frame(width: 700, height: 700).opacity(appear ? 1 : 0)
      VStack(spacing: 12) {
        Text("LEVEL UP").font(Theme.display(40)).kerning(4)
          .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
          .shadow(color: Theme.gold.opacity(0.7), radius: 14)
        LevelBadge(level: level, size: 92)
          .scaleEffect(appear ? 1 : 0.4)
          .rotationEffect(.degrees(appear ? 0 : -40))
        HStack(spacing: 10) {
          if let w = unlocked.first {
            StatTile(icon: "map.fill", label: "New waterway", value: w.name, tint: Theme.cyan).frame(width: 220)
          }
          if !gear.isEmpty {
            StatTile(icon: "cart.fill", label: "Shop unlocks", value: "\(gear.count) new item\(gear.count == 1 ? "" : "s")", tint: Theme.gold).frame(width: 200)
          }
        }
        ChromeButton(title: "Continue", icon: "arrow.right", tone: .gold, minWidth: 180, action: dismiss).accessibilityIdentifier("levelup.continue")
          .padding(.top, 4)
      }
      .padding(.horizontal, 20)
      .panel(padding: 24, radius: 22, light: true)
      .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5))
      .scaleEffect(appear ? 1 : 0.7)
      .opacity(appear ? 1 : 0)
    }
    .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appear = true } }
  }
}

struct TutorialOverlay: View {
  let dismiss: () -> Void
  @State private var appear = false

  private let steps: [(String, String, String)] = [
    ("map.fill", "Pick a spot", "Lone Pine Lake is free and your 3-day license is paid."),
    ("cart.fill", "Gear up", "Rods, reels, line, lures and bait. Better tackle unlocks as you level."),
    ("hand.tap.fill", "Cast & strike", "Hold CAST, release for distance. When the float dips, hit STRIKE."),
    ("gauge.with.needle.fill", "Fight", "Hold REEL, keep the line meter out of the red. Ease off when it runs."),
    ("dollarsign.circle.fill", "Sell", "Keep or release. Sell the keepnet at day's end for credits and XP."),
  ]

  var body: some View {
    ZStack {
      Color.black.opacity(0.72).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 12) {
          AppMark(size: 40)
          VStack(alignment: .leading, spacing: 0) {
            Text("WELCOME, ANGLER").capsLabel(11, color: Theme.cyan)
            Text("REEL HORIZON").font(Theme.display(28)).kerning(3).foregroundStyle(Theme.ink)
          }
        }
        HStack(alignment: .top, spacing: 10) {
          ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Image(systemName: step.0).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.gold)
                  .frame(width: 34, height: 34).background(Circle().fill(Theme.gold.opacity(0.14)))
                Spacer()
                Text("0\(index + 1)").font(Theme.mono(11)).foregroundStyle(Theme.inkDim)
              }
              Text(step.1).font(Theme.display(15)).textCase(.uppercase).foregroundStyle(Theme.ink)
              Text(step.2).font(Theme.body(11, weight: .medium)).foregroundStyle(Theme.inkDim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.06 * Double(index)), value: appear)
          }
        }
        HStack {
          Text("Tip: drag across the water to aim your cast.").font(Theme.body(11)).foregroundStyle(Theme.inkDim)
          Spacer()
          ChromeButton(title: "Let's fish", icon: "figure.fishing", tone: .green, minWidth: 170, action: dismiss).accessibilityIdentifier("tutorial.dismiss")
        }
      }
      .frame(maxWidth: 720)
      .panel(padding: 18, radius: 20, light: true)
      .padding(.horizontal, 40)
      .padding(.vertical, 12)
    }
    .onAppear { appear = true }
  }
}

/// Circular brand mark: a hooked fish on a horizon.
struct AppMark: View {
  var size: CGFloat = 36

  var body: some View {
    ZStack {
      Circle().fill(LinearGradient(colors: [Color(red: 0.99, green: 0.62, blue: 0.30), Color(red: 0.55, green: 0.22, blue: 0.45)], startPoint: .top, endPoint: .center))
      Circle().fill(LinearGradient(colors: [Theme.cyanDeep, Color(red: 0.02, green: 0.18, blue: 0.32)], startPoint: .top, endPoint: .bottom))
        .mask(VStack(spacing: 0) { Color.clear; Color.white }.frame(width: size, height: size))
      Circle().fill(Theme.gold).frame(width: size * 0.32).offset(y: -size * 0.04)
        .mask(VStack(spacing: 0) { Color.white; Color.clear }.frame(width: size, height: size))
      Image(systemName: "fish.fill").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(.white.opacity(0.9)).offset(y: size * 0.2)
      Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
    }
    .frame(width: size, height: size)
    .shadow(color: Theme.cyan.opacity(0.4), radius: 8)
  }
}
