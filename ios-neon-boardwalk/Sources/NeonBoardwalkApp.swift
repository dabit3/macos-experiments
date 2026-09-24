import SceneKit
import SwiftUI

@main
struct NeonBoardwalkApp: App {
  var body: some Scene {
    WindowGroup { BoardwalkView() }
  }
}

private enum Palette {
  static let mint = Color(red: 0.36, green: 1, blue: 0.86)
  static let pink = Color(red: 1, green: 0.35, blue: 0.63)
  static let amber = Color(red: 1, green: 0.72, blue: 0.3)
  static let navy = Color(red: 0.035, green: 0.055, blue: 0.12)
  static let ink = Color(red: 0.07, green: 0.09, blue: 0.17)
  static let muted = Color(red: 0.68, green: 0.75, blue: 0.82)
  static let gold = Color(red: 1, green: 0.84, blue: 0.36)
}

private struct PressableStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .brightness(configuration.isPressed ? 0.12 : 0)
      .animation(.spring(duration: 0.18), value: configuration.isPressed)
  }
}

private struct NeonText: View {
  let text: String
  let size: CGFloat
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: size, weight: .black, design: .rounded))
      .italic()
      .tracking(size > 45 ? -2.5 : -1.2)
      .foregroundStyle(color)
      .shadow(color: color.opacity(0.6), radius: size * 0.14)
      .shadow(color: color.opacity(0.25), radius: size * 0.4)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
  }
}

private struct Glass: View {
  var radius: CGFloat
  var opacity = 0.72

  var body: some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
      .fill(.ultraThinMaterial)
      .environment(\.colorScheme, .dark)
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .fill(Palette.navy.opacity(opacity))
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.26), .white.opacity(0.04)],
              startPoint: .top, endPoint: .bottom))
      )
  }
}

/// Thin progress rail comparing the current distance with the stored best.
private struct BestRail: View {
  let progress: Double
  let tint: Color

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.12))
        Capsule()
          .fill(
            LinearGradient(
              colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: max(4, proxy.size.width * min(1, max(0, progress))))
          .shadow(color: tint.opacity(0.7), radius: 4)
      }
    }
    .frame(height: 4)
  }
}

struct BoardwalkView: View {
  @StateObject private var game = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reducedMotion

  var body: some View {
    ZStack {
      NativeTrack(game: game)
        .ignoresSafeArea()
      scrim
      switch game.engine.phase {
      case .ready: title
      case .running: gameplay
      case .paused:
        gameplay.allowsHitTesting(false)
        if game.countdown > 0 { countdown } else { pausePanel }
      case .finished: resultPanel
      }
      if game.showGuide { guide.transition(.opacity) }
    }
    .foregroundStyle(.white)
    .preferredColorScheme(.dark)
    .animation(reducedMotion ? nil : .spring(duration: 0.35), value: game.banner)
    .animation(.easeOut(duration: 0.2), value: game.showGuide)
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { game.pause() }
    }
    .onChange(of: reducedMotion) { _, value in game.reducedMotion = value }
    .onAppear { game.reducedMotion = reducedMotion }
  }

  private var scrim: some View {
    let ready = game.engine.phase == .ready
    return LinearGradient(
      stops: [
        .init(color: Palette.navy.opacity(ready ? 0.7 : 0.75), location: 0),
        .init(color: .clear, location: ready ? 0.3 : 0.2),
        .init(color: .clear, location: ready ? 0.55 : 0.72),
        .init(color: Palette.navy.opacity(0.95), location: 1),
      ], startPoint: .top, endPoint: .bottom
    )
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  // MARK: Title

  private var title: some View {
    VStack(spacing: 0) {
      HStack {
        runBadge
        Spacer()
        soundButton
      }
      .padding(.top, 6)
      titleLockup
        .padding(.top, 10)
      Spacer(minLength: 16)
      titleDock
        .padding(.bottom, 6)
    }
    .padding(.horizontal, 20)
  }

  private var runBadge: some View {
    HStack(spacing: 7) {
      Image(systemName: "sun.horizon.fill").foregroundStyle(Palette.pink)
      Text(game.record.runs == 0 ? "FIRST SUNSET" : "RUN \(game.record.runs + 1)")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(1.8)
    }
    .font(.system(size: 13, weight: .semibold))
    .padding(.horizontal, 12)
    .frame(height: 32)
    .background(Glass(radius: 16, opacity: 0.5))
  }

  private var titleLockup: some View {
    VStack(spacing: 0) {
      NeonText(text: "NEON", size: 56, color: .white)
      NeonText(text: "BOARDWALK", size: 34, color: Palette.mint)
        .padding(.top, -8)
      HStack(spacing: 10) {
        Capsule().fill(Palette.pink).frame(width: 18, height: 2)
        Text("SKATE THE COAST AFTER DARK")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .tracking(2.2)
          .foregroundStyle(.white.opacity(0.85))
        Capsule().fill(Palette.pink).frame(width: 18, height: 2)
      }
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var titleDock: some View {
    VStack(spacing: 14) {
      HStack(spacing: 0) {
        dockStat(
          "BEST",
          value: game.record.bestDistance == 0 ? "—" : "\(game.record.bestDistance.formatted()) m",
          icon: "laurel.leading", color: Palette.mint)
        dockDivider
        dockStat(
          "COINS", value: game.record.totalCoins.formatted(), icon: "circle.inset.filled",
          color: Palette.gold)
        dockDivider
        dockStat(
          "RUNS", value: game.record.runs.formatted(), icon: "flag.checkered", color: Palette.pink)
      }
      .accessibilityElement(children: .combine)
      primary(
        game.record.runs == 0 ? "START FIRST RIDE" : "LET’S RIDE", icon: "play.fill",
        action: game.start
      )
      .accessibilityIdentifier("startRun")
      HStack(spacing: 10) {
        gestureHint
        Spacer(minLength: 8)
        Button {
          game.showGuide = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "questionmark.circle").font(.system(size: 13, weight: .semibold))
            Text("How to ride").font(.system(size: 13, weight: .semibold))
          }
          .padding(.horizontal, 14)
          .frame(height: 44)
          .background(.white.opacity(0.07), in: Capsule())
          .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("howToRide")
      }
    }
    .padding(16)
    .background(Glass(radius: 28))
  }

  private var gestureHint: some View {
    HStack(spacing: 5) {
      ForEach(["arrow.left", "arrow.right", "arrow.up", "arrow.down"], id: \.self) { symbol in
        Image(systemName: symbol)
          .font(.system(size: 10, weight: .bold))
          .frame(width: 22, height: 22)
          .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
      }
      Text("Swipe")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.muted)
        .padding(.leading, 3)
    }
    .foregroundStyle(Palette.muted)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Swipe left or right to change lanes, up to jump, down to slide")
  }

  private func dockStat(_ label: String, value: String, icon: String, color: Color) -> some View {
    VStack(spacing: 5) {
      HStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
        eyebrow(label)
      }
      Text(value)
        .font(.system(size: 19, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity)
  }

  private var dockDivider: some View {
    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 32)
  }

  // MARK: Gameplay

  private var gameplay: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 10) {
        distanceCard
        Spacer(minLength: 0)
        coinPill
        pauseButton
      }
      .padding(.top, 6)
      if game.engine.isShielded { shieldGauge.padding(.top, 10) }
      if let banner = game.banner {
        bannerView(banner)
          .padding(.top, 16)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
      Spacer()
      if game.engine.distance < 122 || game.shieldBreakTime > 0 {
        coachingChip.padding(.bottom, 14)
      }
      if game.showControls {
        controls.padding(.bottom, 4)
      }
    }
    .padding(.horizontal, 18)
  }

  private var bestProgress: (progress: Double, label: String, tint: Color) {
    let best = game.record.bestDistance
    let distance = Int(game.engine.distance)
    if best == 0 {
      return (min(1, game.engine.distance / 500), "FIRST RUN · SET A MARK", Palette.mint)
    }
    if distance > best { return (1, "NEW BEST +\((distance - best).formatted()) m", Palette.mint) }
    return (
      game.engine.distance / Double(best), "\((best - distance).formatted()) m TO BEST",
      Palette.pink
    )
  }

  private var distanceCard: some View {
    let best = bestProgress
    return VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text("\(Int(game.engine.distance).formatted())")
          .font(.system(size: 34, weight: .heavy, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .fixedSize()
        Text("m").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted)
      }
      BestRail(progress: best.progress, tint: best.tint)
      Text(best.label)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(1.2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(best.tint == Palette.mint ? Palette.mint : Palette.muted)
    }
    .frame(width: 164, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Glass(radius: 20, opacity: 0.55))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Distance \(Int(game.engine.distance)) metres. Best \(game.record.bestDistance) metres"
    )
    .accessibilityIdentifier("distance")
  }

  private var coinPill: some View {
    HStack(spacing: 6) {
      Image(systemName: "circle.inset.filled").foregroundStyle(Palette.gold)
        .shadow(color: Palette.gold.opacity(0.6), radius: 4)
      Text("\(game.engine.coins)").font(.system(size: 18, weight: .bold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
    }
    .padding(.horizontal, 13)
    .frame(height: 44)
    .background(Glass(radius: 22, opacity: 0.55))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(game.engine.coins) coins")
  }

  private var pauseButton: some View {
    Button(action: game.pause) {
      Image(systemName: "pause.fill")
        .font(.system(size: 15, weight: .bold))
        .frame(width: 44, height: 44)
        .background(Glass(radius: 22, opacity: 0.55))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel("Pause")
    .accessibilityIdentifier("pauseRun")
  }

  private var shieldGauge: some View {
    HStack(spacing: 9) {
      ZStack {
        Circle().stroke(Palette.mint.opacity(0.2), lineWidth: 3)
        Circle()
          .trim(from: 0, to: game.engine.shieldTime / 10)
          .stroke(Palette.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: "shield.fill").font(.system(size: 10, weight: .bold))
      }
      .frame(width: 24, height: 24)
      Text("SHIELD \(Int(ceil(game.engine.shieldTime)))s")
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .tracking(1)
    }
    .foregroundStyle(Palette.mint)
    .padding(.leading, 7)
    .padding(.trailing, 13)
    .frame(height: 36)
    .background(Glass(radius: 18, opacity: 0.55))
    .shadow(color: Palette.mint.opacity(0.35), radius: 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("shieldStatus")
  }

  private func bannerView(_ banner: Banner) -> some View {
    let tint = banner.isRecord ? Palette.mint : Palette.pink
    return VStack(spacing: 4) {
      Text(banner.title)
        .font(.system(size: 20, weight: .black, design: .rounded))
        .italic()
        .foregroundStyle(tint)
        .shadow(color: tint.opacity(0.7), radius: 8)
      Text(banner.detail)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.85))
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 12)
    .background(Glass(radius: 22, opacity: 0.6))
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("milestoneBanner")
  }

  private var coaching: (icon: String, text: String, tint: Color) {
    if game.shieldBreakTime > 0 {
      return ("shield.lefthalf.filled", "Shield saved you. Keep riding!", Palette.mint)
    }
    if game.engine.isShielded {
      return ("shield.fill", "Shield up: one hit is on us.", Palette.mint)
    }
    if game.engine.distance < 46 {
      return ("arrow.up", "Amber barrier ahead: swipe up to jump", Palette.amber)
    }
    if game.engine.distance < 83 {
      return ("arrow.down", "Pink sign ahead: swipe down to slide", Palette.pink)
    }
    return ("circle.circle", "Grab the turquoise ring for a shield", Palette.mint)
  }

  private var coachingChip: some View {
    let tip = coaching
    return HStack(spacing: 10) {
      Image(systemName: tip.icon)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Palette.navy)
        .frame(width: 28, height: 28)
        .background(tip.tint, in: Circle())
      Text(tip.text).font(.system(size: 13, weight: .semibold))
    }
    .padding(.leading, 6)
    .padding(.trailing, 16)
    .frame(height: 40)
    .background(Glass(radius: 20, opacity: 0.7))
    .allowsHitTesting(false)
  }

  private var controls: some View {
    HStack(spacing: 0) {
      control(.left, symbol: "arrow.left", label: "LEFT")
      controlDivider
      control(.jump, symbol: "arrow.up", label: "JUMP")
      controlDivider
      control(.slide, symbol: "arrow.down", label: "SLIDE")
      controlDivider
      control(.right, symbol: "arrow.right", label: "RIGHT")
    }
    .frame(height: 64)
    .background(Glass(radius: 24, opacity: 0.6))
  }

  private var controlDivider: some View {
    Rectangle().fill(.white.opacity(0.09)).frame(width: 1, height: 30)
  }

  private func control(_ move: Move, symbol: String, label: String) -> some View {
    let action = move == .jump || move == .slide
    return Button {
      game.move(move)
    } label: {
      VStack(spacing: 4) {
        Image(systemName: symbol).font(.system(size: 20, weight: .bold))
          .foregroundStyle(action ? Palette.mint : .white)
        Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.4)
          .foregroundStyle(Palette.muted)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(move.rawValue.capitalized)
    .accessibilityIdentifier(move.rawValue)
  }

  private var countdown: some View {
    let step = GameStore.countdownLength / 3
    let value = Int(ceil(game.countdown / step))
    return ZStack {
      Palette.navy.opacity(0.35).ignoresSafeArea()
      VStack(spacing: 6) {
        Text("\(value)")
          .font(.system(size: 110, weight: .black, design: .rounded))
          .italic()
          .foregroundStyle(Palette.mint)
          .shadow(color: Palette.mint.opacity(0.7), radius: 22)
          .contentTransition(.numericText(countsDown: true))
        eyebrow("GET READY", color: .white)
      }
    }
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("resumeCountdown")
  }

  // MARK: Pause

  private var pausePanel: some View {
    panel {
      HStack {
        eyebrow("PAUSED", color: Palette.mint)
        Spacer()
        Image(systemName: "moon.stars.fill").foregroundStyle(Palette.mint)
      }
      Text("Catch your breath.")
        .font(.system(size: 28, weight: .heavy, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 0) {
        dockStat(
          "DISTANCE", value: "\(Int(game.engine.distance).formatted()) m", icon: "location.fill",
          color: Palette.mint)
        dockDivider
        dockStat(
          "COINS", value: "\(game.engine.coins)", icon: "circle.inset.filled", color: Palette.gold)
        dockDivider
        dockStat(
          "BEST", value: "\(game.record.bestDistance.formatted()) m", icon: "laurel.leading",
          color: Palette.pink)
      }
      .padding(.vertical, 14)
      .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
      primary("RESUME", icon: "play.fill", action: game.resume)
        .accessibilityIdentifier("resumeRun")
      HStack(spacing: 10) {
        secondary("Restart", icon: "arrow.counterclockwise", action: game.start)
          .accessibilityIdentifier("restartRun")
        secondary("End run", icon: "house.fill", action: game.home)
          .accessibilityIdentifier("endRun")
      }
      VStack(spacing: 0) {
        settingRow(
          "Sound", icon: game.sound ? "speaker.wave.2.fill" : "speaker.slash.fill",
          isOn: $game.sound
        )
        .accessibilityIdentifier("soundToggle")
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 44)
        settingRow("On-screen controls", icon: "dpad.fill", isOn: $game.showControls)
          .accessibilityIdentifier("controlsToggle")
      }
      .padding(.horizontal, 14)
      .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
      Text("Resuming counts you in from three.")
        .font(.system(size: 12))
        .foregroundStyle(Palette.muted)
    }
  }

  private func settingRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Palette.mint).frame(width: 30)
        Text(title).font(.system(size: 15, weight: .semibold))
      }
    }
    .tint(Palette.mint)
    .frame(minHeight: 52)
  }

  // MARK: Results

  private var resultPanel: some View {
    panel {
      HStack {
        resultBadge
        Spacer()
        ShareLink(item: shareText) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.07), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.12)))
        }
        .accessibilityLabel("Share result")
        .accessibilityIdentifier("shareResult")
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(game.newBest ? "Made your mark." : "Wiped out.")
          .font(.system(size: 26, weight: .heavy, design: .rounded))
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(Int(game.engine.distance).formatted())")
            .font(.system(size: 68, weight: .black, design: .rounded)).tracking(-2)
            .minimumScaleFactor(0.6).lineLimit(1)
            .foregroundStyle(game.newBest ? Palette.mint : .white)
            .shadow(color: (game.newBest ? Palette.mint : Palette.pink).opacity(0.4), radius: 18)
          Text("metres").font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.muted)
          Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finalDistance")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 8) {
        BestRail(
          progress: game.previousBest == 0
            ? 1 : game.engine.distance / Double(max(game.previousBest, Int(game.engine.distance))),
          tint: game.newBest ? Palette.mint : Palette.pink)
        HStack {
          Text(districtLabel)
            .lineLimit(1)
          Spacer(minLength: 10)
          Text(bestDelta)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(game.newBest ? Palette.mint : Palette.muted)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(1)
        .foregroundStyle(Palette.muted)
      }
      HStack(spacing: 0) {
        dockStat(
          "COINS", value: "\(game.engine.coins)", icon: "circle.inset.filled", color: Palette.gold)
        dockDivider
        dockStat(
          "DODGED", value: game.engine.obstaclesCleared.formatted(), icon: "bolt.fill",
          color: Palette.pink)
        dockDivider
        dockStat(
          "BEST", value: "\(game.record.bestDistance.formatted()) m", icon: "laurel.leading",
          color: Palette.mint)
      }
      .padding(.vertical, 14)
      .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08)))
      crashTip
      primary("RIDE AGAIN", icon: "arrow.clockwise", action: game.start)
        .accessibilityIdentifier("retryRun")
      Button(action: game.home) {
        Text("Back to title")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Palette.muted)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .accessibilityIdentifier("backHome")
    }
  }

  private var resultBadge: some View {
    let tint = game.newBest ? Palette.mint : Palette.pink
    return HStack(spacing: 6) {
      Image(systemName: game.newBest ? "trophy.fill" : "flag.checkered")
      Text(game.newBest ? "NEW PERSONAL BEST" : "RUN \(game.record.runs) COMPLETE")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .tracking(1.6)
    }
    .font(.system(size: 11, weight: .bold))
    .foregroundStyle(tint)
    .padding(.horizontal, 12)
    .frame(height: 30)
    .background(tint.opacity(0.12), in: Capsule())
    .overlay(Capsule().strokeBorder(tint.opacity(0.35)))
  }

  private var districtLabel: String {
    let district = GameStore.district(for: game.engine.distance)
    return "0\(district.index + 1) / \(district.name)"
  }

  private var shareText: String {
    "I skated \(Int(game.engine.distance).formatted()) m and grabbed \(game.engine.coins) coins on Neon Boardwalk. Best: \(game.record.bestDistance.formatted()) m."
  }

  private var bestDelta: String {
    let gap = Int(game.engine.distance) - game.previousBest
    if game.previousBest == 0 { return "FIRST RUN LOGGED" }
    if gap > 0 { return "+\(gap.formatted()) m OVER OLD BEST" }
    return "\((-gap).formatted()) m SHORT OF BEST"
  }

  private var crashTip: some View {
    let tip: (icon: String, color: Color, text: String) =
      switch game.engine.collision {
      case .barrier:
        ("arrow.up", Palette.amber, "Amber barriers: swipe up to jump, or change lanes.")
      case .sign:
        ("arrow.down", Palette.pink, "Pink signs: swipe down to slide under, or change lanes.")
      case .cart:
        (
          "arrow.left.and.right", Palette.mint,
          "Arcade carts block a lane. Watch for the open route."
        )
      case nil: ("sparkles", Palette.mint, "A little further, a little smoother.")
      }
    return HStack(spacing: 12) {
      Image(systemName: tip.icon)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Palette.navy)
        .frame(width: 30, height: 30)
        .background(tip.color, in: RoundedRectangle(cornerRadius: 9))
      Text(tip.text)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.85))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
  }

  // MARK: Guide

  private var guide: some View {
    panel {
      HStack {
        eyebrow("HOW TO RIDE", color: Palette.mint)
        Spacer()
        Button {
          game.showGuide = false
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 36, height: 36)
            .background(.white.opacity(0.08), in: Circle())
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Close guide")
        .accessibilityIdentifier("closeGuide")
      }
      Text("Four moves.\nOne endless coast.")
        .font(.system(size: 28, weight: .heavy, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .leading)
      VStack(spacing: 10) {
        guideRow(
          "arrow.left.and.right", title: "Change lanes",
          detail: "Swipe left or right. Arcade carts must be dodged.", color: Palette.mint)
        guideRow(
          "arrow.up", title: "Jump", detail: "Swipe up to clear amber barriers.",
          color: Palette.amber)
        guideRow(
          "arrow.down", title: "Slide", detail: "Swipe down to duck under pink signs.",
          color: Palette.pink)
        guideRow(
          "shield.fill", title: "Shield", detail: "Turquoise rings absorb one hit for 10 seconds.",
          color: Palette.mint)
      }
      HStack(spacing: 8) {
        Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.mint)
        Text("Every row leaves an open lane. Prefer taps? Use the controls at the bottom.")
          .font(.system(size: 12))
          .foregroundStyle(Palette.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      primary("GOT IT, LET’S RIDE", icon: "play.fill", action: game.start)
        .accessibilityIdentifier("guideStart")
    }
  }

  private func guideRow(_ icon: String, title: String, detail: String, color: Color) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon).font(.system(size: 18, weight: .bold))
        .foregroundStyle(Palette.navy)
        .frame(width: 42, height: 42)
        .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: color.opacity(0.45), radius: 8)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.system(size: 15, weight: .bold))
        Text(detail).font(.system(size: 12)).foregroundStyle(Palette.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: Shared

  private var soundButton: some View {
    Button {
      game.sound.toggle()
    } label: {
      Image(systemName: game.sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
        .font(.system(size: 15, weight: .semibold))
        .frame(width: 44, height: 44)
        .background(Glass(radius: 22, opacity: 0.5))
    }
    .buttonStyle(PressableStyle())
    .accessibilityLabel(game.sound ? "Mute sound" : "Enable sound")
    .accessibilityIdentifier("soundToggle")
  }

  private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      Palette.navy.opacity(0.6).ignoresSafeArea()
      ScrollView {
        VStack(spacing: 16, content: content)
          .padding(22)
          .background(
            LinearGradient(
              colors: [Palette.ink, Palette.navy], startPoint: .topLeading,
              endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [.white.opacity(0.22), .white.opacity(0.05)], startPoint: .top,
                  endPoint: .bottom))
          )
          .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
          .padding(18)
      }
      .scrollBounceBehavior(.basedOnSize)
      .defaultScrollAnchor(.center)
    }
  }

  private func eyebrow(_ text: String, color: Color = Palette.muted) -> some View {
    Text(text).font(.system(size: 9, weight: .bold, design: .monospaced))
      .tracking(1.8).foregroundStyle(color)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
  }

  private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(size: 15, weight: .heavy)).tracking(1.2)
        Spacer()
        Image(systemName: icon).font(.system(size: 16, weight: .bold))
          .frame(width: 34, height: 34)
          .background(Palette.navy.opacity(0.12), in: Circle())
      }
      .foregroundStyle(Palette.navy)
      .padding(.leading, 22)
      .padding(.trailing, 13)
      .frame(height: 60)
      .background(
        LinearGradient(
          colors: [Color(red: 0.66, green: 1, blue: 0.93), Palette.mint],
          startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.4))
      )
      .shadow(color: Palette.mint.opacity(0.4), radius: 18, y: 6)
    }
    .buttonStyle(PressableStyle())
  }

  private func secondary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: icon).font(.system(size: 13, weight: .bold))
        Text(title).font(.system(size: 14, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12)))
    }
    .buttonStyle(PressableStyle())
  }
}

private struct NativeTrack: UIViewControllerRepresentable {
  @ObservedObject var game: GameStore

  func makeUIViewController(context: Context) -> TrackController {
    TrackController(game: game)
  }

  func updateUIViewController(_ controller: TrackController, context: Context) {
    controller.view.accessibilityLabel = game.engine.routeDescription
  }
}

private final class TrackController: UIViewController {
  private let game: GameStore
  override var canBecomeFirstResponder: Bool { true }

  init(game: GameStore) {
    self.game = game
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("Storyboard initialization is unsupported") }

  override func loadView() {
    let track = SCNView()
    track.scene = game.world.scene
    track.pointOfView = game.world.camera
    track.antialiasingMode = .multisampling4X
    track.preferredFramesPerSecond = 60
    track.isPlaying = true
    track.isAccessibilityElement = true
    track.accessibilityIdentifier = "boardwalk"
    track.accessibilityTraits = .updatesFrequently
    for direction: UISwipeGestureRecognizer.Direction in [.left, .right, .up, .down] {
      let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipe(_:)))
      recognizer.direction = direction
      track.addGestureRecognizer(recognizer)
    }
    view = track
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  @objc private func swipe(_ gesture: UISwipeGestureRecognizer) {
    switch gesture.direction {
    case .left: game.move(.left)
    case .right: game.move(.right)
    case .up: game.move(.jump)
    case .down: game.move(.slide)
    default: break
    }
  }

  override var keyCommands: [UIKeyCommand]? {
    [
      UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(left)),
      UIKeyCommand(
        input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(right)),
      UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(jump)),
      UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(slide)),
      UIKeyCommand(input: " ", modifierFlags: [], action: #selector(togglePause)),
    ]
  }

  @objc private func left() { game.move(.left) }
  @objc private func right() { game.move(.right) }
  @objc private func jump() { game.move(.jump) }
  @objc private func slide() { game.move(.slide) }
  @objc private func togglePause() {
    if game.engine.phase == .paused { game.resume() } else { game.pause() }
  }
}
