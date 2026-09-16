import CudaBlocksCore
import SwiftUI

struct TitleView: View {
  @ObservedObject var store: GameStore
  @State private var startLevel = 1
  @State private var appeared = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 20)
      logo
      Spacer(minLength: 16)
      dieShowcase
      Spacer(minLength: 16)
      stats
      Spacer(minLength: 20)
      buttons
      Spacer(minLength: 12)
      Text("A fan-made tribute · original art · offline")
        .font(Theme.mono(9)).tracking(1).foregroundStyle(Theme.ash.opacity(0.7))
        .padding(.bottom, 8)
    }
    .padding(.horizontal, 26)
    .onAppear {
      withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.1)) { appeared = true }
    }
  }

  private var logo: some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        Rectangle().fill(Theme.green).frame(width: 26, height: 3)
        Text("KERNEL LAUNCH PUZZLE")
          .font(Theme.mono(10, weight: .bold)).tracking(3).foregroundStyle(Theme.green)
        Rectangle().fill(Theme.green).frame(width: 26, height: 3)
      }
      Text("CUDA")
        .font(.system(size: 78, weight: .black, design: .default))
        .tracking(-2)
        .foregroundStyle(Theme.green)
        .shadow(color: Theme.green.opacity(0.85), radius: 22)
        .shadow(color: Theme.green.opacity(0.4), radius: 50)
      Text("BLOCKS")
        .font(.system(size: 46, weight: .heavy, design: .default))
        .tracking(9)
        .foregroundStyle(Theme.bone)
        .offset(y: -18)
    }
    .scaleEffect(appeared ? 1 : 0.85)
    .opacity(appeared ? 1 : 0)
  }

  private var dieShowcase: some View {
    TimelineView(.animation) { timeline in
      let t = timeline.date.timeIntervalSinceReferenceDate
      Canvas { ctx, size in
        let cell: CGFloat = 18
        let kernels: [(Kernel, Int, CGFloat, CGFloat, Double)] = [
          (.t, 0, 0.12, 0.2, 0), (.i, 1, 0.82, 0.05, 1.3), (.l, 2, 0.5, 0.55, 2.2),
          (.s, 1, 0.25, 0.7, 0.7), (.o, 0, 0.7, 0.62, 3.1), (.z, 3, 0.05, 0.75, 1.9),
        ]
        for (k, r, fx, fy, phase) in kernels {
          let bob = sin(t * 0.9 + phase) * 6
          let ox = size.width * fx
          let oy = size.height * fy + bob
          for c in k.cells(rotation: r) {
            let rect = CGRect(
              x: ox + CGFloat(c.col) * cell, y: oy + CGFloat(c.row) * cell, width: cell - 2,
              height: cell - 2)
            var g = ctx
            g.addFilter(.blur(radius: 6))
            g.fill(
              Path(roundedRect: rect, cornerRadius: 3),
              with: .color(Theme.color(for: k).opacity(0.5)))
            ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Theme.color(for: k)))
            ctx.fill(
              Path(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 1),
              with: .color(Theme.black.opacity(0.35)))
          }
        }
        // Scanline sweep.
        let sweep = (t * 0.25).truncatingRemainder(dividingBy: 1) * size.height
        var line = Path()
        line.addRect(CGRect(x: 0, y: sweep, width: size.width, height: 2))
        ctx.fill(line, with: .color(Theme.greenBright.opacity(0.35)))
      }
    }
    .frame(height: 150)
    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.black.opacity(0.65)))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.green.opacity(0.4), lineWidth: 1))
    .overlay(alignment: .topLeading) {
      Text("10×20 SILICON DIE · 7 KERNEL TYPES")
        .font(Theme.mono(8, weight: .bold)).tracking(1.5).foregroundStyle(Theme.green.opacity(0.8))
        .padding(8)
    }
    .opacity(appeared ? 1 : 0)
  }

  private var stats: some View {
    HStack(spacing: 10) {
      DiePanel(title: "Best") {
        Text(ScoreFormat.compact(store.leaderboard.best)).font(Theme.display(18)).foregroundStyle(
          Theme.bone)
      }
      DiePanel(title: "Warps") {
        Text(ScoreFormat.compact(store.lifetimeWarps)).font(Theme.display(18)).foregroundStyle(
          Theme.bone)
      }
      DiePanel(title: "Tensor cores") {
        Text("\(store.lifetimeTensorCores)").font(Theme.display(18)).foregroundStyle(
          Theme.greenBright)
      }
    }
    .opacity(appeared ? 1 : 0)
  }

  private var buttons: some View {
    VStack(spacing: 10) {
      HStack {
        Text("BOOST CLOCK").font(Theme.mono(10, weight: .bold)).tracking(1.5).foregroundStyle(
          Theme.green)
        Spacer()
        Stepper(value: $startLevel, in: 1...15) {
          Text("Level \(startLevel) · \(ScoreFormat.clock(level: startLevel))")
            .font(Theme.mono(12)).foregroundStyle(Theme.bone)
        }
        .tint(Theme.green)
      }
      .padding(.horizontal, 4)
      if store.hasSavedRun {
        Button("RESUME KERNEL") { store.resumeSavedRun() }.buttonStyle(
          NeonButtonStyle(prominent: true))
        Button("LAUNCH NEW KERNEL") { store.newGame(startLevel: startLevel) }.buttonStyle(
          NeonButtonStyle())
      } else {
        Button("LAUNCH KERNEL") { store.newGame(startLevel: startLevel) }.buttonStyle(
          NeonButtonStyle(prominent: true))
      }
      Button("LEADERBOARD") { store.showLeaderboard() }.buttonStyle(NeonButtonStyle())
    }
    .offset(y: appeared ? 0 : 30)
    .opacity(appeared ? 1 : 0)
  }
}

struct LeaderboardView: View {
  @ObservedObject var store: GameStore

  var body: some View {
    VStack(spacing: 14) {
      HStack {
        Button {
          store.backToTitle()
        } label: {
          Label("Back", systemImage: "chevron.left").font(Theme.mono(13, weight: .bold))
        }
        .foregroundStyle(Theme.green)
        Spacer()
        if !store.leaderboard.entries.isEmpty {
          Button("WIPE") { store.clearLeaderboard() }
            .font(Theme.mono(11, weight: .bold)).foregroundStyle(Theme.amber)
        }
      }
      .padding(.horizontal, 20)
      Text("TOP STREAMING MULTIPROCESSORS")
        .font(Theme.mono(10, weight: .bold)).tracking(2.5).foregroundStyle(Theme.green)
      Text("LEADERBOARD").font(Theme.display(34)).foregroundStyle(Theme.bone)
        .shadow(color: Theme.green.opacity(0.6), radius: 12)

      if store.leaderboard.entries.isEmpty {
        Spacer()
        VStack(spacing: 8) {
          Image(systemName: "cpu").font(.system(size: 44)).foregroundStyle(Theme.green.opacity(0.6))
          Text("No kernels profiled yet.").font(Theme.mono(13)).foregroundStyle(Theme.ash)
          Text("Clear a row to dispatch your first warp.").font(Theme.mono(11)).foregroundStyle(
            Theme.ash.opacity(0.7))
        }
        Spacer()
      } else {
        ScrollView {
          VStack(spacing: 8) {
            ForEach(Array(store.leaderboard.entries.enumerated()), id: \.element.id) { i, e in
              HStack(spacing: 12) {
                Text(String(format: "%02d", i + 1))
                  .font(Theme.mono(14, weight: .bold))
                  .foregroundStyle(i == 0 ? Theme.greenBright : Theme.green)
                  .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                  Text(e.name).font(Theme.mono(15, weight: .bold)).foregroundStyle(Theme.bone)
                  Text("L\(e.level) · \(e.lines) warps · \(e.tensorCores) tensor")
                    .font(Theme.mono(9)).foregroundStyle(Theme.ash)
                }
                Spacer()
                Text(ScoreFormat.compact(e.score))
                  .font(Theme.display(20)).foregroundStyle(i == 0 ? Theme.greenBright : Theme.bone)
              }
              .padding(.horizontal, 14).padding(.vertical, 10)
              .background(RoundedRectangle(cornerRadius: 8).fill(Theme.charcoal))
              .overlay(
                RoundedRectangle(cornerRadius: 8).stroke(
                  Theme.green.opacity(i == 0 ? 0.8 : 0.25), lineWidth: 1)
              )
              .shadow(color: Theme.green.opacity(i == 0 ? 0.35 : 0), radius: 10)
            }
          }
          .padding(.horizontal, 20)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.top, 8)
  }
}
