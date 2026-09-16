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
              Toggle("", isOn: $store.soundEnabled)
                .labelsHidden()
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { store.soundEnabled.toggle() }
            HStack {
              Label("HAPTICS", systemImage: "waveform")
              Spacer()
              Toggle("", isOn: $store.hapticsEnabled)
                .labelsHidden()
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { store.hapticsEnabled.toggle() }
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
      Canvas { context, size in
        let columns = 16
        let rows = 2
        let gap = min(6.0, size.width / 100)
        let square = min(14.0, (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let width = CGFloat(columns) * square + CGFloat(columns - 1) * gap
        let height = CGFloat(rows) * square + gap
        let originX = max(0, (size.width - width) / 2)
        let originY = max(0, (size.height - height) / 2)
        let phase = Int(timeline.date.timeIntervalSinceReferenceDate * 8)
        for row in 0..<rows {
          for column in 0..<columns {
            let index = row * columns + column
            let lit = (index + phase) % 11 == 0
            let rect = CGRect(
              x: originX + CGFloat(column) * (square + gap),
              y: originY + CGFloat(row) * (square + gap),
              width: square,
              height: square
            )
            context.fill(
              Path(roundedRect: rect, cornerRadius: 2),
              with: .color(lit ? Theme.green : Theme.panel)
            )
            if lit {
              context.fill(
                Path(ellipseIn: rect.insetBy(dx: square * 0.2, dy: square * 0.2)),
                with: .color(Theme.green.opacity(0.8))
              )
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .clipped()
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
