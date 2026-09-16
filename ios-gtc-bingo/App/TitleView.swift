import SwiftUI

struct TitleView: View {
  @EnvironmentObject private var store: GameStore
  @State private var showHowToPlay = false

  var body: some View {
    NavigationStack {
      ZStack {
        CircuitBackground()
        ScrollView {
          VStack(spacing: 22) {
            Spacer(minLength: 34)
            Text("GTC")
              .font(.system(size: 82, weight: .black))
              .tracking(-4)
              .foregroundStyle(Theme.green)
              .neonGlow(radius: 18)
            Text("KEYNOTE BINGO")
              .font(.system(size: 26, weight: .heavy))
              .tracking(8)
              .foregroundStyle(.white)
              .minimumScaleFactor(0.7)
            Text("Unofficial fan game · zero network · 100% tropes")
              .font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(Theme.muted)
              .multilineTextAlignment(.center)

            DieShot()
              .frame(height: 92)
              .padding(.vertical, 12)

            NavigationLink {
              BoardView()
            } label: {
              Label("PLAY", systemImage: "play.fill")
            }
            .buttonStyle(GlowButtonStyle(filled: true))

            NavigationLink {
              ScoreboardView()
            } label: {
              Label("SCOREBOARD", systemImage: "trophy.fill")
            }
            .buttonStyle(GlowButtonStyle())

            Button("HOW TO PLAY") { showHowToPlay = true }
              .buttonStyle(GlowButtonStyle())

            HStack {
              Label(
                "SOUND",
                systemImage: store.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
              Spacer()
              Toggle("", isOn: $store.soundEnabled).labelsHidden().tint(Theme.green)
            }
            HStack {
              Label("HAPTICS", systemImage: "waveform")
              Spacer()
              Toggle("", isOn: $store.hapticsEnabled).labelsHidden().tint(Theme.green)
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 4)
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 28)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .sheet(isPresented: $showHowToPlay) {
        HowToPlayView()
          .presentationDetents([.medium, .large])
      }
    }
  }
}

private struct DieShot: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 0.08)) { timeline in
      let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 8)
      HStack(spacing: 7) {
        ForEach(0..<25, id: \.self) { index in
          RoundedRectangle(cornerRadius: 2)
            .fill((index + phase) % 9 == 0 ? Theme.green : Theme.panel)
            .frame(width: 14, height: 14)
            .shadow(color: Theme.green.opacity((index + phase) % 9 == 0 ? 0.7 : 0), radius: 6)
        }
      }
      .frame(maxWidth: .infinity)
    }
  }
}

private struct HowToPlayView: View {
  var body: some View {
    ZStack {
      Theme.black.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 18) {
        Text("HOW TO PLAY")
          .font(.system(size: 28, weight: .black))
          .tracking(2)
          .foregroundStyle(Theme.green)
        Text(
          "Watch the keynote. When a trope lands, tap the matching tile. The GPU free space is pre-marked. Complete any row, column, or diagonal to call BINGO."
        )
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white.opacity(0.86))
        Text(
          "Pass the phone between humans, add up to six players, and let the benchmarks decide the winner. New cards are deterministic in the rules engine, fresh in production."
        )
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Theme.muted)
        Spacer()
      }
      .padding(28)
    }
  }
}
