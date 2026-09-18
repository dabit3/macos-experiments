import Combine
import SwiftUI

struct PrismRoot: View {
  @Bindable var model: GameModel
  private let clock = Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      PrismBackdrop()
      switch model.screen {
      case .title: TitleView(model: model)
      case .playing, .ending:
        GameView(model: model).allowsHitTesting(model.screen == .playing)
      case .paused: PauseView(model: model)
      case .result: ResultView(model: model)
      }
    }
    .foregroundStyle(PrismStyle.paper)
    .background(KeyboardBridge(model: model).frame(width: 0, height: 0))
    .onReceive(clock) { model.tick($0) }
    .sheet(isPresented: $model.showingGuide) { GuideView(model: model) }
  }
}

struct TitleView: View {
  @Bindable var model: GameModel

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        HStack {
          Eyebrow(text: "THE FALLING BLOCK COLLECTION")
          Spacer()
          Image(systemName: "sparkle").foregroundStyle(PrismStyle.ice)
        }.padding(.top, 14)
        Spacer(minLength: 15)
        HeroPrism().frame(width: 260, height: min(geometry.size.height * 0.32, 255))
        Spacer(minLength: 18)
        VStack(spacing: 9) {
          Text("PRISM").font(.system(size: 58, weight: .ultraLight)).tracking(13)
            .foregroundStyle(PrismStyle.headline)
          SpectralRule().frame(width: 190)
          Text("S T A C K").font(.system(size: 17, weight: .medium)).tracking(7)
        }
        .padding(.leading, 13)
        Text("Find your flow.\nLeave nothing behind.")
          .font(.system(size: 18, weight: .regular, design: .serif)).italic().lineSpacing(5)
          .foregroundStyle(PrismStyle.mist).multilineTextAlignment(.center)
          .padding(.top, 22)
        Spacer(minLength: 20)
        HStack(spacing: 12) {
          Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
          VStack(spacing: 6) {
            Eyebrow(text: "PERSONAL BEST")
            Text(model.best.formatted()).font(.system(size: 24, weight: .light, design: .rounded))
              .monospacedDigit().foregroundStyle(PrismStyle.headline)
          }.fixedSize()
          Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
        }.padding(.bottom, 26)
        PrismButton(
          title: model.hasSavedGame ? "Continue your flow" : "Enter the flow",
          symbol: "arrow.right", primary: true
        ) { model.start() }
        HStack {
          Button {
            model.showingGuide = true
          } label: {
            Label("How to play", systemImage: "questionmark.circle")
              .font(.system(size: 13)).frame(height: 48)
          }
          Spacer()
          Button {
            model.toggleSound()
          } label: {
            Image(systemName: model.sound ? "speaker.wave.2" : "speaker.slash")
              .frame(width: 48, height: 48)
          }.accessibilityLabel(model.sound ? "Mute sound" : "Enable sound")
        }.foregroundStyle(PrismStyle.mist)
      }.padding(.horizontal, 30).padding(.bottom, 5)
    }
  }
}

struct GameView: View {
  @Bindable var model: GameModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dragPosition: CGFloat = 0
  @State private var softPosition: CGFloat = 0
  @State private var dragActive = false

  var body: some View {
    GeometryReader { geometry in
      let boardWidth = max(140, min(geometry.size.width - 112, (geometry.size.height - 205) / 2))
      VStack(spacing: 14) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: "PRISM / STACK")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(model.engine.score.formatted())
                .font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                .foregroundStyle(PrismStyle.headline)
                .contentTransition(.numericText(value: Double(model.engine.score)))
                .animation(.snappy(duration: 0.35), value: model.engine.score)
                .accessibilityIdentifier("score")
              Text("PTS").font(.system(size: 8, weight: .semibold)).tracking(1.5)
                .foregroundStyle(PrismStyle.mist)
            }
          }
          Spacer()
          Button {
            model.pause()
          } label: {
            Image(systemName: "pause")
              .font(.system(size: 17, weight: .medium))
              .frame(width: 46, height: 46)
              .background(PrismStyle.glassFill, in: Circle())
              .overlay(Circle().strokeBorder(PrismStyle.glassRim))
          }.accessibilityLabel("Pause game")
        }
        HStack(alignment: .top, spacing: 18) {
          BoardView(model: model, reduceMotion: reduceMotion)
            .frame(width: boardWidth, height: boardWidth * 2)
            .padding(5)
            .background(PrismStyle.glassFill, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(PrismStyle.glassRim))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
            .overlay(alignment: .bottom) {
              SpectralRule(opacity: 0.6).frame(width: boardWidth * 0.7).offset(y: 6)
            }
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 10)
                .onChanged { value in
                  guard model.gestures else { return }
                  dragActive = true
                  let unit = boardWidth / 10
                  let dx = value.translation.width - dragPosition
                  if abs(dx) >= unit {
                    model.act(dx > 0 ? .right : .left)
                    dragPosition += dx > 0 ? unit : -unit
                  }
                  let dy = value.translation.height - softPosition
                  if dy > unit {
                    model.act(.softDrop)
                    softPosition += unit
                  }
                }
                .onEnded { value in
                  defer {
                    dragPosition = 0
                    softPosition = 0
                    dragActive = false
                  }
                  guard model.gestures else { return }
                  if value.translation.height < -45 { model.act(.hold) }
                  if value.translation.height > 60,
                    value.predictedEndTranslation.height > value.translation.height + 100
                  {
                    model.act(.hardDrop)
                  }
                }
            )
            .onTapGesture { if model.gestures && !dragActive { model.act(.rotate) } }
          sidebar.frame(width: 58)
        }.frame(maxWidth: .infinity)
        controls
      }.padding(.horizontal, 18).padding(.top, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
  }

  private var sidebar: some View {
    VStack(spacing: 0) {
      Button {
        model.act(.hold)
      } label: {
        VStack(spacing: 10) {
          HStack(spacing: 4) {
            Eyebrow(text: "HOLD")
            if !model.engine.canHold {
              Image(systemName: "lock.fill").font(.system(size: 8))
                .foregroundStyle(PrismStyle.mist)
            }
          }
          PiecePreview(jewel: model.engine.held)
            .frame(height: 31)
        }
        .frame(width: 68, height: 72)
        .background(PrismStyle.glassFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PrismStyle.glassRim))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Hold piece")
      .accessibilityValue(model.engine.canHold ? "Ready" : "Available after placing this piece")
      .disabled(!model.engine.canHold)
      Eyebrow(text: "NEXT").padding(.top, 25).padding(.bottom, 14)
      ForEach(Array(model.engine.queue.prefix(3).enumerated()), id: \.offset) { item in
        PiecePreview(jewel: item.element).frame(height: 29).padding(.bottom, 17)
      }
      SpectralRule(opacity: 0.5).padding(.vertical, 5)
      VStack(spacing: 6) {
        Eyebrow(text: "LEVEL")
        ZStack {
          Circle().stroke(.white.opacity(0.08), lineWidth: 2.5)
          Circle()
            .trim(from: 0, to: CGFloat(model.engine.lines % 10) / 10)
            .stroke(
              AngularGradient(
                colors: [PrismStyle.ice, Jewel.violet.color, PrismStyle.ice], center: .center),
              style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.5), value: model.engine.lines)
          Text(String(format: "%02d", model.engine.level))
            .font(.system(size: 20, weight: .light, design: .rounded))
            .foregroundStyle(PrismStyle.headline)
        }
        .frame(width: 50, height: 50)
        .accessibilityLabel("Level \(model.engine.level)")
        Eyebrow(text: "LINES").padding(.top, 14)
        Text("\(model.engine.lines)").font(.system(size: 22, weight: .light, design: .rounded))
          .accessibilityIdentifier("lines")
      }.padding(.top, 15)
      Spacer(minLength: 12)
    }
  }

  private var controls: some View {
    VStack(spacing: 8) {
      HStack(spacing: 9) {
        ControlButton(symbol: "arrow.left", name: "Move left", repeats: true) {
          model.act(.left)
        }
        ControlButton(symbol: "arrow.clockwise", name: "Rotate", repeats: false) {
          model.act(.rotate)
        }
        ControlButton(symbol: "arrow.right", name: "Move right", repeats: true) {
          model.act(.right)
        }
      }
      HStack(spacing: 9) {
        ControlButton(symbol: "arrow.down", name: "Soft drop", repeats: true) {
          model.act(.softDrop)
        }.frame(maxWidth: 80)
        Button {
          model.act(.hardDrop)
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "arrow.down.to.line.compact")
            Text("DROP").font(.system(size: 12, weight: .bold)).tracking(2)
          }.frame(maxWidth: .infinity).frame(height: 48)
            .foregroundStyle(PrismStyle.ink)
            .background(PrismStyle.iceShine, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.5)))
            .shadow(color: PrismStyle.ice.opacity(0.28), radius: 12, y: 5)
        }.buttonStyle(.plain).accessibilityLabel("Hard drop")
      }
      Text(
        model.gestures
          ? "Drag to move · tap to turn · flick down to drop"
          : "Hold arrows to glide · tap DROP to place"
      )
      .font(.system(size: 10, weight: .medium)).tracking(0.25)
      .foregroundStyle(PrismStyle.mist).padding(.top, 2)
    }
  }
}

struct ControlButton: View {
  let symbol: String
  let name: String
  let repeats: Bool
  let action: () -> Void
  @State private var pressed = false
  @State private var repeatTask: Task<Void, Never>?

  var body: some View {
    Image(systemName: symbol).font(.system(size: 19, weight: .medium))
      .foregroundStyle(pressed ? PrismStyle.ice : PrismStyle.paper)
      .frame(maxWidth: .infinity).frame(height: 48)
      .background(PrismStyle.glassFill, in: RoundedRectangle(cornerRadius: 13))
      .background(
        PrismStyle.ice.opacity(pressed ? 0.18 : 0), in: RoundedRectangle(cornerRadius: 13)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 13)
          .strokeBorder(pressed ? PrismStyle.ice.opacity(0.7) : .white.opacity(0.13))
      )
      .shadow(color: PrismStyle.ice.opacity(pressed ? 0.35 : 0), radius: 10)
      .animation(.easeOut(duration: 0.12), value: pressed)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            guard !pressed else { return }
            pressed = true
            action()
            guard repeats else { return }
            repeatTask = Task { @MainActor in
              try? await Task.sleep(for: .milliseconds(220))
              while !Task.isCancelled {
                action()
                try? await Task.sleep(for: .milliseconds(70))
              }
            }
          }
          .onEnded { _ in
            pressed = false
            repeatTask?.cancel()
            repeatTask = nil
          }
      )
      .accessibilityLabel(name)
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { action() }
      .onDisappear {
        repeatTask?.cancel()
        repeatTask = nil
        pressed = false
      }
  }
}

struct BoardView: View {
  let model: GameModel
  let reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: model.screen != .playing)) {
      timeline in
      let clearAge = timeline.date.timeIntervalSince(model.clearDate)
      Canvas { context, size in
        let unit = size.width / 10
        let frame = CGRect(origin: .zero, size: size)
        let backdrop = Path(roundedRect: frame, cornerRadius: 8)
        context.fill(
          backdrop,
          with: .linearGradient(
            Gradient(colors: [.black.opacity(0.42), .black.opacity(0.22)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        var grid = Path()
        for x in 1..<10 {
          grid.move(to: CGPoint(x: CGFloat(x) * unit, y: 0))
          grid.addLine(to: CGPoint(x: CGFloat(x) * unit, y: size.height))
        }
        for y in 1..<20 {
          grid.move(to: CGPoint(x: 0, y: CGFloat(y) * unit))
          grid.addLine(to: CGPoint(x: size.width, y: CGFloat(y) * unit))
        }
        context.stroke(
          grid,
          with: .linearGradient(
            Gradient(colors: [.white.opacity(0.02), .white.opacity(0.06)]), startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)),
          lineWidth: 0.5)
        var locked: [(CGRect, Jewel)] = []
        var topRow = 20
        for y in 0..<20 {
          for x in 0..<10 {
            if let jewel = Jewel(rawValue: model.engine.board[y + 2][x]) {
              topRow = min(topRow, y)
              locked.append(
                (
                  CGRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit),
                  jewel
                ))
            }
          }
        }
        if topRow < 5 {
          let danger = CGRect(x: 0, y: 0, width: size.width, height: unit * 4)
          let pulse = 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 5)
          context.fill(
            Path(danger),
            with: .linearGradient(
              Gradient(colors: [Jewel.rose.color.opacity(0.12 + 0.14 * pulse), .clear]),
              startPoint: .zero, endPoint: CGPoint(x: 0, y: danger.maxY)))
        }
        drawGlow(context, rects: locked, radius: 5)
        for (rect, jewel) in locked { drawGem(context, rect: rect, jewel: jewel) }
        if model.screen == .playing {
          if let ghost = model.engine.ghost {
            for cell in ghost.cells where cell.y >= 2 {
              drawGem(context, rect: rect(cell, unit), jewel: ghost.jewel, ghost: true)
            }
          }
          if let piece = model.engine.active {
            let rects = piece.cells.filter { $0.y >= 2 }.map { (rect($0, unit), piece.jewel) }
            drawGlow(context, rects: rects, radius: 9)
            for (rect, jewel) in rects { drawGem(context, rect: rect, jewel: jewel) }
          }
        }
        if clearAge < 0.7 && !reduceMotion {
          let progress = clearAge / 0.7
          for row in model.engine.clearedRows where row >= 2 {
            let rect = CGRect(x: 0, y: CGFloat(row - 2) * unit, width: size.width, height: unit)
            if clearAge < 0.55 {
              let wave = clearAge / 0.55
              context.fill(
                Path(rect),
                with: .linearGradient(
                  Gradient(colors: [.clear, PrismStyle.ice.opacity(0.8 * (1 - wave)), .clear]),
                  startPoint: CGPoint(x: size.width * wave - size.width / 2, y: rect.midY),
                  endPoint: CGPoint(x: size.width * wave + size.width / 2, y: rect.midY)))
            }
            for shard in 0..<14 {
              let seed = Double((row * 31 + shard * 17) % 97) / 97
              let x = size.width * (Double(shard) + 0.5) / 14 + (seed - 0.5) * unit * progress * 3
              let rise = (shard % 2 == 0 ? -1.0 : 1.0) * (unit * 1.6 + seed * unit * 2.4) * progress
              let side = max(0.5, unit * 0.26 * (1 - progress))
              let color = PrismStyle.spectrum[shard % PrismStyle.spectrum.count]
              let shardRect = CGRect(
                x: x - side / 2, y: rect.midY + rise - side / 2, width: side, height: side)
              context.fill(
                Path(roundedRect: shardRect, cornerRadius: side * 0.3),
                with: .color(color.opacity(0.9 * (1 - progress))))
            }
          }
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            LinearGradient(
              colors: [.white.opacity(0.26), .white.opacity(0.04), .white.opacity(0.12)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(alignment: .center) {
        if model.screen == .ending {
          GlassCard(radius: 12) {
            Text("Stack reached the top").font(.system(size: 15, weight: .medium))
              .foregroundStyle(PrismStyle.paper).padding(16)
              .background(PrismStyle.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
          }
        } else if clearAge < 1.1 && !model.clearText.isEmpty {
          VStack(spacing: 7) {
            Text(model.clearText).font(.system(size: 17, weight: .bold)).tracking(3.5)
              .foregroundStyle(PrismStyle.iceShine)
            SpectralRule().frame(width: 96)
          }
          .padding(.horizontal, 18).padding(.vertical, 13)
          .background(PrismStyle.ink.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(PrismStyle.glassRim))
          .shadow(color: PrismStyle.ice.opacity(0.3), radius: 18)
          .scaleEffect(reduceMotion ? 1 : 1 + 0.08 * max(0, 0.25 - clearAge))
          .opacity(min(1, (1.1 - clearAge) * 4))
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Game board")
    .accessibilityValue(
      "Score \(model.engine.score), \(model.engine.lines) lines, level \(model.engine.level)")
  }

  private func rect(_ cell: Cell, _ unit: CGFloat) -> CGRect {
    CGRect(x: CGFloat(cell.x) * unit, y: CGFloat(cell.y - 2) * unit, width: unit, height: unit)
  }
}

struct PauseView: View {
  @Bindable var model: GameModel

  var body: some View {
    ZStack {
      PrismBackdrop()
      VStack(spacing: 24) {
        Image(systemName: "pause.circle").font(.system(size: 40, weight: .ultraLight))
          .foregroundStyle(PrismStyle.iceShine)
          .shadow(color: PrismStyle.ice.opacity(0.45), radius: 16)
        VStack(spacing: 12) {
          Eyebrow(text: "TAKE A BREATH")
          Text("Still in the flow.").font(.system(size: 33, weight: .light, design: .serif))
            .italic().foregroundStyle(PrismStyle.headline)
          SpectralRule(opacity: 0.6).frame(width: 120)
          Text("Your stack will be right here.").font(.system(size: 14))
            .foregroundStyle(PrismStyle.mist)
        }
        GlassCard {
          HStack(spacing: 0) {
            pauseStat(model.engine.score.formatted(), "POINTS")
            pauseStat("\(model.engine.lines)", "LINES")
            pauseStat(String(format: "%02d", model.engine.level), "LEVEL")
          }.padding(.vertical, 16)
        }
        VStack(spacing: 10) {
          PrismButton(title: "Resume", symbol: "play.fill", primary: true) { model.resume() }
          PrismButton(title: "How to play", symbol: "questionmark.circle") {
            model.showingGuide = true
          }
          HStack {
            Button {
              model.toggleSound()
            } label: {
              Label(
                model.sound ? "Sound on" : "Sound off",
                systemImage: model.sound ? "speaker.wave.2" : "speaker.slash"
              )
              .font(.system(size: 13)).frame(maxWidth: .infinity).frame(height: 48)
            }
            Button {
              model.toggleGestures()
            } label: {
              Label(model.gestures ? "Gestures on" : "Gestures off", systemImage: "hand.draw")
                .font(.system(size: 13)).frame(maxWidth: .infinity).frame(height: 48)
            }
          }.foregroundStyle(PrismStyle.mist)
          Button("Save & return home") { model.home() }
            .font(.system(size: 13)).foregroundStyle(PrismStyle.mist).frame(height: 48)
        }
      }.padding(.horizontal, 34)
    }
  }

  private func pauseStat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 7) {
      Text(value).font(.system(size: 20, weight: .light, design: .rounded)).monospacedDigit()
        .foregroundStyle(PrismStyle.headline)
      Eyebrow(text: label)
    }.frame(maxWidth: .infinity)
  }
}

struct ResultView: View {
  @Bindable var model: GameModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shownScore = 0
  @State private var revealed = false

  var body: some View {
    let newBest = model.engine.score > model.sessionBest
    ZStack {
      PrismBackdrop()
      VStack(spacing: 24) {
        Image(systemName: newBest ? "crown" : "sparkles")
          .font(.system(size: 35, weight: .ultraLight))
          .foregroundStyle(PrismStyle.iceShine)
          .shadow(color: PrismStyle.ice.opacity(0.5), radius: 18)
        VStack(spacing: 12) {
          Eyebrow(text: newBest ? "A NEW PERSONAL BEST" : "FLOW COMPLETE")
          Text("Beautifully played.").font(.system(size: 33, weight: .light, design: .serif))
            .italic().foregroundStyle(PrismStyle.headline)
          SpectralRule(opacity: 0.6).frame(width: 120)
          Text("Your stack reached the top.").font(.system(size: 13))
            .foregroundStyle(PrismStyle.mist)
        }
        VStack(spacing: 7) {
          Text(shownScore.formatted())
            .font(.system(size: 64, weight: .ultraLight, design: .rounded)).monospacedDigit()
            .foregroundStyle(PrismStyle.headline)
            .contentTransition(.numericText(value: Double(shownScore)))
            .animation(.easeOut(duration: 1.1), value: shownScore)
            .shadow(color: PrismStyle.ice.opacity(newBest ? 0.35 : 0.12), radius: 22)
          Eyebrow(text: "POINTS")
        }.padding(.vertical, 10)
        GlassCard {
          HStack(spacing: 0) {
            resultStat("\(model.engine.lines)", "LINES")
            resultStat("\(model.engine.level)", "LEVEL")
            resultStat(model.best.formatted(), "BEST")
          }.padding(.vertical, 19)
        }
        .opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 14)
        .animation(.easeOut(duration: 0.6).delay(0.5), value: revealed)
        VStack(spacing: 10) {
          PrismButton(title: "Find your flow again", symbol: "arrow.clockwise", primary: true) {
            model.replay()
          }
          Button("Return home") { model.home() }.frame(height: 48)
            .font(.system(size: 13)).foregroundStyle(PrismStyle.mist)
        }
      }.padding(.horizontal, 30)
    }
    .onAppear {
      var transaction = Transaction()
      transaction.disablesAnimations = reduceMotion
      withTransaction(transaction) {
        shownScore = model.engine.score
        revealed = true
      }
    }
  }

  private func resultStat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 8) {
      Text(value).font(.system(size: 22, weight: .light, design: .rounded)).monospacedDigit()
        .foregroundStyle(PrismStyle.headline)
      Eyebrow(text: label)
    }.frame(maxWidth: .infinity)
  }
}

struct GuideView: View {
  @Bindable var model: GameModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      PrismBackdrop()
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          HStack {
            Eyebrow(text: "A MOMENT TO LEARN")
            Spacer()
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark").frame(width: 44, height: 44)
            }.accessibilityLabel("Close guide")
          }
          Text("Make room\nfor what’s next.")
            .font(.system(size: 36, weight: .light, design: .serif)).italic()
            .foregroundStyle(PrismStyle.headline)
          SpectralRule(opacity: 0.6).frame(width: 140)
          Text(
            "Fill a horizontal row with no gaps to clear it. Keep your stack below the top. Every ten lines, the pace rises."
          )
          .font(.system(size: 16)).lineSpacing(5).foregroundStyle(PrismStyle.mist)
          guideRow(
            "arrow.left.and.right", "Find your position",
            "Tap the arrows to move. Hold an arrow to glide. The outline shows where your piece will land."
          )
          guideRow(
            "arrow.clockwise", "Turn & place",
            "Rotate to find a fit. Soft drop nudges down; DROP places instantly. Clear four rows together for 800 × your level."
          )
          guideRow(
            "square.on.square", "Keep a little possibility",
            "Tap HOLD to save or swap a piece, once per turn. Preview your next three pieces.")
          Button {
            model.toggleGestures()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text("Board gestures").font(.system(size: 15, weight: .medium))
                Text("Drag to move · tap to turn\nFlick down to drop · swipe up to hold")
                  .font(.system(size: 12)).foregroundStyle(PrismStyle.mist).lineSpacing(4)
              }
              Spacer()
              Image(systemName: model.gestures ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 25)).foregroundStyle(PrismStyle.ice)
            }.padding(18).background(PrismStyle.glassFill, in: RoundedRectangle(cornerRadius: 16))
              .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(PrismStyle.glassRim))
          }.buttonStyle(.plain).accessibilityLabel(
            "Board gestures \(model.gestures ? "on" : "off")")
          PrismButton(title: "I’m ready", symbol: "arrow.right", primary: true) { dismiss() }
        }.padding(28)
      }
    }.presentationDragIndicator(.visible).preferredColorScheme(.dark)
  }

  private func guideRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: symbol).font(.system(size: 20, weight: .light))
        .foregroundStyle(PrismStyle.iceShine).frame(width: 44, height: 44)
        .background(PrismStyle.glassFill, in: Circle())
        .overlay(Circle().strokeBorder(PrismStyle.glassRim))
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.system(size: 16, weight: .medium))
        Text(detail).font(.system(size: 13)).lineSpacing(4).foregroundStyle(PrismStyle.mist)
      }
    }
  }
}
