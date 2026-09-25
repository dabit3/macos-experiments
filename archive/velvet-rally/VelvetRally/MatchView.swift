import Combine
import SwiftUI

struct MatchView: View {
  @EnvironmentObject private var store: RallyStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var session: MatchSession
  @State private var confirmExit = false
  @State private var confirmReset = false
  private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

  init(settings: MatchSettings) {
    _session = StateObject(wrappedValue: MatchSession(settings: settings))
  }

  var body: some View {
    ZStack {
      Velvet.background.ignoresSafeArea()
      if session.engine.phase == .finished {
        result
      } else {
        VStack(spacing: 18) {
          HStack {
            Eyebrow(text: "Velvet Rally / \(session.engine.settings.court.title)")
            Spacer()
            CircleControl(icon: "pause.fill", label: "Pause match") { session.engine.pause() }
          }
          scoreboard
          GeometryReader { geometry in
            ZStack {
              PlayCourt(engine: session.engine)
              if session.engine.phase == .ready || session.engine.phase == .point {
                servePrompt
              }
            }
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { value in
                  session.engine.movePlayer(to: value.location.x / geometry.size.width)
                }
            )
            .accessibilityElement(children: .contain)
          }
          HStack {
            Image(systemName: "hand.draw").foregroundStyle(Velvet.orange)
            Text("Drag to move · Edge hits add angle")
              .font(.system(.caption, design: .rounded)).foregroundStyle(Velvet.muted)
          }.padding(.bottom, 4)
        }
        .padding(.horizontal, 24).padding(.top, 8)
        if session.engine.phase == .paused { pauseOverlay }
      }
    }
    .onReceive(timer) { date in
      session.advance(at: date.timeIntervalSinceReferenceDate, store: store)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { session.engine.pause() }
    }
    .confirmationDialog("Leave this match?", isPresented: $confirmExit, titleVisibility: .visible) {
      Button("Leave match", role: .destructive) { dismiss() }
    } message: {
      Text("This unfinished match won't be saved.")
    }
    .confirmationDialog(
      "Start again at 0–0?", isPresented: $confirmReset, titleVisibility: .visible
    ) {
      Button("Restart match", role: .destructive) { session.reset() }
    }
  }

  private var scoreboard: some View {
    VStack(spacing: 8) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 3) {
          Eyebrow(text: "You")
          Text("\(session.engine.playerScore)")
            .font(.system(size: 60, weight: .regular, design: .serif))
            .foregroundStyle(Velvet.cream)
          scorePips(session.engine.playerScore, color: Velvet.cream)
        }
        Spacer()
        VStack(spacing: 8) {
          Text("FIRST TO \(session.engine.target)")
            .font(.system(.caption, design: .monospaced)).tracking(1)
            .foregroundStyle(Velvet.muted)
          Text(
            session.engine.rally > 0
              ? "\(session.engine.rally) SHOT RALLY"
              : session.engine.phase == .playing ? "IN PLAY" : "YOUR SERVE"
          )
          .font(.system(.caption, design: .monospaced, weight: .medium))
          .foregroundStyle(Velvet.orange)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Eyebrow(text: session.engine.settings.difficulty.title)
          Text("\(session.engine.opponentScore)")
            .font(.system(size: 60, weight: .regular, design: .serif))
            .foregroundStyle(Velvet.muted)
          scorePips(session.engine.opponentScore, color: Velvet.orange)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "You \(session.engine.playerScore), opponent \(session.engine.opponentScore). First to \(session.engine.target). Rally \(session.engine.rally) shots."
      )
    }
  }

  private func scorePips(_ score: Int, color: Color) -> some View {
    HStack(spacing: 4) {
      ForEach(0..<session.engine.target, id: \.self) { point in
        Circle()
          .fill(point < score ? color : .clear)
          .overlay(Circle().stroke(color.opacity(point < score ? 1 : 0.55), lineWidth: 1))
          .frame(width: 7, height: 7)
      }
    }
    .accessibilityHidden(true)
  }

  private var servePrompt: some View {
    VStack(spacing: 10) {
      Text(
        session.engine.phase == .ready
          ? "Your serve."
          : session.engine.lastPointWasPlayer
            ? "Point to you." : "Point to \(session.engine.settings.difficulty.title)."
      )
      .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)
      .foregroundStyle(Velvet.cream)
      if session.engine.phase == .ready {
        Text("Move the cream paddle. Aim with its edges.\nSide rails keep the ball in play.")
          .font(.footnote).foregroundStyle(Velvet.muted)
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      } else {
        Text(session.engine.lastPointWasPlayer ? "Beautifully placed." : "Find your next opening.")
          .font(.footnote).foregroundStyle(Velvet.muted)
      }
      Button {
        session.engine.serve()
      } label: {
        HStack {
          Text(session.engine.phase == .ready ? "Serve the first ball" : "Serve again")
          Image(systemName: "arrow.up")
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Velvet.orange, in: Capsule())
        .foregroundStyle(Velvet.background)
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .frame(maxWidth: .infinity)
    .background(Velvet.background, in: RoundedRectangle(cornerRadius: 20))
    .padding(20)
  }

  private var pauseOverlay: some View {
    ZStack {
      Velvet.background.opacity(0.98).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 24) {
        Eyebrow(text: "Take a breather")
        Text("Time out.").font(.system(size: 58, design: .serif)).foregroundStyle(Velvet.cream)
        Text("The court will wait for you.")
          .font(.system(.body, design: .serif)).foregroundStyle(Velvet.muted)
        HStack {
          resultScore(session.engine.playerScore, label: "YOU")
          Spacer()
          resultScore(
            session.engine.opponentScore,
            label: session.engine.settings.difficulty.title.uppercased())
        }
        .foregroundStyle(Velvet.cream).padding(.vertical, 12)
        PrimaryButton(title: "Back to the rally", icon: "play.fill") { session.engine.resume() }
        Button("Restart match") { confirmReset = true }
          .font(.headline).foregroundStyle(Velvet.cream).frame(maxWidth: .infinity).padding(14)
        Button("Leave the court") { confirmExit = true }
          .font(.subheadline).foregroundStyle(Velvet.muted).frame(maxWidth: .infinity).padding(14)
      }.padding(32)
    }
    .accessibilityAddTraits(.isModal)
  }

  private var result: some View {
    let won = session.engine.playerScore > session.engine.opponentScore
    return ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Eyebrow(text: "Match / Complete")
          Spacer()
          CircleControl(icon: "xmark", label: "Return to club") { dismiss() }
        }
        Text(won ? "A touch\nof brilliance." : "The next one's\nyours.")
          .font(.system(size: 52, design: .serif)).foregroundStyle(Velvet.cream)
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 24).fill(Velvet.orange)
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Text(won ? "VICTORY AT THE CLUB" : "A MATCH WELL PLAYED")
                .font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(1.5)
              Spacer()
              Image(systemName: won ? "laurel.leading" : "sun.max")
            }
            HStack {
              resultScore(session.engine.playerScore, label: "YOU")
              Spacer()
              Text("–").font(.system(size: 54, design: .serif)).opacity(0.4)
              Spacer()
              resultScore(
                session.engine.opponentScore,
                label: session.engine.settings.difficulty.title.uppercased())
            }
            Rectangle().fill(Velvet.background.opacity(0.3)).frame(height: 1)
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text("\(session.engine.bestRally)").font(.system(size: 36, design: .serif))
                Text("BEST RALLY").font(.system(.caption2, design: .monospaced))
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 5) {
                Text("\(session.engine.returns)").font(.system(size: 36, design: .serif))
                Text("YOUR RETURNS").font(.system(.caption2, design: .monospaced))
              }
            }
          }.padding(28).foregroundStyle(Velvet.background)
        }
        Text(
          "\(session.engine.settings.court.title) · First to \(session.engine.target) · Saved to your club record"
        )
        .font(.caption).foregroundStyle(Velvet.muted)
        PrimaryButton(title: "One more match", icon: "arrow.clockwise") { session.reset() }
        Button("Return to the club") { dismiss() }
          .foregroundStyle(Velvet.cream).frame(maxWidth: .infinity).padding(14)
      }.padding(28)
    }
  }

  private func resultScore(_ score: Int, label: String) -> some View {
    VStack(spacing: 6) {
      Text("\(score)").font(.system(size: 86, design: .serif))
      Text(label).font(.system(.caption, design: .monospaced))
    }
  }
}

struct PlayCourt: View {
  let engine: GameEngine
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let bounds = CGRect(origin: .zero, size: size)
      context.fill(
        Path(roundedRect: bounds, cornerRadius: 12),
        with: .linearGradient(
          Gradient(colors: [
            Velvet.court(engine.settings.court).opacity(0.65),
            Velvet.court(engine.settings.court),
            Velvet.court(engine.settings.court).opacity(0.7),
          ]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
      for x in [0.05, 0.95] {
        context.fill(
          Path(roundedRect: bounds, cornerRadius: 12),
          with: .radialGradient(
            Gradient(colors: [Velvet.cream.opacity(0.12), .clear]),
            center: CGPoint(x: w * x, y: h * 0.1), startRadius: 0, endRadius: h * 0.75))
      }
      context.stroke(
        Path(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerRadius: 10),
        with: .color(Velvet.cream.opacity(0.6)), lineWidth: 2)
      var middle = Path()
      middle.move(to: CGPoint(x: w / 2, y: 3))
      middle.addLine(to: CGPoint(x: w / 2, y: h - 3))
      context.stroke(middle, with: .color(Velvet.cream.opacity(0.22)), lineWidth: 1)
      let netY = h * 0.5
      context.fill(
        Path(CGRect(x: 0, y: netY - 4, width: w, height: 9)),
        with: .color(Velvet.background.opacity(0.4)))
      var net = Path()
      net.move(to: CGPoint(x: 0, y: netY))
      net.addLine(to: CGPoint(x: w, y: netY))
      context.stroke(
        net, with: .color(Velvet.cream.opacity(0.8)),
        style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
      context.draw(
        Text("V / R").font(.system(size: 44, weight: .regular, design: .serif))
          .foregroundColor(Velvet.cream.opacity(0.08)),
        at: CGPoint(x: w / 2, y: h * 0.3))
      for (x, y, width, color) in [
        (engine.opponentX, GameEngine.farY, 0.18, Velvet.orange),
        (engine.playerX, GameEngine.nearY, engine.paddleWidth, Velvet.cream),
      ] {
        let paddle = CGRect(x: (x - width / 2) * w, y: y * h - 5, width: width * w, height: 10)
        let shadow = paddle.offsetBy(dx: 0, dy: 5)
        context.fill(Path(roundedRect: shadow, cornerRadius: 5), with: .color(.black.opacity(0.25)))
        context.fill(Path(roundedRect: paddle, cornerRadius: 5), with: .color(color))
        context.stroke(
          Path(roundedRect: paddle, cornerRadius: 5), with: .color(Velvet.cream.opacity(0.7)),
          lineWidth: 1)
        context.fill(
          Path(
            roundedRect: CGRect(x: x * w - 3, y: y * h + (y > 0.5 ? 5 : -16), width: 6, height: 11),
            cornerRadius: 2),
          with: .color(color.opacity(0.6)))
      }
      context.draw(
        Text("YOU").font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(Velvet.cream.opacity(0.7)),
        at: CGPoint(x: engine.playerX * w, y: h * 0.96))
      if !reduceMotion {
        for (index, point) in engine.trail.enumerated() {
          let radius = Double(index + 1) / 9 * GameEngine.radius * w
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: point.x * w - radius, y: point.y * h - radius, width: radius * 2,
                height: radius * 2)),
            with: .color(Velvet.orange.opacity(Double(index) / 20)))
        }
      }
      let r = GameEngine.radius * w
      let center = CGPoint(x: engine.ball.x * w, y: engine.ball.y * h)
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r + 4, width: r * 2, height: r * 2)),
        with: .color(.black.opacity(0.25)))
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
        with: .color(Velvet.orange))
      context.stroke(
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
        with: .color(Velvet.cream), lineWidth: 1.8)
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: center.x - r / 2, y: center.y - r / 2, width: r * 0.6, height: r * 0.6)),
        with: .color(Velvet.cream.opacity(0.8)))
    }
    .accessibilityLabel(
      "Table tennis court. Your cream paddle is at the bottom, the orange opponent is at the top.")
  }
}
