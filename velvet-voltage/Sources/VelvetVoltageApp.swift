import SpriteKit
import SwiftUI
import UIKit

@main
struct VelvetVoltageApp: App {
  var body: some Scene {
    WindowGroup { VoltageView().preferredColorScheme(.dark) }
  }
}

struct VoltageView: View {
  @StateObject private var game = GameSession()
  @State private var scene: VoltageScene?
  @State private var settings = false
  @State private var shareItem: SharePoster?
  @State private var confirmRestart = false
  @Environment(\.scenePhase) private var phase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 380
      ZStack {
        RadialGradient(
          colors: [Color(Ink.panel), Color(Ink.background)],
          center: .top, startRadius: 40, endRadius: 650
        ).ignoresSafeArea()
        if game.screen == .results {
          results
        } else {
          VStack(spacing: 0) {
            if game.screen == .playing { scoreboard } else { masthead }
            playArea
            if game.screen == .home { homeFooter }
          }
          .padding(.horizontal, compact ? 14 : 20)
          .padding(.top, 8)
          .padding(.bottom, 6)
        }
        if game.paused, game.screen == .playing { pauseOverlay }
      }
    }
    .tint(Color(Ink.brass))
    .onAppear {
      scene = VoltageScene(session: game)
      game.reducedMotion = reduceMotion
    }
    .onChange(of: reduceMotion) { _, value in game.reducedMotion = value }
    .onChange(of: phase) { _, value in if value != .active { game.pause() } }
    .sheet(isPresented: $settings) { settingsView }
    .sheet(item: $shareItem) { item in
      ShareSheet(image: item.image, text: item.text)
    }
    .alert("Restart this three-ball game?", isPresented: $confirmRestart) {
      Button("Restart game", role: .destructive) { game.newGame() }
      Button("Cancel", role: .cancel) {}
    }
  }

  // MARK: Table and controls

  private var playArea: some View {
    ZStack {
      VStack(spacing: 8) {
        if let scene {
          SpriteView(scene: scene, options: [.allowsTransparency])
            .aspectRatio(390 / 620, contentMode: .fit)
            .accessibilityLabel(
              "Pinball table. The glowing target is district \(game.score.nextDistrict + 1)."
            )
            .accessibilityIdentifier("pinballTable")
        }
        if game.screen == .playing { flipperPads }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      if game.screen == .playing {
        TouchDeck(game: game)
        accessibleControls
      }
      if game.screen == .tutorial { tutorial }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var flipperPads: some View {
    HStack(spacing: 10) {
      FlipperPad(left: true, held: game.leftHeld)
      launchCue
      FlipperPad(left: false, held: game.rightHeld)
    }
    .frame(height: 74)
    .animation(.easeOut(duration: 0.12), value: game.inFlight)
  }

  private var launchCue: some View {
    VStack(spacing: 5) {
      if game.inFlight {
        Text(game.coaching ? "TOUCH\nA SIDE" : "FLIP")
          .foregroundStyle(Color(Ink.brass))
      } else {
        Image(systemName: "arrow.down")
          .font(.system(size: 15, weight: .bold))
          .offset(y: game.plungerPull * 10)
        Text(game.plungerPull > 0.05 ? "RELEASE" : "PULL")
      }
    }
    .font(.custom("AvenirNextCondensed-Bold", size: 11)).tracking(1.4)
    .multilineTextAlignment(.center)
    .foregroundStyle(game.inFlight ? Color(Ink.brass) : Color(Ink.cyan))
    .frame(width: 66)
    .frame(maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.45))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12).stroke(
        (game.inFlight ? Color(Ink.brass) : Color(Ink.cyan)).opacity(game.inFlight ? 0.35 : 0.8),
        lineWidth: 1)
    )
    .accessibilityHidden(true)
  }

  private var accessibleControls: some View {
    HStack(spacing: 0) {
      Color.clear
        .accessibilityElement()
        .accessibilityLabel("Left flipper")
        .accessibilityHint("Touch the left half of the table to flip.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("leftFlipper")
        .accessibilityAction { tapFlipper(left: true) }
      Color.clear
        .frame(width: 66)
        .accessibilityElement()
        .accessibilityLabel(game.inFlight ? "Ball in play" : "Launch ball")
        .accessibilityHint("Pull down and release, or tap anywhere on the table.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("launchButton")
        .accessibilityAction { game.launch() }
      Color.clear
        .accessibilityElement()
        .accessibilityLabel("Right flipper")
        .accessibilityHint("Touch the right half of the table to flip.")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("rightFlipper")
        .accessibilityAction { tapFlipper(left: false) }
    }
    .allowsHitTesting(false)
  }

  private func tapFlipper(left: Bool) {
    game.setFlipper(left: left, pressed: true)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(200))
      game.setFlipper(left: left, pressed: false)
    }
  }

  // MARK: Home

  private var masthead: some View {
    VStack(spacing: 0) {
      HStack {
        eyebrow("No. 01  /  ELECTRIC PINBALL")
        Spacer()
        Button {
          settings = true
        } label: {
          Image(systemName: "slider.horizontal.3").font(.system(size: 16)).frame(
            width: 44, height: 44)
        }.accessibilityLabel("Settings").accessibilityIdentifier("settingsButton")
      }
      BrandLockup().frame(height: 82)
      DecoRule().frame(height: 10).padding(.top, 6)
    }
  }

  private var homeFooter: some View {
    VStack(spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          eyebrow("HOUSE RECORD")
          Text(game.best > 0 ? "\(game.best.formatted()) V" : "UNCLAIMED")
            .font(.custom("AvenirNextCondensed-DemiBold", size: 21))
            .foregroundStyle(Color(Ink.cream))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          eyebrow("CIRCUITS LIT")
          Text("\(game.lifetimeCircuits)")
            .font(.custom("AvenirNextCondensed-DemiBold", size: 21))
            .foregroundStyle(Color(Ink.cream))
        }
      }
      primary("PLAY", icon: "bolt.fill", identifier: "playButton") { game.start() }
      Button {
        game.showTutorial()
      } label: {
        Text("HOW TO PLAY")
          .font(.custom("AvenirNextCondensed-DemiBold", size: 12)).tracking(1.8)
          .frame(maxWidth: .infinity, minHeight: 44)
      }
      .foregroundStyle(Color(Ink.brass))
      .accessibilityIdentifier("howToPlayButton")
    }
    .padding(.top, 8)
  }

  // MARK: HUD

  private var scoreboard: some View {
    VStack(spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          eyebrow("VOLTAGE")
          DotMatrixScore(value: game.score.points, color: Color(Ink.cream))
            .frame(height: 30)
            .accessibilityIdentifier("scoreValue")
        }
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 5) {
          Text("\(game.score.multiplier)×").font(.custom("Baskerville-Italic", size: 24))
            .foregroundStyle(Color(Ink.cyan))
            .accessibilityLabel("Multiplier \(game.score.multiplier) times")
          HStack(spacing: 5) {
            ForEach(1...3, id: \.self) { ball in
              Circle().fill(
                ball >= game.ballNumber ? Color(Ink.cream) : Color(Ink.brass).opacity(0.25)
              ).frame(width: 7, height: 7)
            }
            Text("BALL \(game.ballNumber)")
              .font(.custom("AvenirNextCondensed-DemiBold", size: 11)).tracking(1)
              .foregroundStyle(Color(Ink.cream))
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Ball \(game.ballNumber) of 3")
          .accessibilityIdentifier("ballCount")
        }
        Button {
          game.pause()
        } label: {
          Image(systemName: "pause.fill").font(.system(size: 14)).frame(width: 44, height: 44)
            .background(Color(Ink.brass).opacity(0.1), in: Circle())
        }.accessibilityLabel("Pause game").accessibilityIdentifier("pauseButton")
      }
      .padding(.horizontal, 14).padding(.vertical, 11)
      .background(
        LinearGradient(
          colors: [Color.black.opacity(0.8), Color(Ink.panel)], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10).stroke(Color(Ink.brass).opacity(0.55), lineWidth: 0.7))
      circuitStrip
    }
  }

  private var circuitStrip: some View {
    HStack(spacing: 6) {
      ForEach(0..<3, id: \.self) { index in
        let lit = index < game.score.nextDistrict
        let next = index == game.score.nextDistrict && game.inFlight
        HStack(spacing: 5) {
          Circle()
            .fill(lit || next ? Color(Ink.cyan) : Color(Ink.brass).opacity(0.3))
            .frame(width: 6, height: 6)
            .shadow(color: Color(Ink.cyan).opacity(next ? 0.9 : 0), radius: 4)
          Text(["ARCADE", "SPIRE", "RIVIERA"][index])
            .font(.custom("AvenirNextCondensed-DemiBold", size: 10)).tracking(1)
            .foregroundStyle(
              next ? Color(Ink.cyan) : lit ? Color(Ink.cream) : Color(Ink.brass).opacity(0.7))
        }
        if index < 2 {
          Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color(Ink.brass).opacity(0.5))
        }
      }
      Spacer(minLength: 8)
      Text(game.banner)
        .font(.custom("AvenirNextCondensed-DemiBold", size: 11)).tracking(1)
        .foregroundStyle(Color(Ink.cyan)).lineLimit(1).minimumScaleFactor(0.6)
        .contentTransition(.opacity)
        .accessibilityIdentifier("bannerText")
    }
    .padding(.horizontal, 6)
    .animation(.easeInOut(duration: 0.2), value: game.banner)
    .accessibilityElement(children: .combine)
  }

  // MARK: Tutorial

  private var tutorial: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        eyebrow("HOW TO PLAY")
        Spacer()
        Button("Close") { game.screen = .home }
          .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
          .accessibilityIdentifier("tutorialClose")
      }
      Text("Make the\ncity hum.").font(.custom("Baskerville-Italic", size: 42)).foregroundStyle(
        Color(Ink.cream))
      ControlDiagram().frame(height: 96)
      lesson(
        "01", title: "Pull down to launch.",
        text: "Drag down anywhere on the table and let go. A quick tap fires at full power.")
      lesson(
        "02", title: "Touch either side to flip.",
        text:
          "The whole left half is your left flipper; the right half is your right. Hold to keep one raised."
      )
      lesson(
        "03", title: "Follow the cyan light.",
        text:
          "Hit Arcade → Spire → Riviera in order. Each circuit lights more of the city and raises your multiplier."
      )
      primary("LET’S PLAY", icon: "arrow.right", identifier: "tutorialStart") { game.newGame() }
    }
    .padding(22)
    .background(Color(Ink.background).opacity(0.98), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(Ink.brass).opacity(0.8), lineWidth: 1))
    .shadow(color: .black, radius: 25, y: 12)
    .padding(.vertical, 8)
  }

  private func lesson(_ number: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Text(number).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(
        Color(Ink.cyan))
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 14, weight: .semibold))
        Text(text).font(.system(size: 12)).foregroundStyle(Color(Ink.cream).opacity(0.7)).fixedSize(
          horizontal: false, vertical: true)
      }.foregroundStyle(Color(Ink.cream))
    }
  }

  // MARK: Pause and results

  private var pauseOverlay: some View {
    ZStack {
      Color(Ink.background).opacity(0.94).ignoresSafeArea()
      VStack(spacing: 21) {
        eyebrow("PAUSED")
        DecoRule().frame(height: 10)
        Text("The night\ncan wait.").font(.custom("Baskerville-Italic", size: 51))
          .multilineTextAlignment(.center)
        HStack(spacing: 24) {
          stat("VOLTAGE", "\(game.score.points.formatted())")
          stat("BALL", "\(game.ballNumber) / 3")
          stat("POWER", "\(game.score.multiplier)×")
        }
        primary("RESUME", icon: "play.fill", identifier: "resumeButton") { game.paused = false }
        Button("Restart game") { confirmRestart = true }.frame(minHeight: 44)
          .accessibilityIdentifier("restartButton")
        Button("Settings") { settings = true }.frame(minHeight: 44)
        Button("Return to club") {
          game.screen = .home
          game.paused = false
        }.frame(minHeight: 44)
      }.padding(36).foregroundStyle(Color(Ink.cream))
    }
  }

  private func stat(_ title: String, _ value: String) -> some View {
    VStack(spacing: 3) {
      eyebrow(title)
      Text(value).font(.custom("AvenirNextCondensed-DemiBold", size: 18))
    }
  }

  private var results: some View {
    VStack(spacing: 16) {
      ScorePoster(score: game.score, best: game.best, newRecord: game.newRecord)
        .frame(maxHeight: .infinity)
      VStack(spacing: 10) {
        primary("PLAY AGAIN", icon: "arrow.clockwise", identifier: "replayButton") {
          game.newGame()
        }
        HStack(spacing: 10) {
          Button {
            share()
          } label: {
            Label("SHARE POSTER", systemImage: "square.and.arrow.up")
              .font(.custom("AvenirNextCondensed-DemiBold", size: 12)).tracking(1.4)
              .frame(maxWidth: .infinity, minHeight: 48)
          }
          .background(Color(Ink.brass).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
          .overlay(
            RoundedRectangle(cornerRadius: 9).stroke(Color(Ink.brass).opacity(0.5), lineWidth: 0.7)
          )
          .accessibilityIdentifier("shareButton")
          Button {
            game.screen = .home
          } label: {
            Image(systemName: "house").frame(width: 52, height: 48)
          }
          .background(Color(Ink.brass).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
          .overlay(
            RoundedRectangle(cornerRadius: 9).stroke(Color(Ink.brass).opacity(0.5), lineWidth: 0.7)
          )
          .accessibilityLabel("Return home").accessibilityIdentifier("homeButton")
        }.foregroundStyle(Color(Ink.cream))
      }
    }.padding(24)
  }

  private func share() {
    let renderer = ImageRenderer(
      content: ScorePoster(score: game.score, best: game.best, newRecord: game.newRecord).frame(
        width: 390, height: 620))
    renderer.scale = 3
    guard let image = renderer.uiImage else { return }
    shareItem = SharePoster(
      image: image,
      text:
        "I powered the night: \(game.score.points.formatted()) volts and \(game.score.circuits) \(game.score.circuits == 1 ? "circuit" : "circuits") in Velvet Voltage."
    )
  }

  private var settingsView: some View {
    NavigationStack {
      Form {
        Section("The atmosphere") {
          Toggle("Arcade audio", isOn: $game.sound).accessibilityIdentifier("soundToggle")
          Toggle("Haptic feedback", isOn: $game.haptics).accessibilityIdentifier("hapticsToggle")
        }
        Section("Your club record · on this iPhone") {
          LabeledContent("Personal best", value: "\(game.best.formatted()) V")
          LabeledContent("Completed circuits", value: "\(game.lifetimeCircuits)")
          LabeledContent("Finished games", value: "\(game.gamesPlayed)")
        }
        Section {
          Text(
            "Pull down anywhere on the table to launch; touch the left or right half to flip. Hit the cyan district in order: Arcade, Spire, Riviera. Bumpers earn 100 × multiplier; ordered hits add 250 ×. A circuit adds 1,500 × and raises the multiplier up to 5×. Three balls per game."
          )
          .font(.footnote)
          Text(
            "Progress saves automatically. An interrupted game pauses while the app stays open; relaunch returns to the club with your records intact."
          ).font(.footnote)
        } header: {
          Text("House rules")
        }
      }
      .tint(Color(Ink.coral))
      .navigationTitle("Club settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { settings = false } }
      }
    }.presentationDetents([.large])
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.custom("AvenirNextCondensed-DemiBold", size: 10)).tracking(1.5)
      .foregroundStyle(Color(Ink.brass))
  }

  private func primary(
    _ text: String, icon: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(text).tracking(2)
        Spacer()
        Image(systemName: icon)
      }
      .font(.custom("AvenirNextCondensed-Bold", size: 15))
      .padding(.horizontal, 22).frame(height: 54)
    }.buttonStyle(MachineButtonStyle(color: Color(Ink.coral))).accessibilityIdentifier(identifier)
  }
}

struct FlipperPad: View {
  let left: Bool
  let held: Bool
  var body: some View {
    HStack(spacing: 8) {
      if !left { Spacer(minLength: 0) }
      Image(systemName: left ? "arrow.up.left" : "arrow.up.right")
        .font(.system(size: 14, weight: .bold))
      Text(left ? "LEFT" : "RIGHT")
        .font(.custom("AvenirNextCondensed-Bold", size: 13)).tracking(1.6)
      if left { Spacer(minLength: 0) }
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(held ? Color(Ink.background) : Color(Ink.cream))
    .background(
      LinearGradient(
        colors: held
          ? [Color(Ink.coral), Color(Ink.coral).opacity(0.85)]
          : [Color(Ink.panel), Color(Ink.background)],
        startPoint: .top, endPoint: .bottom
      ), in: RoundedRectangle(cornerRadius: 12)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12).stroke(
        held ? Color(Ink.cream).opacity(0.6) : Color(Ink.brass).opacity(0.6), lineWidth: 1)
    )
    .overlay(alignment: .bottom) {
      Capsule().fill(held ? Color(Ink.background) : Color(Ink.coral)).frame(width: 34, height: 2)
        .padding(.bottom, 7)
    }
    .scaleEffect(held ? 0.97 : 1)
    .animation(.easeOut(duration: 0.08), value: held)
    .accessibilityHidden(true)
  }
}

struct ControlDiagram: View {
  var body: some View {
    GeometryReader { proxy in
      let w = proxy.size.width
      let h = proxy.size.height
      ZStack {
        RoundedRectangle(cornerRadius: 10).fill(Color(Ink.panel))
        RoundedRectangle(cornerRadius: 10).stroke(Color(Ink.brass).opacity(0.6), lineWidth: 1)
        Rectangle().fill(Color(Ink.brass).opacity(0.4)).frame(width: 1, height: h - 20)
        HStack {
          Label("LEFT FLIPPER", systemImage: "hand.tap")
          Spacer()
          Label("RIGHT FLIPPER", systemImage: "hand.tap")
        }
        .font(.custom("AvenirNextCondensed-DemiBold", size: 10)).tracking(1)
        .foregroundStyle(Color(Ink.coral)).padding(.horizontal, 16).offset(y: h * 0.28)
        VStack(spacing: 2) {
          Image(systemName: "arrow.down").font(.system(size: 13, weight: .bold))
          Text("PULL TO LAUNCH").font(.custom("AvenirNextCondensed-DemiBold", size: 9)).tracking(1)
        }.foregroundStyle(Color(Ink.cyan)).position(x: w * 0.5, y: h * 0.32)
      }
    }
    .accessibilityHidden(true)
  }
}

struct BrandLockup: View {
  var body: some View {
    VStack(spacing: -5) {
      Text("Velvet").font(.custom("Baskerville-Italic", size: 58))
      HStack(spacing: 10) {
        Rectangle().frame(width: 21, height: 0.7)
        Text("VOLTAGE").font(.custom("AvenirNextCondensed-DemiBold", size: 21)).tracking(6)
        Rectangle().frame(width: 21, height: 0.7)
      }.foregroundStyle(Color(Ink.brass))
    }
    .foregroundStyle(Color(Ink.cream))
    .accessibilityElement(children: .ignore).accessibilityLabel("Velvet Voltage")
  }
}

struct DecoRule: View {
  var body: some View {
    HStack(spacing: 7) {
      Rectangle().frame(height: 0.5)
      Rectangle().frame(width: 4, height: 4).rotationEffect(.degrees(45))
      Rectangle().frame(width: 7, height: 7).rotationEffect(.degrees(45))
      Rectangle().frame(width: 4, height: 4).rotationEffect(.degrees(45))
      Rectangle().frame(height: 0.5)
    }.foregroundStyle(Color(Ink.brass).opacity(0.7)).accessibilityHidden(true)
  }
}

struct MachineButtonStyle: ButtonStyle {
  let color: Color
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Color(Ink.background))
      .background(
        LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 9)
      )
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.25), lineWidth: 0.7))
      .background(
        RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.3)).offset(y: 3)
      )
      .offset(y: configuration.isPressed ? 2 : 0)
      .brightness(configuration.isPressed ? -0.1 : 0)
  }
}

struct DotMatrixScore: View {
  let value: Int
  let color: Color
  private static let glyphs: [Character: [UInt8]] = [
    "0": [14, 17, 19, 21, 25, 17, 14],
    "1": [4, 12, 4, 4, 4, 4, 14],
    "2": [14, 17, 1, 2, 4, 8, 31],
    "3": [30, 1, 1, 14, 1, 1, 30],
    "4": [2, 6, 10, 18, 31, 2, 2],
    "5": [31, 16, 16, 30, 1, 1, 30],
    "6": [14, 16, 16, 30, 17, 17, 14],
    "7": [31, 1, 2, 4, 8, 8, 8],
    "8": [14, 17, 17, 14, 17, 17, 14],
    "9": [14, 17, 17, 15, 1, 1, 14],
  ]

  var body: some View {
    Canvas { context, size in
      let number = String(value)
      let characters = Array(String(repeating: "0", count: max(0, 6 - number.count)) + number)
      let columns = CGFloat(characters.count * 6 - 1)
      let cell = min(size.width / columns, size.height / 7)
      let origin = CGPoint(x: (size.width - cell * columns) / 2, y: (size.height - cell * 7) / 2)
      for (index, digit) in characters.enumerated() {
        let rows = Self.glyphs[digit] ?? Self.glyphs["0"]!
        for row in 0..<7 {
          for column in 0..<5 {
            let lit = rows[row] & (1 << (4 - column)) != 0
            let dot = CGRect(
              x: origin.x + CGFloat(index * 6 + column) * cell + cell * 0.12,
              y: origin.y + CGFloat(row) * cell + cell * 0.12,
              width: cell * 0.76, height: cell * 0.76
            )
            context.fill(Path(ellipseIn: dot), with: .color(color.opacity(lit ? 1 : 0.08)))
          }
        }
      }
    }
    .accessibilityElement().accessibilityLabel("\(value.formatted()) volts")
  }
}

struct ScorePoster: View {
  let score: ScoreCard
  let best: Int
  var newRecord = false
  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        ZStack(alignment: .top) {
          Image("MidnightCity").resizable().scaledToFill()
            .frame(width: proxy.size.width, height: proxy.size.height * 0.48).clipped()
          LinearGradient(
            stops: [
              .init(color: .black.opacity(0.85), location: 0), .init(color: .clear, location: 0.55),
              .init(color: .black.opacity(0.65), location: 1),
            ],
            startPoint: .top, endPoint: .bottom)
          VStack(spacing: 7) {
            Text("THE ELECTRIC SOCIAL CLUB")
              .font(.custom("AvenirNextCondensed-DemiBold", size: 9)).tracking(2.5)
            Text("What a night.").font(.custom("Baskerville-Italic", size: 38))
            Spacer()
            Text(score.circuits > 0 ? "YOU BROUGHT THE CITY TO LIFE" : "THE CITY WANTS AN ENCORE")
              .font(.custom("AvenirNextCondensed-DemiBold", size: 9)).tracking(1.4)
          }.foregroundStyle(Color(Ink.cream)).padding(.vertical, 21)
        }
        .frame(height: proxy.size.height * 0.48)
        VStack(spacing: 0) {
          HStack {
            Text("AFTER HOURS")
            Spacer()
            Text("SESSION COMPLETE")
          }.font(.custom("AvenirNextCondensed-DemiBold", size: 9)).tracking(1.4)
          Rectangle().frame(height: 0.7).opacity(0.3).padding(.top, 10)
          Spacer(minLength: 10)
          DotMatrixScore(value: score.points, color: Color(Ink.background))
            .frame(height: min(49, proxy.size.height * 0.085))
            .accessibilityIdentifier("resultScore")
          Text("VOLTS GENERATED").font(.custom("AvenirNextCondensed-DemiBold", size: 9))
            .tracking(3).padding(.top, 9)
          Spacer(minLength: 10)
          HStack(spacing: 28) {
            Text("\(score.circuits) \(score.circuits == 1 ? "CIRCUIT" : "CIRCUITS")")
            Text("\(score.multiplier)× POWER")
          }.font(.custom("AvenirNextCondensed-DemiBold", size: 14)).tracking(1)
          Text(newRecord ? "A NEW HOUSE RECORD" : "PERSONAL BEST  \(best.formatted()) V")
            .font(.custom("AvenirNextCondensed-DemiBold", size: 10)).tracking(1.2).padding(.top, 8)
          Spacer(minLength: 10)
          Rectangle().frame(height: 0.7).opacity(0.3)
          HStack(alignment: .firstTextBaseline) {
            Text("Velvet Voltage").font(.custom("Baskerville-Italic", size: 21))
            Spacer()
            Text("PLAY IT AGAIN.").font(.custom("AvenirNextCondensed-DemiBold", size: 8)).tracking(
              1.3)
          }.padding(.top, 10)
        }
        .padding(20).foregroundStyle(Color(Ink.background))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(Ink.cream))
      }
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(Ink.brass), lineWidth: 1))
    }
  }
}

struct SharePoster: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct ShareSheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
