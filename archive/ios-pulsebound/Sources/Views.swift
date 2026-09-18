import SpriteKit
import SwiftUI

enum Palette {
  static let background = Color(red: 0.035, green: 0.025, blue: 0.075)
  static let deep = Color(red: 0.065, green: 0.045, blue: 0.13)
  static let panel = Color(red: 0.095, green: 0.07, blue: 0.18)
  static let violet = Color(red: 0.62, green: 0.42, blue: 1)
  static let coral = Color(red: 1, green: 0.36, blue: 0.43)
  static let ember = Color(red: 1, green: 0.6, blue: 0.4)
  static let cyan = Color(red: 0.35, green: 0.95, blue: 0.94)
  static let muted = Color(red: 0.6, green: 0.56, blue: 0.72)
  static let white = Color(red: 0.97, green: 0.96, blue: 1)

  static func accent(_ stage: Int) -> Color {
    [cyan, violet, coral][stage % 3]
  }

  static let ignite = LinearGradient(
    colors: [coral, ember], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct RootView: View {
  @ObservedObject var model: GameModel
  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      if model.screenIsGame {
        PlayView(model: model)
      } else {
        HomeView(model: model)
      }
    }
    .foregroundStyle(Palette.white)
  }
}

struct HomeView: View {
  @ObservedObject var model: GameModel
  private var accent: Color { Palette.accent(model.selection) }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        PulseMark(size: 26)
        Text("PULSEBOUND").font(.system(size: 13, weight: .heavy)).tracking(4.5)
        Spacer()
        SoundButton(model: model)
      }
      .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 14)

      ScrollView(showsIndicators: false) {
        VStack(spacing: 20) {
          HeroPanel(accent: accent)

          VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
              Text("Tracks").font(.system(size: 21, weight: .bold, design: .rounded))
              Spacer()
              Text("\(model.clears.filter { $0 }.count) / 3 CLEARED")
                .font(.system(size: 10, weight: .bold)).tracking(1.4)
                .foregroundStyle(Palette.muted)
            }.padding(.bottom, 4)
            ForEach(Stage.all) { stage in
              StageCard(stage: stage, model: model)
            }
          }
        }
        .padding(.horizontal, 22).padding(.bottom, 20)
      }

      VStack(spacing: 12) {
        HStack(spacing: 4) {
          modeButton("Normal", detail: "One clean run", icon: "bolt.fill", practice: false)
          modeButton(
            "Practice", detail: "Checkpoints on", icon: "flag.checkered", practice: true)
        }
        .padding(4)
        .background(Palette.deep, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07)))
        PrimaryButton(
          title: "Play \(model.stage.title)", icon: "arrow.up.right",
          action: model.enter)
        HStack(spacing: 14) {
          hint("hand.tap.fill", "Tap to jump")
          hint("metronome.fill", "Ride the beat")
          hint("flag.checkered", "Reach the gate")
        }
      }
      .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 4)
      .background(
        LinearGradient(
          colors: [Palette.background.opacity(0), Palette.background], startPoint: .top,
          endPoint: UnitPoint(x: 0.5, y: 0.22)
        )
        .padding(.top, -28)
      )
    }
  }

  private func hint(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon).font(.system(size: 9, weight: .semibold))
      Text(text).font(.system(size: 10, weight: .medium))
    }
    .foregroundStyle(Palette.muted)
  }

  private func modeButton(_ title: String, detail: String, icon: String, practice: Bool)
    -> some View
  {
    let on = model.practice == practice
    return Button {
      withAnimation(.spring(duration: 0.3)) { model.practice = practice }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(on ? accent : Palette.muted)
          .frame(width: 30, height: 30)
          .background(
            (on ? accent : Palette.muted).opacity(on ? 0.16 : 0.08), in: Circle())
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(on ? Palette.white : Palette.muted)
          Text(detail).font(.system(size: 10, weight: .medium))
            .foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 54)
      .background(on ? Palette.panel : .clear, in: RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(on ? accent.opacity(0.45) : .clear, lineWidth: 1)
      )
    }.buttonStyle(.plain).accessibilityIdentifier(practice ? "mode.practice" : "mode.normal")
      .accessibilityAddTraits(on ? .isSelected : [])
  }
}

struct HeroPanel: View {
  let accent: Color
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 30)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.2, green: 0.11, blue: 0.4), Palette.deep, Palette.background,
            ], startPoint: .topTrailing, endPoint: .bottomLeading))
      TimelineView(.animation(paused: reduceMotion)) { timeline in
        PulseSculpture(
          time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate, accent: accent)
      }
      .frame(width: 184, height: 184)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0), .init(color: .white, location: 0.42),
            .init(color: .white, location: 1),
          ], startPoint: .leading, endPoint: .trailing)
      )
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.trailing, -34)
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 12) {
        Eyebrow(text: "ONE TOUCH · PURE FLOW", color: Palette.coral)
        Text("Find your\nfrequency.")
          .font(.system(size: 36, weight: .heavy, design: .rounded))
          .tracking(-1.6).lineSpacing(-5)
          .foregroundStyle(
            LinearGradient(
              colors: [Palette.white, Palette.white.opacity(0.72)], startPoint: .top,
              endPoint: .bottom))
        Text("Three tracks. One perfect run.")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Palette.muted)
      }
      .padding(.leading, 24)
    }
    .frame(height: 192)
    .clipShape(RoundedRectangle(cornerRadius: 30))
    .overlay(
      RoundedRectangle(cornerRadius: 30)
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.16), .white.opacity(0.02)], startPoint: .top,
            endPoint: .bottom), lineWidth: 1)
    )
  }
}

struct PulseSculpture: View {
  let time: Double
  let accent: Color

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let beat = time * 2
      let pulse = pow(1 - beat.truncatingRemainder(dividingBy: 1), 3)
      for index in 0..<48 {
        let angle = Double(index) / 48 * .pi * 2 - .pi / 2
        let wave = 0.5 + 0.5 * sin(time * 2.4 + Double(index) * 0.55)
        let inner = 58.0
        let length = 6 + 22 * wave + 6 * pulse
        var tick = Path()
        tick.move(
          to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
        tick.addLine(
          to: CGPoint(
            x: center.x + cos(angle) * (inner + length),
            y: center.y + sin(angle) * (inner + length)))
        let mix = 0.5 + 0.5 * sin(angle)
        context.stroke(
          tick,
          with: .color(
            mix > 0.5 ? Palette.coral.opacity(0.35 + wave * 0.5) : accent.opacity(0.3 + wave * 0.55)
          ),
          style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
      }
      for index in 0..<3 {
        let radius = 30.0 + Double(index) * 11 + pulse * 4
        context.stroke(
          diamond(center, radius),
          with: .color(accent.opacity(index == 0 ? 0.9 : 0.22 - Double(index) * 0.05)),
          lineWidth: index == 0 ? 2.5 : 1)
      }
      let core = Path(
        roundedRect: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24),
        cornerRadius: 6)
      context.fill(core, with: .color(accent))
      context.fill(
        Path(
          roundedRect: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9),
          cornerRadius: 2), with: .color(Palette.background))
    }
  }

  private func diamond(_ center: CGPoint, _ radius: Double) -> Path {
    var shape = Path()
    shape.move(to: CGPoint(x: center.x, y: center.y - radius))
    shape.addLine(to: CGPoint(x: center.x + radius, y: center.y))
    shape.addLine(to: CGPoint(x: center.x, y: center.y + radius))
    shape.addLine(to: CGPoint(x: center.x - radius, y: center.y))
    shape.closeSubpath()
    return shape
  }
}

struct PulseMark: View {
  let size: CGFloat
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.3).fill(Palette.ignite)
      HStack(spacing: size * 0.09) {
        ForEach(0..<5, id: \.self) { index in
          Capsule().fill(Palette.background)
            .frame(width: size * 0.09, height: size * [0.28, 0.5, 0.68, 0.42, 0.24][index])
        }
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

struct StageSignature: View {
  let stage: Stage
  var accent: Color
  var progress = 100.0
  var playhead = false
  var checkpoints = false

  var body: some View {
    Canvas { context, size in
      let gap = 1.5
      let beats = max(1, min(Int(stage.beats), Int((size.width + gap) / (2 + gap))))
      var counts = [Int](repeating: 0, count: beats)
      for obstacle in stage.obstacles {
        let beat = Int(obstacle.x / stage.length * Double(beats))
        if beat < beats { counts[beat] += 1 }
      }
      let width = (size.width - gap * Double(beats - 1)) / Double(beats)
      let lit = progress / 100 * Double(beats)
      for beat in 0..<beats {
        let level = min(3, counts[beat])
        let height = level == 0 ? 2.5 : size.height * (0.4 + 0.6 * Double(level) / 3)
        let x = Double(beat) * (width + gap)
        let rect = CGRect(x: x, y: (size.height - height) / 2, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: width / 2)
        let on = Double(beat) < lit
        let color =
          level == 0
          ? Color.white.opacity(on ? 0.35 : 0.1)
          : (on ? accent.opacity(0.75 + 0.25 * Double(level) / 3) : Color.white.opacity(0.14))
        context.fill(path, with: .color(color))
      }
      if checkpoints {
        for marker in stage.checkpoints {
          let x = marker / stage.length * size.width
          context.fill(
            Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
            with: .color(Palette.cyan.opacity(0.5)))
        }
      }
      if playhead {
        let x = min(progress, 100) / 100 * size.width
        var line = Path(
          roundedRect: CGRect(x: x - 1, y: -2, width: 2, height: size.height + 4),
          cornerRadius: 1)
        context.fill(line, with: .color(Palette.white))
        line = Path(ellipseIn: CGRect(x: x - 3, y: -5, width: 6, height: 6))
        context.fill(line, with: .color(Palette.white))
      }
    }
    .accessibilityHidden(true)
  }
}

struct StageCard: View {
  let stage: Stage
  @ObservedObject var model: GameModel
  var selected: Bool { model.selection == stage.id }
  private var accent: Color { Palette.accent(stage.id) }

  var body: some View {
    Button {
      withAnimation(.spring(duration: 0.3)) { model.selection = stage.id }
    } label: {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 14)
            .fill(accent.opacity(selected ? 0.16 : 0.07))
          StageSignature(stage: stage, accent: selected ? accent : Palette.muted)
            .padding(.horizontal, 9).padding(.vertical, 10)
        }.frame(width: 70, height: 54)
        VStack(alignment: .leading, spacing: 7) {
          HStack(spacing: 6) {
            Text(stage.title).font(.system(size: 17, weight: .bold, design: .rounded))
            if model.clears[stage.id] {
              Image(systemName: "checkmark.seal.fill").font(.system(size: 12))
                .foregroundStyle(Palette.cyan)
            }
          }
          Text(
            "\(["INTRO", "FLOW", "EXPERT"][stage.id])  ·  \(Int(stage.bpm)) BPM  ·  \(stage.duration) SEC"
          )
          .font(.system(size: 10, weight: .semibold)).tracking(0.6)
          .lineLimit(1).minimumScaleFactor(0.8)
          .foregroundStyle(selected ? accent : Palette.muted)
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.07))
              Capsule().fill(accent)
                .frame(width: geometry.size.width * model.bests[stage.id] / 100)
            }
          }.frame(height: 3)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 3) {
          Text("\(Int(model.bests[stage.id]))")
            .font(.system(size: 24, weight: .light, design: .rounded))
            + Text("%").font(.system(size: 12, weight: .medium)).foregroundColor(Palette.muted)
          Text("BEST").font(.system(size: 9, weight: .bold)).tracking(1.4)
            .foregroundStyle(Palette.muted)
        }
      }
      .padding(14)
      .background(
        LinearGradient(
          colors: selected
            ? [accent.opacity(0.14), Palette.panel] : [Palette.panel, Palette.deep],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22))
      .overlay(
        RoundedRectangle(cornerRadius: 22)
          .stroke(selected ? accent.opacity(0.6) : .white.opacity(0.07), lineWidth: 1)
      )
      .shadow(color: selected ? accent.opacity(0.18) : .clear, radius: 18, y: 8)
    }.buttonStyle(.plain).accessibilityIdentifier("stage.\(stage.id)")
      .accessibilityLabel("\(stage.title), \(Int(model.bests[stage.id])) percent best")
  }
}

struct PlayView: View {
  @ObservedObject var model: GameModel
  @State private var scene: GameScene?
  @State private var padPressed = false
  private var overlayPresented: Bool {
    model.resultReady || (model.engine.phase == .paused && model.resumeCount == 0)
  }
  private var accent: Color { Palette.accent(model.selection) }
  private var ready: Bool { model.engine.phase == .ready }

  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        if !overlayPresented {
          HStack {
            IconButton(icon: "arrow.left", label: "Back to tracks", action: model.home)
            Spacer()
            VStack(spacing: 4) {
              Text(model.stage.title).font(.system(size: 16, weight: .bold, design: .rounded))
              Eyebrow(
                text: "\(model.practice ? "PRACTICE" : "NORMAL") · \(Int(model.stage.bpm)) BPM",
                color: accent)
            }
            Spacer()
            IconButton(icon: "pause.fill", label: "Pause") { model.pause() }
              .disabled(model.engine.phase != .running)
          }
          .padding(.horizontal, 20)
        }
        VStack(spacing: 10) {
          HStack(alignment: .lastTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
              Text("\(Int(model.engine.progress))")
                .font(.system(size: 44, weight: .light, design: .rounded)).tracking(-1.5)
                .contentTransition(.numericText())
              Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
              Text("\(model.practice ? "PRACTICE" : "LOCAL") BEST  \(Int(model.best))%")
              Text(String(format: "ATTEMPT %02d", max(1, model.attempts)))
            }
            .font(.system(size: 10, weight: .bold)).tracking(1.2)
            .foregroundStyle(Palette.muted)
          }
          StageSignature(
            stage: model.stage, accent: accent, progress: model.engine.progress, playhead: true,
            checkpoints: model.practice
          ).frame(height: 30)
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)

        ZStack {
          if let scene {
            GameCanvas(scene: scene)
              .background(Palette.background)
          }
          VStack {
            LinearGradient(
              colors: [Palette.background, Palette.background.opacity(0)], startPoint: .top,
              endPoint: .bottom
            ).frame(height: 46)
            Spacer()
          }.allowsHitTesting(false)
          if ready {
            VStack(spacing: 14) {
              Image(systemName: "hand.tap.fill")
                .font(.system(size: 22, weight: .medium)).foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(accent.opacity(0.14), in: Circle())
              Text("The first beat is yours.")
                .font(.system(size: 21, weight: .bold, design: .rounded)).tracking(-0.4)
              Text(
                "Tap below to start, tap again to jump.\nClear the coral spikes. Reach the gate."
              )
              .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
              .multilineTextAlignment(.center).lineSpacing(4)
            }
            .padding(.horizontal, 26).padding(.vertical, 24)
            .background(Palette.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 26))
            .overlay(
              RoundedRectangle(cornerRadius: 26)
                .stroke(
                  LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.03)], startPoint: .top,
                    endPoint: .bottom), lineWidth: 1)
            )
            .padding(.bottom, 70)
            .allowsHitTesting(false)
          }
          if model.checkpointNotice {
            Label("CHECKPOINT SAVED", systemImage: "flag.checkered")
              .font(.system(size: 11, weight: .bold)).tracking(1.2)
              .foregroundStyle(Palette.cyan).padding(.horizontal, 16).padding(.vertical, 11)
              .background(Palette.background.opacity(0.92), in: Capsule())
              .overlay(Capsule().stroke(Palette.cyan.opacity(0.45)))
              .frame(maxHeight: .infinity, alignment: .top).padding(.top, 18)
              .allowsHitTesting(false)
          }
          if model.resumeCount > 0 {
            VStack(spacing: 6) {
              Text("\(model.resumeCount)")
                .font(.system(size: 46, weight: .light, design: .rounded))
                .contentTransition(.numericText())
              Eyebrow(text: "FIND THE BEAT", color: accent)
            }
            .frame(width: 150, height: 104)
            .background(Palette.background.opacity(0.95), in: RoundedRectangle(cornerRadius: 24))
            .overlay(
              RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.55), lineWidth: 1)
            )
            .frame(maxHeight: .infinity, alignment: .top).padding(.top, 20)
            .allowsHitTesting(false)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        ZStack {
          VStack(spacing: 8) {
            HStack(spacing: 10) {
              Image(systemName: ready ? "play.fill" : "chevron.up")
                .font(.system(size: 15, weight: .heavy))
              Text(ready ? "LET’S GO" : "TAP TO JUMP").tracking(2.4)
            }.font(.system(size: 17, weight: .heavy, design: .rounded))
            Text(
              ready
                ? (model.practice
                  ? "Checkpoints save automatically." : "No checkpoints. Every beat counts.")
                : "Light touch. Perfect timing."
            )
            .font(.system(size: 11, weight: .medium))
            .opacity(0.78)
          }
          .frame(maxWidth: .infinity).frame(height: 108)
          .foregroundStyle(ready ? Palette.background : Palette.cyan)
          .background {
            if ready {
              RoundedRectangle(cornerRadius: 26).fill(Palette.ignite)
                .opacity(padPressed ? 0.85 : 1)
            } else {
              RoundedRectangle(cornerRadius: 26)
                .fill(
                  LinearGradient(
                    colors: [
                      Palette.cyan.opacity(padPressed ? 0.3 : 0.14),
                      Palette.cyan.opacity(padPressed ? 0.18 : 0.05),
                    ], startPoint: .top, endPoint: .bottom))
            }
          }
          .overlay(
            RoundedRectangle(cornerRadius: 26)
              .stroke(
                ready ? .white.opacity(0.35) : Palette.cyan.opacity(padPressed ? 0.9 : 0.5),
                lineWidth: 1.2)
          )
          .shadow(
            color: ready
              ? Palette.coral.opacity(0.4) : Palette.cyan.opacity(padPressed ? 0.35 : 0.1),
            radius: 22, y: 8
          )
          .animation(.easeOut(duration: 0.12), value: padPressed)
          .accessibilityHidden(true)
          if !overlayPresented {
            TouchPad(
              label: ready ? "Let's go" : "Tap to jump",
              value:
                "phase \(String(describing: model.engine.phase)), progress \(Int(model.engine.progress)), grounded \(model.engine.grounded), next \(Int(model.engine.nextHazardDistance ?? 9999))",
              action: model.tap, pressed: { padPressed = $0 }
            )
          }
        }
        .frame(height: 108)
        .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 22)
      }.padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityHidden(overlayPresented)

      if model.engine.phase == .paused && model.resumeCount == 0 { PauseOverlay(model: model) }
      if model.resultReady {
        ResultOverlay(model: model)
      }
    }
    .onAppear { scene = GameScene(model: model) }
    .onDisappear { scene = nil }
  }
}

struct PauseOverlay: View {
  @ObservedObject var model: GameModel
  private var accent: Color { Palette.accent(model.selection) }
  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      Backdrop(accent: accent)
      VStack(spacing: 26) {
        HStack {
          Eyebrow(
            text: "\(model.practice ? "PRACTICE" : "NORMAL") / \(model.stage.title.uppercased())")
          Spacer()
          SoundButton(model: model)
        }
        Spacer(minLength: 0)
        ProgressRing(value: model.engine.progress, size: 132, lineWidth: 5, accent: accent)
        VStack(spacing: 10) {
          Eyebrow(text: "TAKE A BREATH", color: accent)
          Text("Between beats.")
            .font(.system(size: 36, weight: .heavy, design: .rounded)).tracking(-1.2)
          Text("The beat waits for you. Resume with a three-count.")
            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 0)
        PrimaryButton(title: "Resume the flow", icon: "play.fill", action: model.resume)
        Button {
          model.retry()
        } label: {
          HStack {
            Text("Restart attempt").font(.system(size: 15, weight: .bold, design: .rounded))
            Spacer()
            Image(systemName: "arrow.counterclockwise").font(.system(size: 14, weight: .semibold))
          }
          .padding(.horizontal, 22).frame(height: 56)
          .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
          .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1)))
        }.buttonStyle(JumpButtonStyle())
        Button("Back to tracks", action: model.home).buttonStyle(SecondaryButtonStyle())
      }.padding(.horizontal, 26).padding(.vertical, 20)
    }
  }
}

struct ResultOverlay: View {
  @ObservedObject var model: GameModel
  private var cleared: Bool { model.engine.phase == .cleared }
  private var accent: Color { Palette.accent(model.selection) }
  private var personalBest: Bool {
    model.engine.progress > 0 && model.engine.progress >= model.best && model.attempts > 1
  }

  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      Backdrop(accent: cleared ? accent : Palette.coral)
      VStack(spacing: 22) {
        HStack {
          Eyebrow(
            text: "\(model.practice ? "PRACTICE" : "NORMAL") / \(model.stage.title.uppercased())")
          Spacer()
          SoundButton(model: model)
        }
        Spacer(minLength: 0)
        VStack(spacing: 10) {
          Eyebrow(
            text: cleared
              ? "FREQUENCY FOUND"
              : model.engine.progress >= 80 ? "SO CLOSE. GO AGAIN." : "FIND YOUR TIMING",
            color: cleared ? accent : Palette.coral)
          Text(cleared ? "Pure resonance." : "One more beat.")
            .font(.system(size: 36, weight: .heavy, design: .rounded)).tracking(-1.3)
        }
        ZStack(alignment: .bottom) {
          ProgressRing(
            value: model.engine.progress, size: 190, lineWidth: 8,
            accent: cleared ? accent : Palette.coral)
          if cleared || personalBest {
            Text(cleared ? "TRACK CLEARED" : "PERSONAL BEST")
              .font(.system(size: 9, weight: .heavy)).tracking(1.6)
              .foregroundStyle(Palette.background)
              .padding(.horizontal, 12).padding(.vertical, 7)
              .background(cleared ? accent : Palette.coral, in: Capsule())
              .offset(y: 12)
          }
        }
        .padding(.vertical, 6)
        Text(
          cleared
            ? (model.practice
              ? "Practice complete. Ready for a clean run?" : "Every jump. Every beat. All yours.")
            : model.engine.jumps == 0
              ? "Tap as a coral spike approaches your cube."
              : "Watch the next spike. Jump just before it reaches you."
        )
        .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.muted)
        .multilineTextAlignment(.center)
        HStack(spacing: 0) {
          stat("ATTEMPT", value: String(format: "%02d", model.attempts))
          divider
          stat(model.practice ? "PRACTICE BEST" : "LOCAL BEST", value: "\(Int(model.best))%")
          divider
          stat("JUMPS", value: "\(model.engine.jumps)")
        }
        .padding(.vertical, 18)
        .background(Palette.panel.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.07)))
        if model.practice {
          Label(
            model.engine.checkpoint > 0
              ? "Retry from \(Int(model.engine.checkpoint / model.stage.length * 100))% checkpoint"
              : "Reach a flag to save a checkpoint",
            systemImage: "flag.checkered"
          )
          .font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.cyan)
        }
        Spacer(minLength: 0)
        PrimaryButton(
          title: cleared ? "Play it again" : "Try again", icon: "arrow.clockwise",
          action: model.retry
        )
        .accessibilityIdentifier("retry")
        Button("Back to tracks", action: model.home).buttonStyle(SecondaryButtonStyle())
      }.padding(.horizontal, 26).padding(.vertical, 20)
    }
  }

  private var divider: some View {
    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 30)
  }

  private func stat(_ name: String, value: String) -> some View {
    VStack(spacing: 7) {
      Text(value).font(.system(size: 22, weight: .semibold, design: .rounded))
      Text(name).font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(Palette.muted)
    }.frame(maxWidth: .infinity)
  }
}

struct Backdrop: View {
  let accent: Color
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Circle().fill(accent.opacity(0.16))
          .frame(width: geometry.size.width * 1.1)
          .blur(radius: 90)
          .offset(y: -geometry.size.height * 0.2)
        Circle().fill(Palette.violet.opacity(0.1))
          .frame(width: geometry.size.width * 0.9)
          .blur(radius: 80)
          .offset(x: -geometry.size.width * 0.3, y: geometry.size.height * 0.35)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct ProgressRing: View {
  let value: Double
  let size: CGFloat
  let lineWidth: CGFloat
  var accent = Palette.cyan
  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.07), lineWidth: lineWidth)
      Circle().trim(from: 0, to: min(1, value / 100))
        .stroke(
          AngularGradient(
            colors: [accent, accent, Palette.coral, accent], center: .center,
            startAngle: .degrees(0), endAngle: .degrees(360)),
          style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: accent.opacity(0.45), radius: size / 9)
      Circle().stroke(.white.opacity(0.05), lineWidth: 1).padding(lineWidth + 7)
      VStack(spacing: size > 100 ? 4 : 2) {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
          Text("\(Int(value))")
            .font(
              .system(
                size: size > 150 ? 60 : size > 100 ? 42 : 23, weight: .light, design: .rounded)
            )
            .tracking(-1.5)
          Text("%").font(.system(size: size > 100 ? 18 : 10, weight: .light))
            .foregroundStyle(Palette.muted)
        }
        if size > 100 {
          Text("COMPLETED")
            .font(.system(size: 9, weight: .bold))
            .tracking(2).foregroundStyle(Palette.muted)
        }
      }
    }.frame(width: size, height: size).accessibilityLabel("\(Int(value)) percent completed")
  }
}

struct Eyebrow: View {
  let text: String
  var color = Palette.muted
  var body: some View {
    Text(text).font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(color)
  }
}

struct SoundButton: View {
  @ObservedObject var model: GameModel
  var body: some View {
    IconButton(
      icon: model.sound ? "speaker.wave.2.fill" : "speaker.slash.fill",
      label: model.sound ? "Mute sound" : "Enable sound"
    ) {
      model.sound.toggle()
    }.accessibilityIdentifier("sound")
  }
}

struct IconButton: View {
  let icon: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 14, weight: .semibold))
        .frame(width: 44, height: 44)
        .background(.white.opacity(0.05), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.08)))
    }.buttonStyle(.plain).accessibilityLabel(label)
  }
}

struct PrimaryButton: View {
  let title: String
  let icon: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
        Spacer()
        Image(systemName: icon).font(.system(size: 15, weight: .heavy))
          .frame(width: 32, height: 32)
          .background(Palette.background.opacity(0.16), in: Circle())
      }.padding(.leading, 24).padding(.trailing, 14).frame(height: 62)
        .foregroundStyle(Palette.background)
        .background(Palette.ignite, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(
              LinearGradient(
                colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top,
                endPoint: .bottom), lineWidth: 1)
        )
        .shadow(color: Palette.coral.opacity(0.42), radius: 20, y: 10)
    }.buttonStyle(JumpButtonStyle())
  }
}

struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Palette.muted).frame(maxWidth: .infinity, minHeight: 44)
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

struct JumpButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.975 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
