import SpriteKit
import SwiftUI

struct RootView: View {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Palette.black.ignoresSafeArea()
      SpriteView(scene: store.scene, preferredFramesPerSecond: 60)
        .ignoresSafeArea()
        .accessibilityLabel("Fab floor. Swipe across flying wafers to slice them.")
      switch store.screen {
      case .title: TitleView(store: store)
      case .leaderboard: LeaderboardView(store: store)
      case .howToPlay: HowToPlayView(store: store)
      case .playing:
        if !store.hud.isOver { HUDView(store: store) }
        if store.hud.isPaused { PauseView(store: store) }
        if store.hud.isOver, let run = store.lastRun { GameOverView(store: store, run: run) }
      }
    }
    .foregroundStyle(Palette.white)
    .statusBarHidden()
    .onAppear { store.reduceEffects = reduceMotion }
    .onChange(of: reduceMotion) { _, value in store.reduceEffects = value }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        store.appDidReturnToForeground()
      } else {
        store.appDidLeaveForeground()
      }
    }
  }
}

// MARK: - Shared chrome

struct Eyebrow: View {
  let text: String
  var color: Color = Palette.green
  var body: some View {
    Text(text.uppercased())
      .font(.label(11))
      .tracking(2.6)
      .foregroundStyle(color)
  }
}

struct NeonButton: View {
  let title: String
  var subtitle: String? = nil
  var primary = true
  var icon: String? = nil
  var compact = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: compact ? 10 : 14) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: compact ? 16 : 20, weight: .bold))
            .frame(width: compact ? 20 : 26)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(title.uppercased())
            .font(.display(compact ? 20 : 26))
            .tracking(compact ? 1 : 1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: compact, vertical: false)
          if let subtitle {
            Text(subtitle)
              .font(.prose(12))
              .opacity(0.8)
              .multilineTextAlignment(.leading)
          }
        }
        .layoutPriority(1)
        Spacer(minLength: 0)
        if !compact {
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .black))
            .opacity(0.7)
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 6)
            .fill(primary ? Palette.green : Palette.panel.opacity(0.92))
          RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
              primary ? Palette.greenBright : Palette.green.opacity(0.6), lineWidth: 1.5)
        }
      )
      .foregroundStyle(primary ? Palette.black : Palette.white)
      .shadow(color: Palette.green.opacity(primary ? 0.5 : 0.15), radius: 14, y: 4)
    }
    .buttonStyle(PressStyle())
  }
}

struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.965 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

struct IconButton: View {
  let system: String
  var active = true
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: system)
        .font(.system(size: 17, weight: .bold))
        .frame(width: 44, height: 44)
        .background(
          RoundedRectangle(cornerRadius: 6).fill(Palette.panel.opacity(0.9))
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Palette.green.opacity(active ? 0.8 : 0.3), lineWidth: 1.2))
        )
        .foregroundStyle(active ? Palette.greenBright : Palette.smoke)
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(label)
  }
}

struct Panel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content
      .padding(22)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 12).fill(Palette.charcoal.opacity(0.96))
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Palette.green.opacity(0.55), lineWidth: 1.5)
          CornerMarks()
        }
      )
      .shadow(color: Palette.green.opacity(0.25), radius: 30)
  }
}

/// Little PCB-style corner brackets that frame every panel.
struct CornerMarks: View {
  var body: some View {
    GeometryReader { geometry in
      let w = geometry.size.width
      let h = geometry.size.height
      let l: CGFloat = 16
      Path { path in
        for (x, y, sx, sy) in [(0, 0, 1, 1), (w, 0, -1, 1), (0, h, 1, -1), (w, h, -1, -1)] {
          path.move(to: CGPoint(x: x + CGFloat(sx) * l, y: y))
          path.addLine(to: CGPoint(x: x, y: y))
          path.addLine(to: CGPoint(x: x, y: y + CGFloat(sy) * l))
        }
      }
      .stroke(Palette.greenBright, lineWidth: 3)
    }
    .padding(-1)
  }
}

struct StatCell: View {
  let label: String
  let value: String
  var color: Color = Palette.white
  var body: some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.mono(22))
        .foregroundStyle(color)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
      Eyebrow(text: label, color: Palette.smoke)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(RoundedRectangle(cornerRadius: 6).fill(Palette.panel))
  }
}

// MARK: - Title

struct TitleView: View {
  @ObservedObject var store: GameStore
  @State private var pulse = false

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 760
      VStack(spacing: 0) {
        HStack {
          Eyebrow(text: "Fab floor · Bay 4090")
          Spacer()
          IconButton(
            system: store.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
            active: store.soundOn, label: "Toggle sound"
          ) {
            store.soundOn.toggle()
            store.click()
          }
          IconButton(
            system: store.hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash",
            active: store.hapticsOn, label: "Toggle haptics"
          ) {
            store.hapticsOn.toggle()
            store.click()
          }
        }
        .padding(.top, 10)

        Spacer(minLength: 8)

        VStack(spacing: 6) {
          Text("WAFER")
            .font(.display(min(96, geometry.size.width * 0.24)))
            .tracking(4)
            .foregroundStyle(Palette.white)
          Text("SLICE")
            .font(.display(min(96, geometry.size.width * 0.24)))
            .tracking(4)
            .foregroundStyle(Palette.greenGlow)
            .shadow(color: Palette.green.opacity(pulse ? 0.95 : 0.5), radius: pulse ? 28 : 14)
            .padding(.top, -28)
          Rectangle()
            .fill(Palette.green)
            .frame(width: 140, height: 4)
            .shadow(color: Palette.green, radius: 8)
          Text("Dice the silicon. Bin the flagship. Never touch the red.")
            .font(.prose(14))
            .foregroundStyle(Palette.steel)
            .padding(.top, 6)
        }
        .padding(.vertical, compact ? 6 : 14)

        Spacer(minLength: 8)

        VStack(spacing: 10) {
          NeonButton(
            title: "Arcade", subtitle: GameMode.arcade.tagline, icon: "bolt.fill"
          ) { store.startRun(.arcade) }
          NeonButton(
            title: "Zen", subtitle: GameMode.zen.tagline, primary: false, icon: "leaf.fill"
          ) { store.startRun(.zen) }
          HStack(spacing: 10) {
            NeonButton(title: "Top bins", primary: false, icon: "list.number", compact: true) {
              store.showLeaderboard()
            }
            NeonButton(title: "How to", primary: false, icon: "questionmark", compact: true) {
              store.showHowToPlay()
            }
          }
        }

        HStack(spacing: 10) {
          StatCell(
            label: "Best arcade", value: "\(store.board.best(.arcade))", color: Palette.greenBright)
          StatCell(
            label: "Best zen", value: "\(store.board.best(.zen))", color: Palette.greenBright)
          StatCell(label: "Dies sliced", value: "\(store.board.lifetimeSliced)")
        }
        .padding(.top, 12)

        Text("Unofficial fan project. Not affiliated with or endorsed by NVIDIA.")
          .font(.prose(10))
          .foregroundStyle(Palette.smoke)
          .padding(.top, 10)
          .padding(.bottom, 4)
      }
      .padding(.horizontal, 20)
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .background(
      LinearGradient(
        colors: [Palette.black.opacity(0.35), Palette.black.opacity(0.75)], startPoint: .top,
        endPoint: .bottom
      ).ignoresSafeArea()
    )
    .onAppear {
      withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
    }
  }
}

// MARK: - HUD

struct HUDView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Eyebrow(text: "Yield")
          Text("\(store.hud.score)")
            .font(.mono(38))
            .foregroundStyle(store.hud.multiplier > 1 ? Palette.gold : Palette.white)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.2), value: store.hud.score)
            .shadow(color: Palette.green.opacity(0.6), radius: 10)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          if store.hud.mode == .arcade {
            Text(store.hud.timeText)
              .font(.mono(30))
              .foregroundStyle(store.hud.isCountdown ? Palette.red : Palette.greenBright)
              .monospacedDigit()
            HStack(spacing: 5) {
              ForEach(0..<max(store.hud.maxLives, 1), id: \.self) { index in
                LifeChip(alive: index < store.hud.lives)
              }
            }
          } else {
            Eyebrow(text: "Zen · no clock")
            Text("∞").font(.mono(30)).foregroundStyle(Palette.greenBright)
          }
        }
        IconButton(system: "pause.fill", label: "Pause") { store.pause() }
      }
      .padding(.horizontal, 18)
      .padding(.top, 6)

      if store.hud.slowMoFraction > 0 {
        SlowMoBanner(fraction: store.hud.slowMoFraction)
          .padding(.top, 10)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
      Spacer()
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.hud.slowMoFraction > 0)
    .allowsHitTesting(!store.hud.isOver)
  }
}

struct LifeChip: View {
  let alive: Bool
  var body: some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(alive ? Palette.green : Palette.panel)
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .strokeBorder(alive ? Palette.greenBright : Palette.smoke.opacity(0.5), lineWidth: 1.2)
      )
      .overlay(
        Group {
          if alive {
            Rectangle().fill(Palette.black.opacity(0.35)).frame(width: 8, height: 8)
          }
        }
      )
      .frame(width: 20, height: 20)
      .shadow(color: alive ? Palette.green.opacity(0.7) : .clear, radius: 5)
      .animation(.spring(), value: alive)
  }
}

struct SlowMoBanner: View {
  let fraction: Double
  var body: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        Image(systemName: "sparkles").foregroundStyle(Palette.gold)
        Text("FLAGSHIP DIE · DLSS 2× YIELD")
          .font(.label(13))
          .tracking(1.8)
          .foregroundStyle(Palette.gold)
        Image(systemName: "sparkles").foregroundStyle(Palette.gold)
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(Palette.panel)
          Capsule()
            .fill(
              LinearGradient(
                colors: [Palette.gold, Palette.greenBright], startPoint: .leading,
                endPoint: .trailing)
            )
            .frame(width: geometry.size.width * fraction)
            .shadow(color: Palette.gold, radius: 6)
        }
      }
      .frame(height: 6)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.charcoal.opacity(0.9)))
    .overlay(
      RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1.2)
    )
    .padding(.horizontal, 40)
  }
}

// MARK: - Pause

struct PauseView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    ZStack {
      Palette.black.opacity(0.72).ignoresSafeArea()
      Panel {
        VStack(spacing: 14) {
          Eyebrow(text: "Fab line halted")
          Text("PAUSED")
            .font(.display(48))
            .tracking(3)
          Text("Yield \(store.hud.score) · \(store.hud.mode.title) mode")
            .font(.prose(14))
            .foregroundStyle(Palette.steel)
          NeonButton(title: "Resume", icon: "play.fill") { store.resume() }
          if store.hud.mode == .zen {
            NeonButton(
              title: "Bank run", subtitle: "Finish now and record the score", primary: false,
              icon: "tray.and.arrow.down.fill"
            ) {
              store.click()
              store.finishEarly()
            }
          }
          NeonButton(title: "Restart", primary: false, icon: "arrow.counterclockwise") {
            store.startRun(store.hud.mode)
          }
          NeonButton(title: "Quit to title", primary: false, icon: "xmark") { store.quitToTitle() }
          HStack(spacing: 10) {
            IconButton(
              system: store.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
              active: store.soundOn, label: "Toggle sound"
            ) { store.soundOn.toggle() }
            IconButton(
              system: store.hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash",
              active: store.hapticsOn, label: "Toggle haptics"
            ) { store.hapticsOn.toggle() }
          }
        }
      }
      .padding(.horizontal, 24)
    }
  }
}

// MARK: - Game over

struct GameOverView: View {
  @ObservedObject var store: GameStore
  let run: RunSummary
  @State private var revealed = false

  private var headline: String {
    switch run.endReason {
    case .outOfLives: return "FAB SHUTDOWN"
    case .timeUp: return "TAPE-OUT"
    case .finished: return "RUN BANKED"
    }
  }

  private var quip: String {
    if run.endReason == .outOfLives { return "Three defective dies. QA would like a word." }
    if run.score >= 2000 { return "It just works. Suspiciously well." }
    if run.score >= 1000 { return "The more you slice, the more you save." }
    if run.flagshipHits == 0 { return "Not a single flagship binned. Moore's Law weeps." }
    if run.bestSwipe >= 5 { return "That swipe had more cores than a datacenter." }
    return "Respectable yield. Ship it to the partners."
  }

  var body: some View {
    ZStack {
      Palette.black.opacity(0.78).ignoresSafeArea()
      ScrollView {
        Panel {
          VStack(spacing: 14) {
            Eyebrow(text: "\(run.mode.title) · production report")
            Text(headline)
              .font(.display(46))
              .tracking(3)
              .foregroundStyle(run.endReason == .outOfLives ? Palette.red : Palette.white)
            Text("\(run.score)")
              .font(.mono(64))
              .foregroundStyle(Palette.greenGlow)
              .shadow(color: Palette.green.opacity(0.8), radius: 20)
              .scaleEffect(revealed ? 1 : 0.6)
              .opacity(revealed ? 1 : 0)
            Text(run.bin.uppercased())
              .font(.label(14))
              .tracking(3)
              .foregroundStyle(Palette.gold)
            if let rank = store.lastRank {
              Text(rank == 1 ? "NEW FAB RECORD" : "TOP BIN #\(rank)")
                .font(.label(12))
                .tracking(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(rank == 1 ? Palette.green : Palette.panel))
                .foregroundStyle(rank == 1 ? Palette.black : Palette.greenBright)
            }
            Text(quip)
              .font(.prose(13))
              .foregroundStyle(Palette.steel)
              .multilineTextAlignment(.center)
            HStack(spacing: 8) {
              StatCell(label: "Sliced", value: "\(run.sliced - run.defectiveHits)")
              StatCell(label: "Yield", value: "\(run.yieldPercent)%")
              StatCell(label: "Best swipe", value: "×\(run.bestSwipe)")
            }
            HStack(spacing: 8) {
              StatCell(label: "Flagships", value: "\(run.flagshipHits)", color: Palette.gold)
              StatCell(label: "Bonuses", value: "\(run.binningBonuses)")
              StatCell(
                label: "Defects", value: "\(run.defectiveHits)",
                color: run.defectiveHits > 0 ? Palette.red : Palette.white)
            }
            NeonButton(title: "Run it back", icon: "arrow.counterclockwise") {
              store.startRun(run.mode)
            }
            HStack(spacing: 10) {
              NeonButton(title: "Scores", primary: false, icon: "list.number", compact: true) {
                store.showLeaderboard()
              }
              NeonButton(title: "Title", primary: false, icon: "house.fill", compact: true) {
                store.quitToTitle()
              }
            }
          }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 40)
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.15)) { revealed = true }
    }
  }
}

// MARK: - Leaderboard

struct LeaderboardView: View {
  @ObservedObject var store: GameStore
  @State private var mode: GameMode = .arcade

  var body: some View {
    ZStack {
      Palette.black.opacity(0.8).ignoresSafeArea()
      VStack(spacing: 14) {
        HStack {
          IconButton(system: "chevron.left", label: "Back") {
            if store.lastRun != nil { store.screen = .playing } else { store.quitToTitle() }
            store.click()
          }
          Spacer()
          Eyebrow(text: "Local leaderboard")
          Spacer()
          Color.clear.frame(width: 44, height: 44)
        }
        Text("TOP BINS")
          .font(.display(44))
          .tracking(3)
        Picker("Mode", selection: $mode) {
          ForEach(GameMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in store.click() }
        Panel {
          let entries = store.board.top(mode)
          if entries.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "cpu").font(.system(size: 34)).foregroundStyle(Palette.green)
              Text("No runs binned yet.").font(.prose(15))
              Text("Finish a \(mode.title) run to post the first score.")
                .font(.prose(12)).foregroundStyle(Palette.smoke)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
          } else {
            VStack(spacing: 0) {
              ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 12) {
                  Text(String(format: "%02d", index + 1))
                    .font(.mono(16))
                    .foregroundStyle(index == 0 ? Palette.gold : Palette.green)
                    .frame(width: 30)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(entry.bin).font(.label(14))
                    Text(
                      "\(entry.sliced) sliced · best swipe ×\(entry.bestSwipe) · \(entry.date.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.prose(11)).foregroundStyle(Palette.smoke)
                  }
                  Spacer()
                  Text("\(entry.score)")
                    .font(.mono(20))
                    .foregroundStyle(Palette.white)
                }
                .padding(.vertical, 9)
                if index < entries.count - 1 { Divider().overlay(Palette.green.opacity(0.25)) }
              }
            }
          }
        }
        HStack(spacing: 8) {
          StatCell(label: "Runs", value: "\(store.board.lifetimeRuns)")
          StatCell(label: "Lifetime sliced", value: "\(store.board.lifetimeSliced)")
          StatCell(
            label: "Flagships", value: "\(store.board.lifetimeFlagships)", color: Palette.gold)
        }
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
  }
}

// MARK: - How to play

struct HowToPlayView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    ZStack {
      Palette.black.opacity(0.8).ignoresSafeArea()
      VStack(spacing: 14) {
        HStack {
          IconButton(system: "chevron.left", label: "Back") { store.quitToTitle() }
          Spacer()
          Eyebrow(text: "Cleanroom briefing")
          Spacer()
          Color.clear.frame(width: 44, height: 44)
        }
        Text("HOW TO SLICE")
          .font(.display(40))
          .tracking(3)
        ScrollView {
          VStack(spacing: 10) {
            rule(
              kind: .wafer, title: "Wafers · +10",
              text: "300mm silicon. Swipe across the dashed die-cut lines to dice them.")
            rule(
              kind: .chiplet, title: "Chiplets · +15",
              text: "Small packaged dies on a gold-pad interposer. Quick to bin.")
            rule(
              kind: .heatsink, title: "Heatsinks · +20",
              text: "Finned vapor chambers. Delid them for the biggest base yield.")
            rule(
              kind: .defective, title: "Defective dies · −1 life",
              text:
                "Red, cracked, failed QA. Slicing one in Arcade costs a life. Three and the fab shuts down.",
              color: Palette.red)
            rule(
              kind: .flagship, title: "Flagship die · +100",
              text:
                "The golden one. Slicing it starts a 3-second slow-mo window with 2× yield on everything, and refunds a lost life.",
              color: Palette.gold)
            Panel {
              VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Binning bonus")
                Text(
                  "Slice three or more clean parts in one swipe and lift your finger to bank +20 per part (doubled during slow-mo). Defective dies never count."
                )
                .font(.prose(13)).foregroundStyle(Palette.steel)
                Eyebrow(text: "Modes")
                Text(
                  "Arcade is a 60-second production run with three lives. Zen has no clock and no defects; bank your run from the pause menu whenever you like."
                )
                .font(.prose(13)).foregroundStyle(Palette.steel)
              }
            }
          }
          .padding(.bottom, 20)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
  }

  private func rule(
    kind: SliceableKind, title: String, text: String, color: Color = Palette.greenBright
  )
    -> some View
  {
    HStack(spacing: 14) {
      Image(uiImage: ProceduralArt.image(for: kind))
        .resizable()
        .scaledToFit()
        .frame(width: 58, height: 58)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.label(14)).foregroundStyle(color)
        Text(text).font(.prose(12)).foregroundStyle(Palette.steel)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 8).fill(Palette.charcoal.opacity(0.95)))
    .overlay(
      RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.green.opacity(0.35), lineWidth: 1))
  }
}
