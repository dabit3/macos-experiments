import QuartzCore
import SwiftUI
import UIKit

struct HitFeedback: Identifiable {
  let id: Int
  let lane: Int
  let judgment: Judgment
  let time: Double  // game time of the hit
  let auto: Bool
}

struct GameView: View {
  let track: Track
  var onFinish: (GameState) -> Void
  var onQuit: () -> Void

  private let laneNames = ["VERTEX", "RASTER", "SHADER", "OUTPUT"]
  private let countdownLen = 3.0
  private let travel = 1.6
  @State private var synth = SynthEngine()
  private let store = ScoreStore.shared
  @State private var haptics: Haptics

  @State private var state: GameState
  @State private var t0: CFTimeInterval = 0
  @State private var musicBegun = false
  @State private var paused = false
  @State private var pauseAt: CFTimeInterval = 0
  @State private var feedback: [HitFeedback] = []
  @State private var laneFlash = [Double](repeating: -10, count: 4)
  @State private var pressed: Set<Int> = []
  @State private var comboBump = false
  @State private var finishSent = false
  @State private var feedbackID = 0
  @State private var frameTick = 0
  @Environment(\.scenePhase) private var scenePhase

  private let timer = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

  init(track: Track, onFinish: @escaping (GameState) -> Void, onQuit: @escaping () -> Void) {
    self.track = track
    self.onFinish = onFinish
    self.onQuit = onQuit
    let seed = UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFFFF
    _state = State(
      initialValue: GameState(track: track, notes: ChartGenerator.notes(for: track, seed: seed)))
    _haptics = State(initialValue: Haptics(enabled: ScoreStore.shared.hapticsOn))
  }

  private func now() -> Double {
    CACurrentMediaTime() - t0 - countdownLen
  }

  var body: some View {
    let _ = frameTick  // read so the timer tick forces redraws
    GeometryReader { geo in
      let rawT = now()
      let t = max(rawT, 0)
      let lag = state.lag
      let rate = max(8, 120 - lag * 112)
      let visualT = rawT >= 0 ? t : 0
      let quantizedT = floor(visualT * rate) / rate
      ZStack {
        Palette.black
        gameCanvas(size: geo.size, t: quantizedT, lag: lag)
        hud(t: t)
        dlssOverlay(t: t)
        countdownOverlay(rawT: rawT)
        if paused { pauseOverlay }
      }
      .onReceive(timer) { _ in
        frameTick &+= 1
        advanceIfNeeded(t: now())
      }
      .onAppear {
        t0 = CACurrentMediaTime()
        synth.configure(track: track)
        if store.soundOn { synth.start() }
      }
      .onDisappear { synth.stop() }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active && !paused { pauseGame() }
      }
      .statusBarHidden(true)
    }
    .ignoresSafeArea(edges: .bottom)
  }

  // MARK: - Frame update

  private func advanceIfNeeded(t: Double) {
    guard t0 > 0, t >= 0, !paused, !finishSent else { return }
    if !musicBegun {
      musicBegun = true
      synth.play()
    }
    synth.setLag(state.lag)
    for event in state.advance(to: t) {
      switch event {
      case .missed(let note):
        laneFlash[note.lane] = t
        addFeedback(lane: note.lane, judgment: .miss, t: t, auto: false)
        haptics.error()
        synth.sfx(.miss)
      case .autoHit(let note):
        laneFlash[note.lane] = t
        addFeedback(lane: note.lane, judgment: .perfect, t: t, auto: true)
        synth.sfx(.great)
      case .finished:
        finishSent = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
          onFinish(state)
        }
      }
    }
  }

  private func addFeedback(lane: Int, judgment: Judgment, t: Double, auto: Bool) {
    feedbackID += 1
    feedback.append(
      HitFeedback(id: feedbackID, lane: lane, judgment: judgment, time: t, auto: auto))
    if feedback.count > 24 { feedback.removeFirst(feedback.count - 24) }
  }

  private func tapLane(_ lane: Int) {
    let t = now()
    guard t >= 0, !paused, !finishSent else { return }
    if let judgment = state.tap(lane: lane, at: t) {
      laneFlash[lane] = t
      addFeedback(lane: lane, judgment: judgment, t: t, auto: false)
      comboBump.toggle()
      switch judgment {
      case .perfect:
        haptics.light()
        synth.sfx(.perfect)
      case .great:
        haptics.light()
        synth.sfx(.great)
      case .good:
        haptics.rigid()
        synth.sfx(.good)
      case .miss:
        haptics.error()
        synth.sfx(.miss)
      }
    } else {
      synth.sfx(.whiff)
    }
  }

  // MARK: - Canvas

  private func gameCanvas(size: CGSize, t: Double, lag: Double) -> some View {
    Canvas { ctx, canvasSize in
      let padH: CGFloat = 110
      let top: CGFloat = 64
      let laneArea = CGRect(
        x: 0, y: top, width: canvasSize.width, height: canvasSize.height - top - padH)
      let hitY = laneArea.maxY - 30

      // Screen tearing: horizontal bands offset by lag.
      var rng = SeededRandom(seed: UInt64(floor(t * 10) * 7919) + 13)
      let bandCount = lag > 0.5 ? 4 : (lag > 0.2 ? 3 : 1)
      for band in 0..<bandCount {
        var bandCtx = ctx
        let bandH = canvasSize.height / CGFloat(bandCount)
        let rect = CGRect(x: 0, y: bandH * CGFloat(band), width: canvasSize.width, height: bandH)
        bandCtx.clip(to: Path(rect))
        let offset = (rng.next() - 0.5) * lag * 28
        bandCtx.translateBy(x: offset, y: 0)
        drawScene(ctx: bandCtx, size: canvasSize, laneArea: laneArea, hitY: hitY, t: t, lag: lag)
      }
    }
  }

  private func drawScene(
    ctx: GraphicsContext, size: CGSize, laneArea: CGRect, hitY: CGFloat, t: Double, lag: Double
  ) {
    let laneW = laneArea.width / 4

    // Lane guides.
    for l in 0..<4 {
      let x = laneArea.minX + laneW * CGFloat(l)
      var rect = Path()
      rect.addRect(CGRect(x: x, y: laneArea.minY, width: laneW, height: laneArea.height))
      ctx.fill(rect, with: .color(l % 2 == 0 ? Palette.charcoal.opacity(0.5) : Color.clear))
      var line = Path()
      line.move(to: CGPoint(x: x, y: laneArea.minY))
      line.addLine(to: CGPoint(x: x, y: laneArea.maxY))
      ctx.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
    }

    // Hit line.
    var hl = Path()
    hl.move(to: CGPoint(x: 0, y: hitY))
    hl.addLine(to: CGPoint(x: size.width, y: hitY))
    ctx.stroke(hl, with: .color(Palette.green.opacity(0.9)), lineWidth: 2)

    // Notes (and a duplicated ghost frame while lagging).
    drawNotes(
      ctx: ctx, size: size, laneArea: laneArea, hitY: hitY, t: t, alpha: 1, ghost: false, lag: lag)
    if lag > 0.3 {
      let rate = max(8, 120 - lag * 112)
      drawNotes(
        ctx: ctx, size: size, laneArea: laneArea, hitY: hitY, t: t - 1 / rate,
        alpha: 0.3, ghost: true, lag: lag)
    }

    // Hit sparks for recent feedback.
    for fb in feedback {
      let age = t - fb.time
      guard age < 0.45 else { continue }
      let cx = laneArea.minX + laneW * (CGFloat(fb.lane) + 0.5)
      var sparkRng = SeededRandom(seed: UInt64(fb.id) &* 2_654_435_761)
      for _ in 0..<7 {
        let ang = sparkRng.next() * 2 * .pi
        let r = age * 200 + sparkRng.next() * 10
        let p = CGPoint(x: cx + cos(ang) * r, y: hitY + sin(ang) * r * 0.6)
        let shard = Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2))
        let color = fb.judgment == .miss ? Palette.red : Palette.green
        ctx.fill(shard, with: .color(color.opacity(max(0, 1 - age / 0.45))))
      }
      // Judgment text pop.
      let scale = 1 + max(0, 0.5 - age) * 1.6
      let text = fb.auto ? "AUTO" : fb.judgment.rawValue.uppercased()
      let color: Color =
        fb.judgment == .miss ? Palette.red : (fb.judgment == .perfect ? Palette.green : .white)
      let resolved = ctx.resolve(
        Text(text)
          .font(.mono(16, .heavy))
          .foregroundStyle(color)
      )
      var textCtx = ctx
      textCtx.translateBy(x: cx, y: hitY - 46 - age * 30)
      textCtx.scaleBy(x: scale, y: scale)
      textCtx.draw(resolved, at: .zero, anchor: .center)
    }

    // Lane flashes.
    for l in 0..<4 {
      let age = t - laneFlash[l]
      guard age < 0.25 else { continue }
      let rect = CGRect(
        x: laneArea.minX + laneW * CGFloat(l), y: laneArea.minY, width: laneW,
        height: laneArea.height)
      ctx.fill(
        Path(rect),
        with: .color(Palette.green.opacity(0.16 * max(0, 1 - age / 0.25))))
    }
  }

  private func drawNotes(
    ctx: GraphicsContext, size: CGSize, laneArea: CGRect, hitY: CGFloat, t: Double,
    alpha: Double, ghost: Bool, lag: Double
  ) {
    let laneW = laneArea.width / 4
    for note in state.notes {
      if state.hit.contains(note.id) { continue }
      let dt = note.time - t
      if dt > travel || dt < -0.25 { continue }
      let y = hitY - (dt / travel) * (hitY - laneArea.minY)
      let noteRect = CGRect(
        x: laneArea.minX + laneW * CGFloat(note.lane) + 7,
        y: y - 10, width: laneW - 14, height: 20)
      // Chromatic split at deep lag.
      if !ghost && lag > 0.5 {
        var r = Path()
        r.addRoundedRect(
          in: noteRect.offsetBy(dx: 2, dy: 0), cornerSize: CGSize(width: 5, height: 5))
        ctx.fill(r, with: .color(.red.opacity(0.25 * alpha)))
        var b = Path()
        b.addRoundedRect(
          in: noteRect.offsetBy(dx: -2, dy: 0), cornerSize: CGSize(width: 5, height: 5))
        ctx.fill(b, with: .color(.blue.opacity(0.25 * alpha)))
      }
      var path = Path()
      path.addRoundedRect(in: noteRect, cornerSize: CGSize(width: 5, height: 5))
      ctx.fill(path, with: .color(Palette.green.opacity(alpha)))
      if !ghost {
        ctx.stroke(path, with: .color(.white.opacity(0.5 * alpha)), lineWidth: 1)
      }
    }
  }

  // MARK: - HUD

  private func hud(t: Double) -> some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        Button(action: pauseGame) {
          Image(systemName: "pause.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Palette.green)
            .padding(10)
        }
        Spacer()
        VStack(spacing: 0) {
          let flicker = flickerDim(t: t)
          Text("\(Int(state.fps))")
            .font(.mono(40, .heavy))
            .foregroundStyle(fpsColor)
            .greenGlow(8)
            .opacity(flicker)
          Text("FPS")
            .font(.mono(10, .medium))
            .foregroundStyle(Palette.faint)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(state.score)")
            .font(.mono(20, .bold))
            .foregroundStyle(.white)
          if state.combo > 1 {
            Text("x\(state.combo) COMBO")
              .font(.mono(13, .bold))
              .foregroundStyle(Palette.green)
              .scaleEffect(comboBump ? 1.22 : 1)
              .animation(.spring(duration: 0.18), value: comboBump)
          }
        }
        .padding(.trailing, 14)
      }
      .padding(.top, 8)

      // Lane headers.
      HStack(spacing: 0) {
        ForEach(0..<4, id: \.self) { l in
          Text(laneNames[l])
            .font(.mono(10, .bold))
            .foregroundStyle(Palette.dim)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.top, 2)

      Spacer()

      // DLSS bar + button.
      HStack(spacing: 10) {
        GeometryReader { g in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(Palette.panel)
            RoundedRectangle(cornerRadius: 3)
              .fill(state.dlss.isFull ? Palette.green : Palette.green.opacity(0.55))
              .frame(width: g.size.width * min(1, state.dlss.charge))
          }
        }
        .frame(height: 8)
        Button {
          if state.activateDLSS() {
            haptics.heavy()
            synth.sfx(.dlss)
          }
        } label: {
          Text("DLSS 3 · FRAME GEN")
            .font(.mono(11, .heavy))
            .foregroundStyle(state.dlss.isFull ? Palette.black : Palette.faint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(state.dlss.isFull ? Palette.green : Palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .greenGlow(state.dlss.isFull ? 10 : 0)
        }
        .disabled(!state.dlss.isFull)
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 6)

      // Tap pads.
      HStack(spacing: 8) {
        ForEach(0..<4, id: \.self) { l in
          RoundedRectangle(cornerRadius: 8)
            .fill(pressed.contains(l) ? Palette.green.opacity(0.85) : Palette.panel)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.green.opacity(pressed.contains(l) ? 1 : 0.45), lineWidth: 2)
            )
            .overlay(
              Text(laneNames[l])
                .font(.mono(11, .heavy))
                .foregroundStyle(pressed.contains(l) ? Palette.black : Palette.dim)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .gesture(
              DragGesture(minimumDistance: 0)
                .onChanged { _ in
                  if !pressed.contains(l) {
                    pressed.insert(l)
                    tapLane(l)
                  }
                }
                .onEnded { _ in pressed.remove(l) }
            )
        }
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 10)
    }
  }

  private var fpsColor: Color {
    if state.fps >= 200 { return Palette.green }
    if state.fps >= 120 { return Palette.yellow }
    return Palette.red
  }

  private func flickerDim(t: Double) -> Double {
    guard state.lag > 0.35 else { return 1 }
    var rng = SeededRandom(seed: UInt64(floor(t * 18) * 104729) + 5)
    return rng.next() < state.lag * 0.55 ? 0.45 : 1
  }

  // MARK: - Overlays

  private func dlssOverlay(t: Double) -> some View {
    Group {
      if state.dlss.isActive(at: t) {
        ZStack {
          Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
              var line = Path()
              line.move(to: CGPoint(x: 0, y: y))
              line.addLine(to: CGPoint(x: size.width, y: y))
              ctx.stroke(line, with: .color(Palette.green.opacity(0.07)), lineWidth: 1)
              y += 6
            }
          }
          VStack {
            Text("FRAME GENERATION")
              .font(.mono(14, .heavy))
              .tracking(6)
              .foregroundStyle(Palette.green)
              .greenGlow(12)
              .padding(.top, 120)
            Spacer()
          }
        }
        .allowsHitTesting(false)
      }
    }
  }

  private func countdownOverlay(rawT: Double) -> some View {
    Group {
      if rawT < 0 {
        ZStack {
          Palette.black.opacity(0.75)
          VStack(spacing: 16) {
            Text("COMPILING SHADERS…")
              .font(.mono(14, .bold))
              .tracking(3)
              .foregroundStyle(Palette.dim)
            Text("\(max(1, Int(ceil(-rawT))))")
              .font(.hero(80, .heavy))
              .foregroundStyle(Palette.green)
              .greenGlow(16)
          }
        }
        .allowsHitTesting(false)
      }
    }
  }

  private var pauseOverlay: some View {
    ZStack {
      Palette.black.opacity(0.85)
      VStack(spacing: 22) {
        Text("RENDER PAUSED")
          .font(.hero(26, .heavy))
          .tracking(4)
          .foregroundStyle(.white)
        Button(action: resumeGame) {
          Text("RESUME")
            .font(.hero(17, .heavy))
            .tracking(3)
            .foregroundStyle(Palette.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 13)
            .background(Palette.green)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        Button(action: {
          synth.stop()
          onQuit()
        }) {
          Text("QUIT TO TRACKS")
            .font(.mono(13, .bold))
            .tracking(2)
            .foregroundStyle(Palette.dim)
            .padding(.horizontal, 30)
            .padding(.vertical, 11)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(Palette.faint, lineWidth: 1)
            )
        }
      }
    }
  }

  private func pauseGame() {
    guard !paused, !finishSent else { return }
    paused = true
    pauseAt = CACurrentMediaTime()
    synth.pause()
  }

  private func resumeGame() {
    t0 += CACurrentMediaTime() - pauseAt
    paused = false
    synth.play()
  }
}

// MARK: - Haptics

struct Haptics {
  let enabled: Bool
  private let lightGen = UIImpactFeedbackGenerator(style: .light)
  private let rigidGen = UIImpactFeedbackGenerator(style: .rigid)
  private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
  private let notify = UINotificationFeedbackGenerator()

  init(enabled: Bool) {
    self.enabled = enabled
    lightGen.prepare()
    rigidGen.prepare()
    heavyGen.prepare()
    notify.prepare()
  }

  func light() { if enabled { lightGen.impactOccurred() } }
  func rigid() { if enabled { rigidGen.impactOccurred() } }
  func heavy() { if enabled { heavyGen.impactOccurred() } }
  func error() { if enabled { notify.notificationOccurred(.error) } }
}
