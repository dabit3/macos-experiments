import CoreText
import SceneKit
import SwiftUI

@main
struct DriftPicnicApp: App {
  init() {
    if let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
  var body: some Scene {
    WindowGroup { PicnicView() }
  }
}

let ink = Color(uiColor: Palette.ink)
let navy = Color(uiColor: Palette.deepGreen)
let navyLight = Color(red: 0.14, green: 0.22, blue: 0.52)
let coin = Color(uiColor: Palette.butter)
let coinDeep = Color(red: 0.86, green: 0.50, blue: 0.04)
let paper = Color(uiColor: Palette.cream)
let cherry = Color(uiColor: Palette.pink)
let cherryDeep = Color(red: 0.58, green: 0.05, blue: 0.10)
let royal = Color(uiColor: Palette.blue)
let leaf = Color(uiColor: Palette.green)
let skyBlue = Color(uiColor: Palette.sky)
let slate = Color(red: 0.45, green: 0.47, blue: 0.58)

func raceTime(_ seconds: Double) -> String {
  guard seconds > 0 else { return "-'--\"--" }
  let whole = Int(seconds)
  let hundredths = Int((seconds - Double(whole)) * 100)
  return String(format: "%d'%02d\"%02d", whole / 60, whole % 60, hundredths)
}

func pixel(_ size: CGFloat) -> Font { .custom("PressStart2P-Regular", size: size) }

func ordinal(_ position: Int) -> String {
  ["", "1ST", "2ND", "3RD", "4TH"][position]
}

/// Hard 8-direction outline built from zero-radius shadows, like sprite text on a console.
struct Outlined: ViewModifier {
  var color: Color
  var width: CGFloat
  func body(content: Content) -> some View {
    content
      .shadow(color: color, radius: 0, x: width, y: 0)
      .shadow(color: color, radius: 0, x: -width, y: 0)
      .shadow(color: color, radius: 0, x: 0, y: width)
      .shadow(color: color, radius: 0, x: 0, y: -width)
  }
}

extension View {
  func outlined(_ color: Color = ink, _ width: CGFloat = 2) -> some View {
    modifier(Outlined(color: color, width: width))
  }
  func hardShadow(_ color: Color = ink, _ offset: CGFloat = 3) -> some View {
    shadow(color: color, radius: 0, x: offset, y: offset)
  }
  func retroPanel(_ fill: Color = navy, border: Color = paper) -> some View {
    modifier(RetroPanel(fill: fill, border: border))
  }
}

/// Pixel-font text with an ink outline. `size / 9` keeps the outline one "pixel" wide at any size.
struct RetroText: View {
  var text: String
  var size: CGFloat
  var color: Color = paper
  var outline: Color = ink
  init(_ text: String, _ size: CGFloat, _ color: Color = paper, outline: Color = ink) {
    self.text = text
    self.size = size
    self.color = color
    self.outline = outline
  }
  var body: some View {
    Text(text).font(pixel(size)).foregroundStyle(color)
      .outlined(outline, max(1.5, size / 9))
  }
}

/// A dialog box in the style of a 16-bit RPG: ink frame, fill, then a bright inner frame.
struct RetroPanel: ViewModifier {
  var fill: Color
  var border: Color
  func body(content: Content) -> some View {
    content.background {
      ZStack {
        Rectangle().fill(ink).offset(x: 5, y: 5)
        Rectangle().fill(fill)
        Rectangle().strokeBorder(border, lineWidth: 3).padding(5)
        Rectangle().strokeBorder(ink, lineWidth: 3)
      }
    }
  }
}

/// A chunky bevelled arcade button. Pressing snaps it down onto its hard shadow; no easing.
struct RetroButtonStyle: ButtonStyle {
  var fill: Color = coin
  var text: Color = ink
  var height: CGFloat = 50
  var size: CGFloat = 11
  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    return configuration.label
      .font(pixel(size)).foregroundStyle(text)
      .frame(maxWidth: .infinity).frame(height: height)
      .background {
        ZStack {
          Rectangle().fill(fill)
          VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.5)).frame(height: 4)
            Spacer()
            Rectangle().fill(.black.opacity(0.3)).frame(height: 6)
          }.padding(3)
          Rectangle().strokeBorder(ink, lineWidth: 3)
        }
      }
      .background { Rectangle().fill(ink).offset(y: pressed ? 0 : 5) }
      .offset(y: pressed ? 5 : 0)
      .animation(nil, value: pressed)
  }
}

struct RetroIconButtonStyle: ButtonStyle {
  var fill: Color = navy
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: 44, height: 44)
      .background {
        ZStack {
          Rectangle().fill(fill)
          Rectangle().strokeBorder(paper, lineWidth: 2).padding(3)
          Rectangle().strokeBorder(ink, lineWidth: 3)
        }
      }
      .background { Rectangle().fill(ink).offset(y: configuration.isPressed ? 0 : 4) }
      .offset(y: configuration.isPressed ? 4 : 0)
      .animation(nil, value: configuration.isPressed)
  }
}

/// Toggles visibility on a fixed clock, the classic "PRESS START" cadence.
struct Blink<Content: View>: View {
  var period = 0.5
  var animated = true
  @ViewBuilder var content: () -> Content
  var body: some View {
    TimelineView(.periodic(from: .now, by: period)) { context in
      let on = !animated || Int(context.date.timeIntervalSinceReferenceDate / period) % 2 == 0
      content().opacity(on ? 1 : 0)
    }
  }
}

/// Letters ride a stepped wave, advancing one frame every tenth of a second.
struct WaveText: View {
  var text: String
  var size: CGFloat
  var color: Color
  var animated = true
  private let lifts: [CGFloat] = [0, -2, -5, -8, -10, -8, -5, -2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.1)) { context in
      let frame = Int(context.date.timeIntervalSinceReferenceDate * 10)
      HStack(spacing: 0) {
        ForEach(Array(text.enumerated()), id: \.offset) { index, letter in
          let phase = (frame + index * 2) % lifts.count
          Text(String(letter)).font(pixel(size)).foregroundStyle(color)
            .offset(y: animated ? lifts[phase] : 0)
        }
      }
      .outlined(ink, size / 10)
      .hardShadow(cherryDeep, size / 10)
    }
  }
}

/// Tiny sprites drawn from character rows; one character is one pixel.
struct PixelArt: View {
  let rows: [String]
  var body: some View {
    Canvas { context, size in
      let columns = rows.map(\.count).max() ?? 1
      let cell = floor(min(size.width / CGFloat(columns), size.height / CGFloat(rows.count)))
      let ox = (size.width - cell * CGFloat(columns)) / 2
      let oy = (size.height - cell * CGFloat(rows.count)) / 2
      for (y, row) in rows.enumerated() {
        for (x, character) in row.enumerated() {
          guard let color = Sprites.palette[character] else { continue }
          context.fill(
            Path(
              CGRect(
                x: ox + CGFloat(x) * cell, y: oy + CGFloat(y) * cell, width: cell, height: cell)),
            with: .color(color))
        }
      }
    }
  }
}

enum Sprites {
  static let palette: [Character: Color] = [
    "k": ink, "w": paper, "y": coin, "r": cherry, "b": royal, "g": leaf,
    "o": Color(red: 0.93, green: 0.52, blue: 0.20),
    "p": Color(red: 1, green: 0.62, blue: 0.72), "s": Color(red: 0.55, green: 0.55, blue: 0.64),
    "t": Color(red: 0.80, green: 0.80, blue: 0.86), "c": skyBlue,
  ]
  static let arrowLeft = [
    "....kk...", "...kwk...", "..kwwk...", ".kwwwkkkk", "kwwwwwwwk", ".kwwwkkkk", "..kwwk...",
    "...kwk...", "....kk...",
  ]
  static let arrowRight = arrowLeft.map { String($0.reversed()) }
  static let cursor = [
    "k....", "kk...", "kyk..", "kyyk.", "kyyyk", "kyyk.", "kyk..", "kk...", "k....",
  ]
  static let lemonade = [
    "......kk..", ".....krk..", "....krk...", ".kkkkrkkk.", "kwwwwrwwwk", "kwyyyyyyyk",
    "kwyyyyyyyk", "kwyywwyyyk", "kwyyyyyyyk", ".kwyyyyyk.", ".kwyyyyyk.", "..kkkkkk..",
  ]
  static let bolt = [
    "....kkk.", "...kyyk.", "..kyyk..", ".kyyk...", "kyyyykkk", "kkkyyyyk", "..kyyyk.", "...kyyk.",
    "....kyk.", "...kyk..", "..kyk...", "..kk....",
  ]
  static let speaker = [
    "....k.....", "...kk..k..", "..kwk...k.", "kkkwk.k.k.", "kwwwk.k.k.", "kkkwk.k.k.",
    "..kwk...k.",
    "...kk..k..", "....k.....",
  ]
  static let muted = [
    "....k.....", "...kk.....", "..kwk.r.r.", "kkkwk..r..", "kwwwk.r.r.", "kkkwk.....",
    "..kwk.....",
    "...kk.....", "....k.....",
  ]
  static let trophy = [
    "kkkkkkkkkk", "kyyyyyyyyk", "kkyyyyyykk", ".kyyyyyyk.", "..kyyyyk..", "...kyyk...",
    "....kk....",
    "...kyyk...", "..kyyyyk..", ".kkkkkkkk.",
  ]
  static let stopwatch = [
    "...kkk...", "....k....", "..kkkkk..", ".kwwwwwk.", "kwwwkwwwk", "kwwwkwwwk", "kwwwkkkwk",
    ".kwwwwwk.", "..kkkkk..",
  ]
  static let flag = [
    "k.........", "kkkkkkkkk.", "kwkwkwkwk.", "kkwkwkwkk.", "kwkwkwkwk.", "kkkkkkkkk.",
    "k.........",
    "k.........", "k.........",
  ]
  static let home = [
    "....kk....", "...kwwk...", "..kwwwwk..", ".kwwwwwwk.", "kkkwwwwkkk", "..kwwwwk..",
    "..kwkkwk..",
    "..kwkkwk..", "..kkkkkk..",
  ]
  static let steer = [
    "...kkkkk...", "..kwwwwwk..", ".kwkkkkkwk.", "kwk.....kwk", "kwk.....kwk", "kwk..k..kwk",
    ".kwkkkkkwk.", "..kwwwwwk..", "...kkkkk...",
  ]
  static let animals: [[String]] = [
    [
      "..kk....kk..", ".kwwk..kwwk.", ".kwpk..kpwk.", ".kwpk..kpwk.", ".kwwkkkkwwk.",
      ".kwwwwwwwwk.",
      "kwwwwwwwwwwk", "kwwkwwwwkwwk", "kwwwwwwwwwwk", "kwwwwrrwwwwk", ".kwwwwwwwwk.",
      "..kkkkkkkk..",
    ],
    [
      ".kk......kk.", "kookkkkkkook", "kooooooooook", "koookoookook", "kooooooooook",
      "koowwwwwwook",
      "koowwkkwwook", "koowwwwwwook", "kooooooooook", ".kooooooook.", "..kkkkkkkk..",
      "............",
    ],
    [
      "kk........kk", "ksk......ksk", "kssk....kssk", "kssskkkksssk", "kssssssssssk",
      "kssksssskssk",
      "kssssssssssk", "ksssskpksssk", "kssssssssssk", ".kssssssssk.", "..kkkkkkkk..",
      "............",
    ],
    [
      "..kkkkkkkk..", ".kwwwwwwwwk.", "kwwwwwwwwwwk", "kwwkkkkkkwwk", "kwkttttttkwk",
      "kwktkttktkwk",
      "kwkttttttkwk", "kwkttkkttkwk", "kwkttttttkwk", ".kwkkkkkkwk.", "..kkkkkkkk..",
      "............",
    ],
  ]
}

let driverNames = ["CLOVER", "MAPLE", "MOCHI", "PEPPER"]
let driverColors = [cherry, royal, leaf, coin]

struct PicnicView: View {
  @StateObject private var game = GameController()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        NativeScene(game: game).ignoresSafeArea()
        if game.phase == .title {
          title(geometry.size)
        } else if game.phase == .results {
          results(geometry.size)
        } else {
          hud(geometry.size)
          if game.phase == .countdown { countdownView }
          if game.phase == .paused { pausePanel }
        }
        if game.showGuide { guide(geometry.size) }
      }
      .foregroundStyle(paper)
      .onAppear { game.reducedMotion = reduceMotion }
      .onChange(of: reduceMotion) { _, value in game.reducedMotion = value }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active { game.pause() }
      }
    }
    .persistentSystemOverlays(.hidden)
  }

  // MARK: Countdown

  private var countdownView: some View {
    VStack(spacing: 14) {
      VStack(spacing: 8) {
        Text(game.mode == .picnic ? "PICNIC CUP  ·  3 LAPS  ·  3 RIVALS" : "TIME TRIAL  ·  3 LAPS")
          .font(pixel(7)).foregroundStyle(skyBlue)
        HStack(spacing: 10) {
          ForEach(0..<3, id: \.self) { lamp in
            let lit = lamp <= 3 - game.countdown
            Circle()
              .fill(game.countdown == 0 ? leaf : (lit ? cherry : cherryDeep.opacity(0.5)))
              .overlay { Circle().strokeBorder(ink, lineWidth: 3) }
              .frame(width: 30, height: 30)
          }
        }
      }
      .padding(.horizontal, 16).padding(.vertical, 10)
      .retroPanel()
      RetroText(
        game.countdown == 0 ? "GO!!" : "\(game.countdown)", game.countdown == 0 ? 64 : 80, coin
      )
      .hardShadow(cherryDeep, 6)
      .id(game.countdown)
      .transition(.scale(scale: 1.6))
    }
    .animation(reduceMotion ? nil : .linear(duration: 0.08), value: game.countdown)
    .allowsHitTesting(false)
  }

  // MARK: Title

  private func title(_ size: CGSize) -> some View {
    let compact = size.height < 400
    return ZStack {
      // Let the orbiting diorama breathe: darken only the edges where type sits.
      LinearGradient(
        colors: [ink.opacity(0.62), ink.opacity(0.1), .clear, ink.opacity(0.1), ink.opacity(0.62)],
        startPoint: .top, endPoint: .bottom
      ).ignoresSafeArea()
      LinearGradient(colors: [ink.opacity(0.55), .clear], startPoint: .leading, endPoint: .center)
        .ignoresSafeArea()
      VStack(spacing: 0) {
        HStack(alignment: .center) {
          Text("PICNIC GAMES").font(pixel(7)).foregroundStyle(paper.opacity(0.7))
          Spacer()
          Button(action: game.toggleSound) {
            PixelArt(rows: game.sound ? Sprites.speaker : Sprites.muted).frame(
              width: 24, height: 24)
          }
          .buttonStyle(RetroIconButtonStyle())
          .accessibilityLabel(game.sound ? "Mute sound" : "Enable sound")
        }
        Spacer(minLength: 6)
        HStack(alignment: .center, spacing: 24) {
          VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
              WaveText(text: "DRIFT", size: compact ? 44 : 52, color: coin, animated: !reduceMotion)
              WaveText(
                text: "PICNIC", size: compact ? 44 : 52, color: paper, animated: !reduceMotion)
            }
            RetroText("TOY-SIZED KART RACING", 9, skyBlue)
            recordsStrip.padding(.top, 6)
          }
          Spacer(minLength: 0)
          menuPanel(compact)
        }
        Spacer(minLength: 6)
        HStack(alignment: .bottom) {
          if !game.learnedControls {
            HStack(spacing: 8) {
              PixelArt(rows: Sprites.cursor).frame(width: 8, height: 14)
              Text("FIRST RACE? START WALKS YOU THROUGH THE CONTROLS").font(pixel(6))
                .foregroundStyle(coin)
            }
          } else {
            Text("STRAWBERRY CIRCUIT  ·  3 LAPS").font(pixel(6)).foregroundStyle(paper.opacity(0.7))
          }
          Spacer()
          Text("KEYBOARD  ← →  SPACE  B").font(pixel(6)).foregroundStyle(paper.opacity(0.45))
        }
      }
      .padding(.horizontal, compact ? 16 : 28).padding(.vertical, compact ? 10 : 16)
    }
  }

  private var recordsStrip: some View {
    HStack(spacing: 16) {
      record(Sprites.stopwatch, "BEST LAP", raceTime(game.bestLap))
      record(Sprites.trophy, "CUP WINS", "\(game.wins)")
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background {
      ZStack {
        Rectangle().fill(navy.opacity(0.85))
        Rectangle().strokeBorder(ink, lineWidth: 3)
      }
    }
  }

  private func record(_ icon: [String], _ label: String, _ value: String) -> some View {
    HStack(spacing: 7) {
      PixelArt(rows: icon).frame(width: 18, height: 18)
      VStack(alignment: .leading, spacing: 4) {
        Text(label).font(pixel(6)).foregroundStyle(coin)
        Text(value).font(pixel(8)).foregroundStyle(paper)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func menuPanel(_ compact: Bool) -> some View {
    VStack(spacing: compact ? 8 : 12) {
      RetroText("CHOOSE YOUR RACE", 8, coin)
      VStack(spacing: 8) {
        modeCard(
          .picnic, icon: Sprites.flag, detail: "3 RIVALS  ·  PODIUM",
          best: "BEST", value: raceTime(game.bestCup))
        modeCard(
          .trial, icon: Sprites.stopwatch, detail: "SOLO  ·  BEAT THE CLOCK",
          best: "BEST", value: raceTime(game.bestTrial))
      }
      Button(game.mode == .picnic ? "START RACE" : "START TRIAL", action: game.begin)
        .buttonStyle(RetroButtonStyle(height: compact ? 46 : 50, size: 12))
        .accessibilityIdentifier("startRace")
      Button("HOW TO PLAY") { game.showGuide = true }
        .buttonStyle(RetroButtonStyle(fill: royal, text: paper, height: 32, size: 7))
    }
    .padding(compact ? 12 : 16)
    .frame(width: compact ? 300 : 320)
    .retroPanel()
  }

  private func modeCard(
    _ mode: RaceMode, icon: [String], detail: String, best: String, value: String
  ) -> some View {
    let selected = game.mode == mode
    return Button {
      game.mode = mode
    } label: {
      HStack(spacing: 10) {
        PixelArt(rows: icon).frame(width: 22, height: 22)
        VStack(alignment: .leading, spacing: 5) {
          Text(mode.rawValue.uppercased()).font(pixel(9)).foregroundStyle(paper)
          Text(detail).font(pixel(5)).foregroundStyle(selected ? skyBlue : paper.opacity(0.6))
        }
        Spacer(minLength: 4)
        VStack(alignment: .trailing, spacing: 4) {
          Text(best).font(pixel(5)).foregroundStyle(coin)
          Text(value).font(pixel(7)).foregroundStyle(paper)
        }
      }
      .padding(.horizontal, 10).frame(height: 52)
      .background {
        ZStack {
          Rectangle().fill(selected ? royal : navyLight.opacity(0.6))
          Rectangle().strokeBorder(selected ? coin : ink, lineWidth: selected ? 3 : 2)
        }
      }
      .overlay(alignment: .leading) {
        if selected {
          PixelArt(rows: Sprites.cursor).frame(width: 8, height: 14).offset(x: -14)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(mode.rawValue), best \(value)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  // MARK: HUD

  private var ready: Bool { game.race.player.driftCharge >= 0.65 }
  private let padWidth: CGFloat = 196

  private func hud(_ size: CGSize) -> some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        standings
        Spacer()
        lapPanel
        Spacer()
        VStack(alignment: .trailing, spacing: 8) {
          HStack(spacing: 8) {
            Button(action: game.toggleSound) {
              PixelArt(rows: game.sound ? Sprites.speaker : Sprites.muted).frame(
                width: 22, height: 22)
            }
            .buttonStyle(RetroIconButtonStyle())
            .accessibilityLabel(game.sound ? "Mute sound" : "Enable sound")
            Button(action: game.pause) {
              HStack(spacing: 4) {
                Rectangle().fill(paper).frame(width: 6, height: 18)
                Rectangle().fill(paper).frame(width: 6, height: 18)
              }
            }
            .buttonStyle(RetroIconButtonStyle())
            .accessibilityLabel("Pause race").accessibilityIdentifier("pauseRace")
          }
          MiniMap(circuit: game.race.circuit, drivers: game.race.drivers, onCard: false)
            .frame(width: 96, height: 62)
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background {
              ZStack {
                Rectangle().fill(navy.opacity(0.7))
                Rectangle().strokeBorder(ink, lineWidth: 3)
              }
            }
        }
      }
      ZStack {
        if game.race.feedbackRemaining > 0 && game.phase == .racing {
          RetroText(game.race.feedback, 13, coin)
            .hardShadow(cherryDeep, 3)
            .transition(.scale(scale: 1.4))
            .accessibilityIdentifier("raceFeedback")
        }
      }
      .frame(height: 40).padding(.top, 6)
      .animation(
        reduceMotion ? nil : .linear(duration: 0.08), value: game.race.feedbackRemaining > 0)
      Spacer()
      HStack(alignment: .bottom, spacing: 12) {
        steeringPad
        Spacer()
        coachChip
        Spacer()
        itemButton
        driftButton
      }
    }
    .padding(.horizontal, 16).padding(.vertical, size.height < 400 ? 10 : 14)
  }

  private var standings: some View {
    VStack(alignment: .leading, spacing: 6) {
      if game.mode == .trial {
        RetroText("TIME TRIAL", 9, coin).hardShadow(cherryDeep, 2)
        Text("TARGET  \(raceTime(game.previousRecord))").font(pixel(6)).foregroundStyle(paper)
          .outlined(ink, 1.5)
      } else {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          RetroText("\(game.race.position)", 36, coin).hardShadow(cherryDeep, 4)
            .contentTransition(.identity)
          RetroText(String(ordinal(game.race.position).dropFirst()), 12, paper)
        }
        VStack(alignment: .leading, spacing: 3) {
          ForEach(game.race.standings, id: \.self) { driver in
            HStack(spacing: 5) {
              Rectangle().fill(driverColors[driver]).frame(width: 8, height: 8)
                .overlay { Rectangle().strokeBorder(ink, lineWidth: 1.5) }
              Text(driverNames[driver]).font(pixel(6))
                .foregroundStyle(driver == 0 ? coin : paper.opacity(0.85))
            }
          }
        }
        .padding(6)
        .background(navy.opacity(0.55))
        .animation(reduceMotion ? nil : .linear(duration: 0.1), value: game.race.standings)
      }
    }
    .frame(width: 104, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(game.mode == .trial ? "Time trial" : "Position \(game.race.position) of 4")
  }

  private var lapPanel: some View {
    let laps = game.race.player.tracker.laps
    let current = game.race.elapsed - game.race.player.lapStart
    return VStack(spacing: 6) {
      HStack(spacing: 10) {
        Text(laps == 2 ? "FINAL LAP" : "LAP").font(pixel(8)).foregroundStyle(coin)
        HStack(spacing: 3) {
          ForEach(0..<3, id: \.self) { lap in
            Rectangle()
              .fill(lap < laps ? coin : paper.opacity(lap == laps ? 1 : 0.3))
              .frame(width: 10, height: 8)
          }
        }
        Text("\(min(3, laps + 1))/3").font(pixel(10))
      }
      Text(raceTime(game.race.elapsed)).font(pixel(15)).foregroundStyle(paper)
        .contentTransition(.identity)
      Text("THIS LAP  \(raceTime(current))").font(pixel(6)).foregroundStyle(skyBlue)
        .contentTransition(.identity)
    }
    .padding(.horizontal, 16).padding(.vertical, 8)
    .retroPanel()
    .accessibilityElement(children: .combine)
  }

  /// One tip at a time: coaching on the first race, otherwise track warnings.
  private var coachChip: some View {
    let offRoad = game.race.offRoad && game.phase == .racing && game.race.elapsed > 1
    let text = offRoad ? "OFF TRACK!  BACK TO THE ROAD" : game.hint
    return ZStack {
      if !text.isEmpty {
        Text(text).font(pixel(7)).foregroundStyle(offRoad ? paper : ink)
          .padding(.horizontal, 12).padding(.vertical, 9)
          .background {
            ZStack {
              Rectangle().fill(offRoad ? cherry : coin)
              Rectangle().strokeBorder(ink, lineWidth: 2)
            }
          }
          .background { Rectangle().fill(ink).offset(x: 3, y: 3) }
          .id(text)
          .transition(.scale(scale: 1.2))
          .accessibilityIdentifier("coachHint")
      }
    }
    .frame(maxWidth: 300, minHeight: 40)
    .padding(.bottom, 6)
    .animation(reduceMotion ? nil : .linear(duration: 0.08), value: text.isEmpty)
  }

  /// Left and right halves share one pad so the thumb can slide between them; speed lives in the seam.
  private var steeringPad: some View {
    let steering = game.race.steering
    let segments = Int((game.race.player.speed / 26) * 8)
    let boosting = game.race.player.boost > 0
    return HStack(spacing: 0) {
      steeringHalf(held: steering < 0, icon: Sprites.arrowLeft)
      VStack(spacing: 2) {
        ForEach((0..<8).reversed(), id: \.self) { index in
          Rectangle()
            .fill(
              index < segments
                ? (boosting ? coin : (index < 5 ? leaf : (index < 7 ? coin : cherry)))
                : ink.opacity(0.4)
            )
            .frame(width: 14, height: 7)
        }
      }
      .frame(width: 28, height: 84)
      .background(navy)
      steeringHalf(held: steering > 0, icon: Sprites.arrowRight)
    }
    .overlay { Rectangle().strokeBorder(ink, lineWidth: 3) }
    .background { Rectangle().fill(ink).offset(y: 5) }
    .frame(width: padWidth)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in game.steer(value.location.x < padWidth / 2 ? -1 : 1) }
        .onEnded { _ in game.steer(0) }
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Steering pad, speed \(Int(game.race.player.speed * 3.6)) km/h")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Steer left") {
      game.steer(-1)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { game.steer(0) }
    }
    .accessibilityAction(named: "Steer right") {
      game.steer(1)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { game.steer(0) }
    }
  }

  private func steeringHalf(held: Bool, icon: [String]) -> some View {
    PixelArt(rows: icon)
      .frame(width: 40, height: 40)
      .frame(width: 84, height: 84)
      .background {
        ZStack {
          Rectangle().fill(held ? coin : royal)
          VStack(spacing: 0) {
            Rectangle().fill(.white.opacity(held ? 0.2 : 0.45)).frame(height: 5)
            Spacer()
            Rectangle().fill(.black.opacity(0.3)).frame(height: held ? 3 : 7)
          }.padding(3)
        }
      }
      .animation(nil, value: held)
  }

  private var itemButton: some View {
    let has = game.race.hasItem
    return Button(action: game.item) {
      VStack(spacing: 6) {
        PixelArt(rows: Sprites.lemonade).frame(width: 30, height: 36)
          .opacity(has ? 1 : 0.25)
        Text(has ? "LEMONADE" : "FIND ONE").font(pixel(6))
      }
      .frame(width: 84, height: 84)
      .foregroundStyle(has ? ink : paper.opacity(0.7))
    }
    .buttonStyle(ControlPadStyle(fill: has ? leaf : navy.opacity(0.7), active: has, dashed: !has))
    .disabled(!has)
    .accessibilityLabel(has ? "Use lemonade boost" : "No item yet, drive through a lemonade glass")
    .accessibilityIdentifier("useItem")
  }

  private var driftButton: some View {
    let drifting = game.race.drifting
    let charge = min(1, game.race.player.driftCharge / 0.65)
    return Button(action: game.drift) {
      VStack(spacing: 5) {
        PixelArt(rows: Sprites.bolt).frame(width: 26, height: 36)
        HStack(spacing: 2) {
          ForEach(0..<6, id: \.self) { index in
            Rectangle()
              .fill(
                Double(index) < charge * 6 - 0.01 ? (ready ? coin : skyBlue) : ink.opacity(0.35)
              )
              .frame(width: 9, height: 6)
          }
        }
        if ready {
          Blink(period: 0.25, animated: !reduceMotion) { Text("BOOST!").font(pixel(7)) }
        } else {
          Text(drifting ? "CHARGING" : "DRIFT").font(pixel(7))
        }
      }
      .frame(width: 100, height: 92)
      .foregroundStyle(ready ? ink : paper)
    }
    .buttonStyle(ControlPadStyle(fill: ready ? coin : (drifting ? royal : cherry), active: true))
    .accessibilityLabel(drifting ? "Release drift boost" : "Start drift")
    .accessibilityIdentifier("drift")
  }

  // MARK: Guide

  private func guide(_ size: CGSize) -> some View {
    ZStack {
      ink.opacity(0.7).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            RetroText("HOW TO PLAY", 16, coin).hardShadow(cherryDeep, 3)
            Text("YOUR KART ACCELERATES ON ITS OWN. YOU DO THE FUN PART.").font(pixel(6))
              .foregroundStyle(skyBlue)
          }
          Spacer()
          Button {
            game.showGuide = false
          } label: {
            Text("X").font(pixel(12)).foregroundStyle(paper)
          }
          .buttonStyle(RetroIconButtonStyle(fill: cherry))
          .accessibilityLabel("Close instructions")
        }
        HStack(alignment: .top, spacing: 10) {
          step(1, "STEER", "HOLD LEFT OR RIGHT ON THE PAD. HUG THE INSIDE OF EACH BEND.") {
            HStack(spacing: 2) {
              guideKey(Sprites.arrowLeft, royal)
              Rectangle().fill(navy).frame(width: 10, height: 34)
              guideKey(Sprites.arrowRight, royal)
            }
            .overlay { Rectangle().strokeBorder(ink, lineWidth: 2) }
          }
          step(2, "DRIFT & BOOST", "TAP DRIFT IN A BEND, KEEP TURNING, TAP AGAIN WHEN IT FLASHES.")
          {
            guideKey(Sprites.bolt, cherry)
          }
          step(3, "LEMONADE", "DRIVE THROUGH A GLASS ON THE ROAD, THEN TAP IT FOR A BIG BURST.") {
            guideKey(Sprites.lemonade, leaf)
          }
        }
        Button(game.learnedControls ? "GOT IT" : "GOT IT! LET'S RACE", action: game.start)
          .buttonStyle(RetroButtonStyle(height: 46, size: 10))
          .accessibilityIdentifier("confirmGuide")
      }
      .padding(18).frame(maxWidth: min(size.width - 40, 700))
      .retroPanel()
    }
  }

  private func guideKey(_ icon: [String], _ fill: Color) -> some View {
    PixelArt(rows: icon).frame(width: 20, height: 22)
      .frame(width: 40, height: 34)
      .background {
        ZStack {
          Rectangle().fill(fill)
          Rectangle().strokeBorder(ink, lineWidth: 2)
        }
      }
  }

  private func step<Visual: View>(
    _ number: Int, _ title: String, _ text: String, @ViewBuilder visual: () -> Visual
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text("\(number)").font(pixel(9)).foregroundStyle(ink)
          .frame(width: 22, height: 22).background(coin)
          .overlay { Rectangle().strokeBorder(ink, lineWidth: 2) }
        Text(title).font(pixel(8)).foregroundStyle(coin)
        Spacer(minLength: 0)
        visual()
      }
      Text(text).font(pixel(6)).lineSpacing(5).foregroundStyle(paper)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      Rectangle().fill(navyLight).overlay { Rectangle().strokeBorder(ink, lineWidth: 2) }
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: Pause

  private var pausePanel: some View {
    ZStack {
      ink.opacity(0.6).ignoresSafeArea()
      VStack(spacing: 12) {
        Blink(animated: !reduceMotion) { RetroText("PAUSED", 24, coin).hardShadow(cherryDeep, 4) }
        HStack(spacing: 16) {
          pauseStat("TIME", raceTime(game.race.elapsed))
          pauseStat("LAP", "\(min(3, game.race.player.tracker.laps + 1))/3")
          if game.mode == .picnic { pauseStat("PLACE", ordinal(game.race.position)) }
        }
        Button("CONTINUE", action: game.resume).buttonStyle(RetroButtonStyle(height: 46, size: 10))
          .accessibilityIdentifier("resumeRace")
        HStack(spacing: 8) {
          Button("RESTART", action: game.start)
          Button("QUIT", action: game.home)
          Button(action: game.toggleSound) {
            PixelArt(rows: game.sound ? Sprites.speaker : Sprites.muted).frame(
              width: 22, height: 22)
          }
          .buttonStyle(RetroIconButtonStyle(fill: royal))
          .accessibilityLabel(game.sound ? "Mute sound" : "Enable sound")
        }
        .buttonStyle(RetroButtonStyle(fill: royal, text: paper, height: 38, size: 8))
      }
      .padding(20)
      .frame(width: 340)
      .retroPanel()
    }
  }

  private func pauseStat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 4) {
      Text(label).font(pixel(6)).foregroundStyle(skyBlue)
      Text(value).font(pixel(8)).foregroundStyle(paper)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: Results

  private func results(_ size: CGSize) -> some View {
    let trial = game.mode == .trial
    let won = !trial && game.race.position == 1
    let personal = trial ? game.bestTrial : game.bestCup
    let newBest = abs(personal - game.race.elapsed) < 0.001
    let compact = size.height < 400
    return ZStack {
      LinearGradient(
        colors: [ink.opacity(0.7), ink.opacity(0.35), ink.opacity(0.7)], startPoint: .top,
        endPoint: .bottom
      ).ignoresSafeArea()
      if (won || newBest) && !reduceMotion {
        Confetti().ignoresSafeArea().allowsHitTesting(false)
      }
      HStack(alignment: .center, spacing: compact ? 20 : 28) {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
          Text((trial ? "TIME TRIAL" : "PICNIC CUP") + "  ·  STRAWBERRY CIRCUIT").font(pixel(6))
            .foregroundStyle(paper).padding(.horizontal, 8).padding(.vertical, 5)
            .background(navy).overlay { Rectangle().strokeBorder(ink, lineWidth: 2) }
          WaveText(
            text: won ? "YOU WIN!" : "FINISH!", size: compact ? 30 : 36, color: coin,
            animated: !reduceMotion)
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if trial {
              RetroText(raceTime(game.race.elapsed), 20, paper).hardShadow(cherryDeep, 3)
            } else {
              RetroText("\(game.race.position)", 40, paper).hardShadow(cherryDeep, 4)
              RetroText(String(ordinal(game.race.position).dropFirst()), 13, paper)
              RetroText("PLACE", 10, coin).padding(.leading, 6)
            }
          }
          recordLine(newBest: newBest, personal: personal)
          HStack(spacing: 8) {
            resultChip(Sprites.bolt, "\(game.race.driftBoosts) DRIFTS")
            resultChip(Sprites.lemonade, "\(game.race.itemsCollected) DRINKS")
            if !trial { resultChip(Sprites.flag, "\(game.race.overtakes) PASSES") }
          }
          HStack(spacing: 8) {
            Button("RACE AGAIN", action: game.start)
              .buttonStyle(RetroButtonStyle(height: 46, size: 11))
              .accessibilityIdentifier("raceAgain")
            Button("MENU", action: game.home)
              .buttonStyle(RetroButtonStyle(fill: royal, text: paper, height: 46, size: 8))
              .frame(width: 96)
              .accessibilityLabel("Back to title")
          }.padding(.top, 2)
        }.frame(maxWidth: 320, alignment: .leading)
        VStack(spacing: 10) {
          if trial { lapSplits } else { podium }
          if !trial {
            lapSplits
          }
        }.frame(maxWidth: 300)
      }.padding(.horizontal, 24).padding(.vertical, 16)
    }
  }

  private func recordLine(newBest: Bool, personal: Double) -> some View {
    HStack(spacing: 8) {
      if newBest {
        Blink(animated: !reduceMotion) { Text("NEW RECORD!").font(pixel(8)).foregroundStyle(coin) }
        if game.improvement > 0 {
          Text(String(format: "-%.2f", game.improvement)).font(pixel(8)).foregroundStyle(leaf)
        }
      } else {
        Text("YOUR RECORD  \(raceTime(personal))").font(pixel(7)).foregroundStyle(paper)
        Text(String(format: "+%.2f", game.race.elapsed - personal)).font(pixel(7))
          .foregroundStyle(cherry)
      }
    }
    .outlined(ink, 1.5)
    .accessibilityElement(children: .combine)
  }

  private var lapSplits: some View {
    let times = game.race.player.lapTimes
    let fastest = times.min() ?? 0
    return VStack(spacing: 7) {
      ForEach(times.indices, id: \.self) { index in
        let best = times[index] == fastest
        HStack {
          Text("LAP \(index + 1)").font(pixel(7)).foregroundStyle(best ? coin : paper)
          if best {
            Text("BEST").font(pixel(5)).foregroundStyle(ink).padding(.horizontal, 4)
              .padding(.vertical, 2).background(coin)
          }
          Spacer()
          Text(raceTime(times[index])).font(pixel(8)).foregroundStyle(best ? coin : paper)
        }
      }
      Rectangle().fill(paper.opacity(0.3)).frame(height: 2)
      HStack {
        Text("TOTAL").font(pixel(7)).foregroundStyle(skyBlue)
        Spacer()
        Text(raceTime(game.race.elapsed)).font(pixel(9)).foregroundStyle(paper)
      }
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
    .retroPanel()
    .accessibilityElement(children: .combine)
  }

  private func resultChip(_ icon: [String], _ text: String) -> some View {
    HStack(spacing: 6) {
      PixelArt(rows: icon).frame(width: 14, height: 16)
      Text(text).font(pixel(6))
    }
    .foregroundStyle(paper)
    .padding(.horizontal, 8).padding(.vertical, 7)
    .background {
      Rectangle().fill(navyLight).overlay { Rectangle().strokeBorder(ink, lineWidth: 2) }
    }
    .accessibilityElement(children: .combine)
  }

  private var podium: some View {
    let sorted = game.race.standings
    return VStack(spacing: 6) {
      HStack(alignment: .bottom, spacing: 6) {
        ForEach([1, 0, 2], id: \.self) { rank in
          let driver = sorted[rank]
          let height: CGFloat = rank == 0 ? 50 : (rank == 1 ? 38 : 30)
          VStack(spacing: 4) {
            PixelArt(rows: Sprites.animals[driver]).frame(width: 32, height: 32)
            Text(driverNames[driver] + (driver == 0 ? "★" : "")).font(pixel(6))
              .foregroundStyle(driver == 0 ? coin : paper)
            ZStack(alignment: .top) {
              Rectangle().fill(
                rank == 0
                  ? coin : (rank == 1 ? Color(red: 0.75, green: 0.76, blue: 0.82) : coinDeep)
              )
              .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.5)).frame(height: 4) }
              .overlay { Rectangle().strokeBorder(ink, lineWidth: 3) }
              Text("\(rank + 1)").font(pixel(rank == 0 ? 16 : 12))
                .foregroundStyle(ink).padding(.top, rank == 0 ? 9 : 7)
            }
            .frame(maxWidth: .infinity).frame(height: height)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(
            "\(rank + 1). \(driverNames[driver].capitalized)\(driver == 0 ? ", you" : "")")
        }
      }
      if sorted.count > 3 {
        let last = sorted[3]
        Text("4TH  \(driverNames[last])" + (last == 0 ? "★" : "")).font(pixel(6))
          .foregroundStyle(last == 0 ? coin : paper.opacity(0.7))
      }
    }
  }
}

/// Square control pad with the same bevel language as the menu buttons. Dashed when it is an empty slot.
struct ControlPadStyle: ButtonStyle {
  var fill: Color
  var active: Bool
  var dashed = false
  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed && active
    return configuration.label
      .background {
        ZStack {
          Rectangle().fill(fill)
          if !dashed {
            VStack(spacing: 0) {
              Rectangle().fill(.white.opacity(0.45)).frame(height: 5)
              Spacer()
              Rectangle().fill(.black.opacity(0.3)).frame(height: 7)
            }.padding(3)
          }
          if dashed {
            Rectangle().strokeBorder(
              style: StrokeStyle(lineWidth: 3, dash: [8, 6])
            ).foregroundStyle(paper.opacity(0.5))
          } else {
            Rectangle().strokeBorder(ink, lineWidth: 3)
          }
        }
      }
      .background { Rectangle().fill(ink).offset(y: dashed ? 0 : (pressed ? 0 : 5)) }
      .offset(y: pressed ? 5 : 0)
      .animation(nil, value: pressed)
  }
}

/// Square confetti that falls in quantised steps at twelve frames a second.
struct Confetti: View {
  private let start = Date()
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1.0 / 12)) { timeline in
      let t = floor(timeline.date.timeIntervalSince(start) * 12) / 12
      Canvas { context, size in
        let colors = [coin, cherry, paper, royal, leaf]
        for i in 0..<40 {
          let seed = Double(i)
          let speed = 60 + (seed * 37).truncatingRemainder(dividingBy: 50)
          let x =
            (seed * 97.3).truncatingRemainder(dividingBy: size.width)
            + (Int(t * 4 + seed) % 2 == 0 ? 0 : 6)
          let y = (t * speed + seed * 61).truncatingRemainder(dividingBy: size.height + 40) - 20
          let fade = max(0, 1 - t / 8)
          var piece = context
          piece.opacity = fade
          let side: CGFloat = i % 3 == 0 ? 8 : 6
          piece.fill(
            Path(CGRect(x: x, y: y, width: side, height: side)),
            with: .color(colors[i % colors.count]))
        }
      }
    }
  }
}

struct MiniMap: View {
  let circuit: Circuit
  let drivers: [Driver]
  var onCard: Bool
  var body: some View {
    Canvas { context, size in
      func point(_ p: Point) -> CGPoint {
        CGPoint(x: (p.x + 68) / 136 * size.width, y: (p.z + 50) / 100 * size.height)
      }
      var path = Path()
      path.addLines(circuit.points.map(point))
      path.closeSubpath()
      context.stroke(path, with: .color(ink), lineWidth: 8)
      context.stroke(path, with: .color(paper), lineWidth: 3.5)
      let start = point(circuit.points[0])
      context.fill(
        Path(CGRect(x: start.x - 2, y: start.y - 5, width: 4, height: 10)), with: .color(coin))
      let colors = [cherry, royal, leaf, coin]
      for index in drivers.indices.reversed() {
        let p = point(drivers[index].point)
        let half: CGFloat = index == 0 ? 5 : 3.5
        let rect = CGRect(x: p.x - half, y: p.y - half, width: half * 2, height: half * 2)
        context.fill(Path(rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(index == 0 ? paper : ink))
        context.fill(Path(rect), with: .color(colors[index]))
      }
    }.accessibilityLabel("Circuit map")
  }
}

struct NativeScene: UIViewRepresentable {
  let game: GameController
  func makeUIView(context: Context) -> KeyboardSceneView {
    let view = KeyboardSceneView()
    view.scene = game.world.scene
    view.pointOfView = game.world.camera
    #if targetEnvironment(simulator)
      view.antialiasingMode = .multisampling2X
    #else
      view.antialiasingMode = .multisampling4X
    #endif
    view.preferredFramesPerSecond = 60
    view.isPlaying = true
    view.game = game
    view.becomeFirstResponder()
    return view
  }
  func updateUIView(_ uiView: KeyboardSceneView, context: Context) {}
}

final class KeyboardSceneView: SCNView {
  weak var game: GameController?
  override var canBecomeFirstResponder: Bool { true }
  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    for press in presses {
      switch press.key?.keyCode {
      case .keyboardLeftArrow: game?.steer(-1)
      case .keyboardRightArrow: game?.steer(1)
      case .keyboardSpacebar: game?.drift()
      case .keyboardB: game?.item()
      case .keyboardP:
        if game?.phase == .paused { game?.resume() } else { game?.pause() }
      default: super.pressesBegan(presses, with: event)
      }
    }
  }
  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    for press in presses {
      if press.key?.keyCode == .keyboardLeftArrow || press.key?.keyCode == .keyboardRightArrow {
        game?.steer(0)
      }
    }
    super.pressesEnded(presses, with: event)
  }
}
