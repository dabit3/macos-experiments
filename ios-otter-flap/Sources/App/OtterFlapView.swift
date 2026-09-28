import SwiftUI

struct OtterFlapView: View {
  @StateObject private var store = FlapStore()
  @State private var touching = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        RiverCanvas(engine: store.engine)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in
                if !touching {
                  touching = true
                  store.tap()
                }
              }
              .onEnded { _ in touching = false }
          )
        overlay
      }
      .onAppear { store.configure(size: proxy.size) }
      .onChange(of: proxy.size) { _, size in store.configure(size: size) }
    }
    .ignoresSafeArea()
    .background(Palette.skyTop)
  }

  @ViewBuilder private var overlay: some View {
    let engine = store.engine
    VStack(spacing: 0) {
      if engine.phase != .ready {
        HStack {
          Spacer()
          ChunkyText(text: "\(engine.score)", size: 72)
            .scaleEffect(1 + max(0, 0.25 - (engine.time - engine.lastScoreTime)) * 1.2)
          Spacer()
        }
        .overlay(alignment: .trailing) {
          if engine.shells > 0 {
            Label("\(engine.shells)", systemImage: "seal.fill")
              .font(.system(size: 18, weight: .heavy, design: .rounded))
              .foregroundStyle(Palette.shellDark)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Capsule().fill(Palette.card.opacity(0.9)))
              .padding(.trailing, 18)
          }
        }
        .padding(.top, 70)
        .allowsHitTesting(false)
      }
      switch engine.phase {
      case .ready: readyPanel
      case .over:
        Spacer()
        resultsCard
        Spacer()
      default: Spacer()
      }
    }
    .overlay(alignment: .topTrailing) {
      if engine.phase == .ready || engine.phase == .over {
        Button(action: store.toggleSound) {
          Image(systemName: store.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Palette.cardInk)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Palette.card.opacity(0.9)))
        }
        .accessibilityLabel(store.soundEnabled ? "Mute sound" : "Unmute sound")
        .padding(.top, 60)
        .padding(.trailing, 18)
      }
    }
    .animation(.spring(duration: 0.35), value: engine.phase)
  }

  private var readyPanel: some View {
    VStack(spacing: 14) {
      Spacer().frame(height: 120)
      ChunkyText(text: "Otter Flap", size: 58)
      Spacer()
      Label("Tap to paddle", systemImage: "hand.tap.fill")
        .font(.system(size: 22, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .shadow(color: Palette.cardInk, radius: 0, y: 2)
        .shadow(color: Palette.cardInk.opacity(0.6), radius: 3)
        .scaleEffect(1 + sin(engine.time * 4) * 0.05)
      Text("Paddle through the driftwood.\nGrab shells, dodge logs.")
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .multilineTextAlignment(.center)
        .foregroundStyle(Palette.cardInk)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card.opacity(0.85)))
      if store.best > 0 {
        Text("Best \(store.best)")
          .font(.system(size: 16, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          .background(Capsule().fill(Palette.accent))
      }
      Spacer().frame(height: 170)
    }
    .allowsHitTesting(false)
    .transition(.opacity)
  }

  private var engine: FlapEngine { store.engine }

  private var resultsCard: some View {
    VStack(spacing: 18) {
      ChunkyText(text: "Splash!", size: 48)
      VStack(spacing: 14) {
        HStack(alignment: .center, spacing: 20) {
          medal
          VStack(alignment: .trailing, spacing: 8) {
            stat("Score", engine.score)
            stat("Best", store.best)
            stat("Shells", engine.shells)
          }
        }
        if store.newBest {
          Text("New best!")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Palette.shellDark))
        }
      }
      .padding(22)
      .background(
        RoundedRectangle(cornerRadius: 24).fill(Palette.card)
          .shadow(color: Palette.cardInk.opacity(0.35), radius: 0, x: 0, y: 6)
      )
      PillButton(title: "Paddle again", icon: "arrow.counterclockwise", action: store.restart)
    }
    .padding(.horizontal, 30)
    .transition(.scale(scale: 0.8).combined(with: .opacity))
  }

  private var medal: some View {
    let name = FlapEngine.medal(for: engine.score)
    let color: Color =
      switch name {
      case "Pearl": Color(hex: 0xF4ECFF)
      case "Gold": Color(hex: 0xF6C343)
      case "Silver": Color(hex: 0xC9D3DC)
      case "Bronze": Color(hex: 0xD49060)
      default: Color(hex: 0xE9DCC8)
      }
    return VStack(spacing: 6) {
      ZStack {
        Circle().fill(color).frame(width: 74, height: 74)
        Circle().stroke(Palette.cardInk.opacity(0.25), lineWidth: 4).frame(width: 74, height: 74)
        Image(systemName: name == nil ? "drop.fill" : "star.fill")
          .font(.system(size: 30, weight: .bold))
          .foregroundStyle(name == nil ? Palette.water.opacity(0.6) : .white)
      }
      Text(name ?? "No medal")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(Palette.cardInk.opacity(0.7))
    }
  }

  private func stat(_ label: String, _ value: Int) -> some View {
    HStack(spacing: 14) {
      Text(label.uppercased())
        .font(.system(size: 13, weight: .heavy, design: .rounded))
        .foregroundStyle(Palette.accent)
      Text("\(value)")
        .font(.system(size: 26, weight: .black, design: .rounded))
        .foregroundStyle(Palette.cardInk)
        .monospacedDigit()
        .frame(minWidth: 50, alignment: .trailing)
    }
  }
}
