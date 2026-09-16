import SwiftUI

@main
struct FPSHeroApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .preferredColorScheme(.dark)
    }
  }
}

enum Screen {
  case title
  case tracks
  case game(Track)
  case results(ScoreRecord, Bool, GameState)
}

struct RootView: View {
  @State private var screen: Screen = .title
  private let store = ScoreStore.shared

  var body: some View {
    ZStack {
      Palette.black.ignoresSafeArea()
      CircuitBackground().ignoresSafeArea()
      switch screen {
      case .title:
        TitleView(store: store) {
          withAnimation(.easeInOut(duration: 0.35)) { screen = .tracks }
        }
        .transition(.opacity)
      case .tracks:
        TrackSelectView(store: store) { track in
          withAnimation(.easeInOut(duration: 0.3)) { screen = .game(track) }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
      case .game(let track):
        GameView(
          track: track,
          onFinish: { state in
            let grade = Grade.forAccuracy(state.accuracy)
            let record = ScoreRecord(
              trackId: track.id, score: state.score, grade: grade,
              maxCombo: state.maxCombo, accuracy: state.accuracy)
            let isRecord = store.record(record)
            withAnimation(.easeInOut(duration: 0.3)) {
              screen = .results(record, isRecord, state)
            }
          },
          onQuit: {
            withAnimation(.easeInOut(duration: 0.3)) { screen = .tracks }
          }
        )
        .transition(.opacity)
      case .results(let record, let isRecord, let finalState):
        ResultsView(
          record: record,
          isRecord: isRecord,
          state: finalState,
          onRetry: {
            if let track = Track.all.first(where: { $0.id == record.trackId }) {
              withAnimation(.easeInOut(duration: 0.3)) { screen = .game(track) }
            }
          },
          onTracks: {
            withAnimation(.easeInOut(duration: 0.3)) { screen = .tracks }
          }
        )
        .transition(.opacity)
      }
    }
  }
}

// MARK: - Title

struct TitleView: View {
  let store: ScoreStore
  var onBoot: () -> Void

  @State private var appeared = false
  @State private var fakeFPS = 238.0
  @State private var pulse = false
  @State private var soundOn = ScoreStore.shared.soundOn

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      VStack(spacing: 14) {
        Text("FPS")
          .font(.hero(86, .heavy))
          .foregroundStyle(Palette.green)
          .greenGlow(18)
          .offset(y: appeared ? 0 : 30)
          .opacity(appeared ? 1 : 0)
        Text("HERO")
          .font(.hero(64, .black))
          .foregroundStyle(.white)
          .tracking(18)
          .offset(y: appeared ? 0 : 30)
          .opacity(appeared ? 1 : 0)
        Text("A GPU-FLAVORED RHYTHM GAME")
          .font(.mono(13, .medium))
          .foregroundStyle(Palette.dim)
          .tracking(3)
          .opacity(appeared ? 1 : 0)
      }
      .animation(.spring(duration: 0.7).delay(0.1), value: appeared)

      Spacer()

      VStack(spacing: 10) {
        Text("\(Int(fakeFPS))")
          .font(.mono(44, .heavy))
          .foregroundStyle(Palette.green)
          .greenGlow(10)
          .contentTransition(.numericText())
        Text("FPS · TARGET 240 · VSYNC OFF")
          .font(.mono(11, .medium))
          .foregroundStyle(Palette.faint)
      }
      .opacity(appeared ? 1 : 0)

      Spacer()

      Button(action: onBoot) {
        Text("TAP TO BOOT")
          .font(.hero(20, .heavy))
          .tracking(4)
          .foregroundStyle(Palette.black)
          .padding(.horizontal, 44)
          .padding(.vertical, 16)
          .background(Palette.green)
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .greenGlow(pulse ? 22 : 6)
          .scaleEffect(pulse ? 1.04 : 1.0)
      }
      .opacity(appeared ? 1 : 0)

      HStack(spacing: 24) {
        if let best = store.overallBest {
          Text("BEST: \(best.score)")
            .font(.mono(12, .medium))
            .foregroundStyle(Palette.dim)
        }
        Text("RUNS: \(store.runs)")
          .font(.mono(12, .medium))
          .foregroundStyle(Palette.dim)
        Button {
          soundOn.toggle()
          store.soundOn = soundOn
        } label: {
          Image(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            .foregroundStyle(Palette.green)
        }
      }
      .padding(.top, 26)
      .opacity(appeared ? 1 : 0)
      .padding(.bottom, 54)
    }
    .onAppear {
      appeared = true
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
        pulse = true
      }
      Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
        var rng = SeededRandom(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        fakeFPS = 236 + rng.next() * 4
      }
    }
  }
}

// MARK: - Track select

struct TrackSelectView: View {
  let store: ScoreStore
  var onPick: (Track) -> Void

  private func spec(for track: Track) -> String {
    switch track.difficulty {
    case "chill": return "TDP: CHILL · \(Int(track.bpm)) CORES"
    case "hard": return "TDP: MAXED · \(Int(track.bpm)) CORES"
    default: return "TDP: BOOST · \(Int(track.bpm)) CORES"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("SELECT TRACK")
        .font(.hero(28, .heavy))
        .tracking(4)
        .foregroundStyle(.white)
        .padding(.top, 70)
        .padding(.horizontal, 24)
      Text("4 LANES · VERTEX → OUTPUT · 240 HZ")
        .font(.mono(11, .medium))
        .foregroundStyle(Palette.faint)
        .padding(.horizontal, 24)
        .padding(.top, 6)

      VStack(spacing: 16) {
        ForEach(Track.all, id: \.id) { track in
          TrackCard(track: track, spec: spec(for: track), best: store.best(for: track.id)) {
            onPick(track)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 30)

      Spacer()
      Text("CUDA CORES WARMED UP · DRIVER UPDATE AVAILABLE (JUST KIDDING)")
        .font(.mono(10, .medium))
        .foregroundStyle(Palette.faint)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 34)
    }
  }
}

struct TrackCard: View {
  let track: Track
  let spec: String
  let best: ScoreRecord?
  var onTap: () -> Void
  @State private var pressed = false

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 8) {
        Text(track.title.uppercased())
          .font(.hero(22, .heavy))
          .foregroundStyle(.white)
        Text(spec)
          .font(.mono(11, .medium))
          .foregroundStyle(Palette.green)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .overlay(
            RoundedRectangle(cornerRadius: 3)
              .stroke(Palette.green.opacity(0.6), lineWidth: 1)
          )
        if let best {
          Text("BEST \(best.score) · GRADE \(best.grade) · \(Int(best.accuracy * 100))%")
            .font(.mono(11, .medium))
            .foregroundStyle(Palette.dim)
        } else {
          Text("NO RUNS LOGGED · VRAM PRISTINE")
            .font(.mono(11, .medium))
            .foregroundStyle(Palette.faint)
        }
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(Palette.green)
    }
    .padding(20)
    .background(Palette.panel.opacity(0.8))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
    .scaleEffect(pressed ? 0.97 : 1)
    .animation(.spring(duration: 0.25), value: pressed)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in pressed = true }
        .onEnded { _ in
          pressed = false
          onTap()
        }
    )
  }
}
