import CudaBlocksCore
import SwiftUI

struct GameView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    ZStack {
      VStack(spacing: 10) {
        header
        HStack(alignment: .top, spacing: 10) {
          leftRail
          ZStack {
            BoardView(store: store)
              .overlay(TouchLayer(store: store))
            toastLayer
          }
          rightRail
        }
        .padding(.horizontal, 10)
        controls
      }
      .padding(.top, 6)
      .padding(.bottom, 8)

      if store.screen == .paused { PauseOverlay(store: store) }
      if store.screen == .gameOver { GameOverOverlay(store: store) }
    }
  }

  private var state: GameState { store.engine.state }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 0) {
        Text("THROUGHPUT")
          .font(Theme.mono(9, weight: .bold)).tracking(1.6)
          .foregroundStyle(Theme.green.opacity(0.85))
        Text(ScoreFormat.compact(state.score))
          .font(Theme.display(34))
          .foregroundStyle(Theme.bone)
          .contentTransition(.numericText())
          .animation(.snappy(duration: 0.2), value: state.score)
          .shadow(color: Theme.green.opacity(0.5), radius: 8)
      }
      Spacer()
      Button {
        store.pause()
      } label: {
        Image(systemName: "pause.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(Theme.green)
          .frame(width: 42, height: 42)
          .background(RoundedRectangle(cornerRadius: 6).fill(Theme.charcoal))
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.5), lineWidth: 1))
      }
      .accessibilityLabel("Pause")
    }
    .padding(.horizontal, 14)
  }

  private var leftRail: some View {
    VStack(spacing: 8) {
      DiePanel(title: "Hold") {
        KernelPreview(kernel: state.hold, dimmed: !state.canHold, size: 11)
      }
      DiePanel(title: "Clock") {
        Text("L\(state.level)")
          .font(Theme.display(22)).foregroundStyle(Theme.bone)
        Text(ScoreFormat.clock(level: state.level))
          .font(Theme.mono(9)).foregroundStyle(Theme.ash)
      }
      DiePanel(title: "Warps") {
        Text("\(state.lines)")
          .font(Theme.display(22)).foregroundStyle(Theme.bone)
          .contentTransition(.numericText())
        Text("rows cleared").font(Theme.mono(8)).foregroundStyle(Theme.ash)
      }
      Spacer(minLength: 0)
    }
    .frame(width: 74)
  }

  private var rightRail: some View {
    VStack(spacing: 8) {
      DiePanel(title: "Queue") {
        VStack(spacing: 6) {
          ForEach(Array(state.queue.prefix(4).enumerated()), id: \.offset) { i, k in
            KernelPreview(kernel: k, size: i == 0 ? 11 : 9)
              .opacity(i == 0 ? 1 : 0.75)
          }
        }
      }
      DiePanel(title: "Tensor", glow: state.multiplier > 1) {
        Text("x\(state.multiplier)")
          .font(Theme.display(24))
          .foregroundStyle(state.multiplier > 1 ? Theme.greenBright : Theme.bone)
          .contentTransition(.numericText())
          .animation(.bouncy, value: state.multiplier)
        Text(state.backToBack ? "B2B armed" : "multiplier")
          .font(Theme.mono(8)).foregroundStyle(state.backToBack ? Theme.greenBright : Theme.ash)
      }
      if state.combo > 0 {
        DiePanel(title: "Combo") {
          Text("\(state.combo)").font(Theme.display(20)).foregroundStyle(Theme.amber)
        }
        .transition(.scale.combined(with: .opacity))
      }
      Spacer(minLength: 0)
    }
    .frame(width: 74)
    .animation(.spring(duration: 0.3), value: state.combo > 0)
  }

  private var toastLayer: some View {
    VStack(spacing: 6) {
      Spacer().frame(height: 60)
      ForEach(store.toasts) { toast in
        VStack(spacing: 2) {
          Text(toast.title)
            .font(toast.tensor ? Theme.display(30) : Theme.display(20))
            .foregroundStyle(toast.tensor ? Theme.greenBright : Theme.bone)
            .shadow(color: Theme.green.opacity(0.9), radius: toast.tensor ? 18 : 8)
          if let sub = toast.subtitle {
            Text(sub.uppercased())
              .font(Theme.mono(11, weight: .bold)).tracking(1.5)
              .foregroundStyle(Theme.green)
          }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(Theme.black.opacity(0.7)))
        .transition(
          .asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
      }
      Spacer()
    }
    .allowsHitTesting(false)
    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: store.toasts)
  }

  private var controls: some View {
    HStack(spacing: 8) {
      ControlButton(symbol: "arrow.counterclockwise", label: "CCW") {
        store.rotate(clockwise: false)
      }
      ControlButton(symbol: "arrow.clockwise", label: "CW") { store.rotate(clockwise: true) }
      ControlButton(symbol: "arrow.triangle.swap", label: "HOLD", disabled: !state.canHold) {
        store.hold()
      }
      ControlButton(symbol: "arrow.down.to.line", label: "DROP", prominent: true) {
        store.hardDrop()
      }
    }
    .padding(.horizontal, 10)
  }
}

struct ControlButton: View {
  var symbol: String
  var label: String
  var disabled = false
  var prominent = false
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: symbol).font(.system(size: 18, weight: .bold))
        Text(label).font(Theme.mono(9, weight: .bold)).tracking(1.2)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 54)
      .foregroundStyle(prominent ? Theme.black : Theme.green)
      .background(RoundedRectangle(cornerRadius: 8).fill(prominent ? Theme.green : Theme.charcoal))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.green.opacity(0.5), lineWidth: 1))
      .shadow(color: Theme.green.opacity(prominent ? 0.5 : 0), radius: 10)
    }
    .buttonStyle(PressStyle())
    .disabled(disabled)
    .opacity(disabled ? 0.4 : 1)
    .accessibilityLabel(label)
  }
}

struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.93 : 1)
      .animation(.spring(response: 0.15, dampingFraction: 0.5), value: configuration.isPressed)
  }
}

/// Gesture surface over the die: tap rotates, drag moves, slow drag down soft-drops,
/// flick down hard-drops, flick up holds.
struct TouchLayer: View {
  @ObservedObject var store: GameStore
  @State private var startTime: Date?
  @State private var axis: Axis?
  @State private var stepX: CGFloat = 0
  @State private var stepY: CGFloat = 0
  @State private var didAct = false

  private enum Axis { case horizontal, vertical }

  var body: some View {
    GeometryReader { geo in
      let cell = geo.size.width / CGFloat(Board.width)
      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
              guard store.screen == .playing else { return }
              if startTime == nil {
                startTime = Date()
                stepX = 0
                stepY = 0
                axis = nil
                didAct = false
              }
              let tx = value.translation.width
              let ty = value.translation.height
              if axis == nil, hypot(tx, ty) > cell * 0.55 {
                axis = abs(tx) > abs(ty) * 1.2 ? .horizontal : .vertical
              }
              switch axis {
              case .horizontal:
                let cellsMoved = Int((tx - stepX) / (cell * 0.92))
                if cellsMoved != 0 {
                  for _ in 0..<abs(cellsMoved) {
                    if cellsMoved > 0 { store.moveRight() } else { store.moveLeft() }
                  }
                  stepX += CGFloat(cellsMoved) * cell * 0.92
                  didAct = true
                }
              case .vertical:
                if ty > 0 {
                  let rows = Int((ty - stepY) / (cell * 1.1))
                  if rows > 0 {
                    for _ in 0..<rows { store.softDropStep() }
                    stepY += CGFloat(rows) * cell * 1.1
                    didAct = true
                  }
                }
              case nil:
                break
              }
            }
            .onEnded { value in
              defer {
                startTime = nil
                axis = nil
              }
              guard store.screen == .playing, let start = startTime else { return }
              let duration = Date().timeIntervalSince(start)
              let ty = value.translation.height
              let flickY = value.predictedEndTranslation.height - ty
              if axis == nil, duration < 0.3 {
                store.rotate(clockwise: value.startLocation.x > geo.size.width * 0.28)
                return
              }
              if axis == .vertical {
                if ty < -cell * 1.5 {
                  store.hold()
                } else if flickY > cell * 2.5 || (ty > cell * 4 && duration < 0.28) {
                  store.hardDrop()
                }
              }
            }
        )
    }
  }
}

struct PauseOverlay: View {
  @ObservedObject var store: GameStore

  var body: some View {
    ZStack {
      Theme.black.opacity(0.82).ignoresSafeArea()
      VStack(spacing: 18) {
        Text("KERNEL SUSPENDED")
          .font(Theme.display(28)).foregroundStyle(Theme.greenBright)
          .shadow(color: Theme.green.opacity(0.8), radius: 12)
        Text("Streams idle · registers preserved")
          .font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.ash)
        VStack(spacing: 10) {
          Toggle(isOn: $store.soundEnabled) { Label("Synth audio", systemImage: "speaker.wave.2") }
          Toggle(isOn: $store.hapticsEnabled) { Label("Haptics", systemImage: "waveform.path") }
        }
        .tint(Theme.green)
        .font(Theme.mono(13))
        .foregroundStyle(Theme.bone)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        Button("RESUME") { store.resume() }.buttonStyle(NeonButtonStyle(prominent: true))
        Button("SAVE & EXIT") { store.quitToTitle() }.buttonStyle(NeonButtonStyle())
      }
      .padding(24)
      .frame(maxWidth: 320)
      .background(RoundedRectangle(cornerRadius: 12).fill(Theme.charcoal))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.green.opacity(0.6), lineWidth: 1))
      .shadow(color: Theme.green.opacity(0.35), radius: 30)
    }
    .transition(.opacity)
  }
}

struct GameOverOverlay: View {
  @ObservedObject var store: GameStore
  @FocusState private var nameFocused: Bool

  var body: some View {
    let s = store.engine.state
    ZStack {
      Theme.black.opacity(0.86).ignoresSafeArea()
      VStack(spacing: 14) {
        Text("THERMAL THROTTLE")
          .font(Theme.display(30)).foregroundStyle(Theme.amber)
          .shadow(color: Theme.amber.opacity(0.7), radius: 12)
        Text("Die saturated · kernel launch failed")
          .font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.ash)

        Text(ScoreFormat.compact(s.score))
          .font(Theme.display(48)).foregroundStyle(Theme.bone)
          .shadow(color: Theme.green.opacity(0.7), radius: 14)

        HStack(spacing: 14) {
          Stat(label: "Warps", value: "\(s.lines)")
          Stat(label: "Tensor", value: "\(s.tensorCores)")
          Stat(label: "T-spins", value: "\(s.tSpins)")
          Stat(label: "Clock", value: "L\(s.level)")
        }

        if store.runQualifies {
          VStack(spacing: 8) {
            Text("LEADERBOARD ENTRY").font(Theme.mono(10, weight: .bold)).tracking(1.5)
              .foregroundStyle(Theme.greenBright)
            HStack {
              TextField("SM name", text: $store.playerName)
                .font(Theme.mono(15, weight: .bold))
                .foregroundStyle(Theme.bone)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { store.submitScore() }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.black))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.6)))
              Button("COMMIT") {
                nameFocused = false
                store.submitScore()
              }
              .buttonStyle(NeonButtonStyle(prominent: true))
              .frame(width: 130)
            }
          }
        } else if let rank = store.lastRank {
          Text("RANKED #\(rank) ON THE DIE")
            .font(Theme.mono(13, weight: .bold)).tracking(1.5)
            .foregroundStyle(Theme.greenBright)
        }

        Button("RELAUNCH KERNEL") { store.newGame(startLevel: s.startLevel) }
          .buttonStyle(NeonButtonStyle(prominent: true))
        HStack(spacing: 10) {
          Button("RANKINGS") { store.showLeaderboard() }.buttonStyle(NeonButtonStyle())
          Button("TITLE") { store.backToTitle() }.buttonStyle(NeonButtonStyle())
        }
      }
      .padding(22)
      .frame(maxWidth: 340)
      .background(RoundedRectangle(cornerRadius: 12).fill(Theme.charcoal))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.green.opacity(0.6), lineWidth: 1))
      .shadow(color: Theme.green.opacity(0.35), radius: 30)
    }
    .transition(.opacity)
  }
}

struct Stat: View {
  var label: String
  var value: String
  var body: some View {
    VStack(spacing: 2) {
      Text(value).font(Theme.display(20)).foregroundStyle(Theme.bone)
      Text(label.uppercased()).font(Theme.mono(8, weight: .bold)).tracking(1.2).foregroundStyle(
        Theme.green)
    }
  }
}
