import SwiftUI

struct GameView: View {
  @EnvironmentObject var store: GameStore
  var namespace: Namespace.ID
  @State private var shake: CGFloat = 0
  @State private var startDate = Date()

  var body: some View {
    GeometryReader { geo in
      VStack(spacing: 14) {
        header
        timerBar
        Spacer(minLength: 0)
        boardView(available: CGSize(width: geo.size.width - 28, height: geo.size.height * 0.62))
          .offset(x: shake)
        Spacer(minLength: 0)
        footer
      }
      .padding(.horizontal, 14)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .overlay {
      if store.isPaused { PauseOverlay() }
      if store.board.phase == .solved { WinOverlay(namespace: namespace) }
      if case .failed(let reason) = store.board.phase { FailOverlay(reason: reason) }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.board.phase)
    .animation(.easeInOut(duration: 0.2), value: store.isPaused)
    .onChange(of: store.lastMelted) { _, melted in
      guard !melted.isEmpty else { return }
      withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shake = 9 }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shake = 0 }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      Button {
        store.showLevels()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(Palette.green)
          .frame(width: 44, height: 44)
          .background(Circle().fill(Palette.charcoal.opacity(0.9)))
          .overlay(Circle().strokeBorder(Palette.green.opacity(0.4), lineWidth: 1))
      }
      .accessibilityLabel("Back to levels")
      VStack(alignment: .leading, spacing: 2) {
        Text("LEVEL \(String(format: "%02d", store.board.level.id)) / \(LevelCatalog.count)")
          .font(.mono(11))
          .foregroundStyle(Palette.green)
          .tracking(2)
        Text(store.board.level.name)
          .font(.display(22))
          .foregroundStyle(Palette.paper)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      Spacer()
      Button {
        store.togglePause()
      } label: {
        Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(Palette.green)
          .frame(width: 44, height: 44)
          .background(Circle().fill(Palette.charcoal.opacity(0.9)))
          .overlay(Circle().strokeBorder(Palette.green.opacity(0.4), lineWidth: 1))
      }
      .accessibilityLabel(store.isPaused ? "Resume" : "Pause")
      .opacity(store.board.phase == .routing ? 1 : 0.35)
    }
  }

  private var timerBar: some View {
    let fraction = store.board.timeFraction
    let color: Color =
      fraction > 0.4 ? Palette.green : fraction > 0.18 ? Palette.amber : Palette.red
    return VStack(spacing: 6) {
      HStack {
        Label {
          Text(store.board.phase == .ready ? "TAP A CABLE TO START" : "POWER-ON TIMER")
            .font(.mono(11)).tracking(1.5)
        } icon: {
          Image(systemName: "bolt.fill").font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        Spacer()
        Text(timeString(store.board.timeRemaining))
          .font(.mono(20, weight: .bold))
          .foregroundStyle(color)
          .contentTransition(.numericText())
          .monospacedDigit()
      }
      GeometryReader { g in
        ZStack(alignment: .leading) {
          Capsule().fill(Palette.slate)
          Capsule()
            .fill(
              LinearGradient(
                colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: max(6, g.size.width * fraction))
            .shadow(color: color.opacity(0.7), radius: 6)
        }
      }
      .frame(height: 8)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.charcoal.opacity(0.8))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
            Palette.steel.opacity(0.5), lineWidth: 1))
    )
  }

  private func timeString(_ t: Double) -> String {
    let whole = Int(t)
    let tenths = Int((t - Double(whole)) * 10)
    return String(format: "%02d:%02d.%d", whole / 60, whole % 60, tenths)
  }

  private func boardView(available: CGSize) -> some View {
    let board = store.board
    let gap: CGFloat = 5
    let cell = floor(
      min(
        (available.width - gap * CGFloat(board.width - 1)) / CGFloat(board.width),
        (available.height - gap * CGFloat(board.height - 1)) / CGFloat(board.height)))
    return TimelineView(.animation(minimumInterval: 1 / 60, paused: store.isPaused)) { timeline in
      let phase = timeline.date.timeIntervalSince(startDate)
      VStack(spacing: gap) {
        ForEach(0..<board.height, id: \.self) { y in
          HStack(spacing: gap) {
            ForEach(0..<board.width, id: \.self) { x in
              let p = GridPoint(x, y)
              TileView(
                tile: board[p], powered: store.flow.powered[p] ?? [],
                isShort: store.flow.shorts.contains(p),
                solved: board.phase == .solved, phase: phase, size: cell
              )
              .onTapGesture { store.tap(p) }
              .accessibilityAddTraits(board[p].isRotatable ? .isButton : [])
            }
          }
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Palette.ink.opacity(0.75))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Palette.green.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: Palette.green.opacity(0.15), radius: 30)
    )
  }

  private var footer: some View {
    let board = store.board
    let hottest = board.tiles.filter { $0.kind != .slag }.map(\.heat).max() ?? 0
    return HStack(spacing: 10) {
      chip(
        icon: "hand.tap.fill", label: "TAPS", value: "\(board.moves)",
        detail: "PAR \(board.level.par)", tint: Palette.green)
      chip(
        icon: "cable.connector", label: "LANES",
        value: "\(store.flow.sinksPowered.count)/\(board.level.nets.count)",
        detail: store.flow.shorts.isEmpty ? "NOMINAL" : "SHORT!",
        tint: store.flow.shorts.isEmpty ? Palette.green : Palette.red)
      if board.level.hasHeat {
        chip(
          icon: "thermometer.high", label: "JUNCTION",
          value: hottest > 0.02 ? "\(Int(45 + hottest * 60))°C" : "45°C",
          detail: hottest > 0.7 ? "MELTING" : hottest > 0.02 ? "THROTTLE" : "COOL",
          tint: hottest > 0.7 ? Palette.red : hottest > 0.02 ? Palette.ember : Palette.green)
      }
    }
  }

  private func chip(icon: String, label: String, value: String, detail: String, tint: Color)
    -> some View
  {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
      VStack(alignment: .leading, spacing: 1) {
        Text(label).font(.mono(9)).tracking(1.2).foregroundStyle(Palette.mist)
        Text(value).font(.mono(16, weight: .bold)).foregroundStyle(Palette.paper).contentTransition(
          .numericText())
        Text(detail).font(.mono(9)).foregroundStyle(tint)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.charcoal.opacity(0.85))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(
            tint.opacity(0.35), lineWidth: 1))
    )
  }
}

struct PauseOverlay: View {
  @EnvironmentObject var store: GameStore
  var body: some View {
    ZStack {
      Palette.ink.opacity(0.82).ignoresSafeArea()
      Panel {
        VStack(spacing: 18) {
          Text("PAUSED").font(.display(30)).foregroundStyle(Palette.green).tracking(4)
          Text("Clocks halted. Fans idle. Heat is frozen while you think.")
            .font(.label(14)).foregroundStyle(Palette.mist).multilineTextAlignment(.center)
          Button("Resume") { store.togglePause() }.buttonStyle(NeonButtonStyle())
          Button("Restart level") { store.restart() }.buttonStyle(NeonButtonStyle(filled: false))
          Button("Level select") { store.showLevels() }.buttonStyle(
            NeonButtonStyle(tint: Palette.mist, filled: false))
        }
        .padding(26)
      }
      .padding(30)
    }
    .transition(.opacity)
  }
}

struct WinOverlay: View {
  @EnvironmentObject var store: GameStore
  var namespace: Namespace.ID
  @State private var revealed = 0
  @State private var appeared = false

  var body: some View {
    let board = store.board
    ZStack {
      Palette.ink.opacity(0.78).ignoresSafeArea()
      ForEach(0..<14, id: \.self) { i in
        Confetti(index: i, go: appeared)
      }
      Panel {
        VStack(spacing: 16) {
          Text("GPU ONLINE")
            .font(.display(34)).foregroundStyle(Palette.green).tracking(3)
            .shadow(color: Palette.green.opacity(0.8), radius: 14)
          Text(
            board.level.nets.count > 1
              ? "Both lanes seated. Fans spinning up." : "Cable seated. Fans spinning up."
          )
          .font(.label(14)).foregroundStyle(Palette.mist)
          HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { i in
              Image(systemName: i < board.stars ? "star.fill" : "star")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(i < board.stars ? Palette.green : Palette.steel)
                .shadow(color: i < board.stars ? Palette.green.opacity(0.9) : .clear, radius: 12)
                .scaleEffect(i < revealed ? 1 : 0.2)
                .opacity(i < revealed ? 1 : 0.15)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: revealed)
            }
          }
          .padding(.vertical, 6)
          VStack(spacing: 6) {
            statRow(
              "Boot time", value: String(format: "%.1fs", board.elapsed),
              ok: board.timeFraction >= 0.4, hint: "≥40% timer left")
            statRow(
              "Taps", value: "\(board.moves) / par \(board.level.par)",
              ok: board.moves <= board.level.par + max(2, board.level.par / 4),
              hint: "within par + \(max(2, board.level.par / 4))")
          }
          .padding(.horizontal, 4)
          if let result = store.progress.results[board.level.id] {
            Text("BEST  \(String(format: "%.1fs", result.bestTime))  ·  \(result.bestMoves) TAPS")
              .font(.mono(11)).tracking(1.4).foregroundStyle(Palette.green.opacity(0.85))
          }
          Button(board.level.id == LevelCatalog.count ? "Back to levels" : "Next level") {
            store.nextLevel()
          }
          .buttonStyle(NeonButtonStyle())
          HStack(spacing: 12) {
            Button("Replay") { store.restart() }.buttonStyle(NeonButtonStyle(filled: false))
            Button("Levels") { store.showLevels() }.buttonStyle(
              NeonButtonStyle(tint: Palette.mist, filled: false))
          }
        }
        .padding(24)
      }
      .padding(24)
      .scaleEffect(appeared ? 1 : 0.85)
      .opacity(appeared ? 1 : 0)
    }
    .onAppear {
      withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.25)) { appeared = true }
      for i in 1...3 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i) * 0.22) {
          if i <= board.stars {
            revealed = i
            store.synth.play(.connect(pitch: Double(i * 4)))
            Haptics.connect()
          }
        }
      }
    }
  }

  private func statRow(_ title: String, value: String, ok: Bool, hint: String) -> some View {
    HStack {
      Image(systemName: ok ? "checkmark.circle.fill" : "circle")
        .foregroundStyle(ok ? Palette.green : Palette.steel)
      Text(title).font(.label(13)).foregroundStyle(Palette.paper)
      Spacer()
      VStack(alignment: .trailing, spacing: 0) {
        Text(value).font(.mono(13, weight: .bold)).foregroundStyle(Palette.paper)
        Text(hint).font(.mono(9)).foregroundStyle(Palette.mist)
      }
    }
  }
}

struct Confetti: View {
  let index: Int
  let go: Bool
  var body: some View {
    let seed = Double(index)
    let x = (sin(seed * 12.9898) * 0.5 + 0.5) * 320 - 160
    let delay = (cos(seed * 7.7) * 0.5 + 0.5) * 0.4
    let color = index % 3 == 0 ? Palette.amber : Palette.green
    RoundedRectangle(cornerRadius: 2)
      .fill(color)
      .frame(width: 8, height: index % 2 == 0 ? 16 : 8)
      .rotationEffect(.degrees(go ? seed * 97 : 0))
      .offset(x: x, y: go ? 420 : -420)
      .opacity(go ? 0 : 1)
      .animation(.easeIn(duration: 1.6).delay(delay), value: go)
      .allowsHitTesting(false)
  }
}

struct FailOverlay: View {
  @EnvironmentObject var store: GameStore
  let reason: FailReason
  @State private var appeared = false
  var body: some View {
    ZStack {
      Palette.ink.opacity(0.82).ignoresSafeArea()
      Panel(tint: Palette.red) {
        VStack(spacing: 16) {
          Image(systemName: reason == .timeout ? "clock.badge.exclamationmark" : "flame.fill")
            .font(.system(size: 44, weight: .bold))
            .foregroundStyle(Palette.red)
            .shadow(color: Palette.red.opacity(0.8), radius: 14)
          Text(reason.title).font(.display(28)).foregroundStyle(Palette.red).tracking(2)
          Text(reason.message).font(.label(14)).foregroundStyle(Palette.mist)
            .multilineTextAlignment(.center)
          Text(
            reason == .timeout
              ? "Tip: decoy cables carry nothing. Trace from the PSU outward."
              : "Tip: a glowing cable next to a hot chip is about to melt. Rotate it out of the lane."
          )
          .font(.mono(11)).foregroundStyle(Palette.amber).multilineTextAlignment(.center)
          Button("Retry") { store.restart() }.buttonStyle(NeonButtonStyle(tint: Palette.red))
          Button("Level select") { store.showLevels() }.buttonStyle(
            NeonButtonStyle(tint: Palette.mist, filled: false))
        }
        .padding(24)
      }
      .padding(28)
      .scaleEffect(appeared ? 1 : 0.9)
      .opacity(appeared ? 1 : 0)
    }
    .onAppear {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.2)) { appeared = true }
    }
  }
}
