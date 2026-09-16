import SwiftUI

struct TitleView: View {
  @EnvironmentObject var store: GameStore
  var namespace: Namespace.ID
  @State private var appeared = false
  @State private var showSettings = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      logo
        .padding(.bottom, 26)
      Text("Route the lanes. Feed the GPU.")
        .font(.label(16))
        .tracking(1)
        .foregroundStyle(Palette.mist)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)
      Spacer()
      stats
        .padding(.bottom, 22)
      VStack(spacing: 12) {
        Button(
          store.progress.solvedCount == 0
            ? "Power on" : "Continue · Level \(store.progress.nextLevel)"
        ) {
          if store.progress.solvedCount == 0 {
            store.start(level: 1)
          } else {
            store.start(level: store.progress.nextLevel)
          }
        }
        .buttonStyle(NeonButtonStyle())
        .matchedGeometryEffect(id: "primary", in: namespace)
        HStack(spacing: 12) {
          Button("Levels") { store.showLevels() }.buttonStyle(NeonButtonStyle(filled: false))
          Button {
            showSettings = true
            Haptics.tap()
          } label: {
            Label("Options", systemImage: "slider.horizontal.3")
          }
          .buttonStyle(NeonButtonStyle(tint: Palette.mist, filled: false))
        }
      }
      .padding(.horizontal, 28)
      .opacity(appeared ? 1 : 0)
      .offset(y: appeared ? 0 : 30)
      .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: appeared)
      Text("A fan-made tribute. Not affiliated with NVIDIA.")
        .font(.mono(10))
        .foregroundStyle(Palette.steel)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
    .onAppear { appeared = true }
    .sheet(isPresented: $showSettings) { SettingsSheet() }
  }

  private var logo: some View {
    VStack(spacing: 6) {
      TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { tl in
        let t = tl.date.timeIntervalSinceReferenceDate
        LogoCables(phase: t)
          .frame(height: 118)
          .padding(.horizontal, 30)
      }
      .opacity(appeared ? 1 : 0)
      .scaleEffect(appeared ? 1 : 0.9)
      .animation(.spring(response: 0.7, dampingFraction: 0.7), value: appeared)
      Text("CABLE")
        .font(.display(60)).tracking(8)
        .foregroundStyle(Palette.paper)
      Text("CHAOS")
        .font(.display(60)).tracking(8)
        .foregroundStyle(Palette.green)
        .shadow(color: Palette.green.opacity(0.85), radius: appeared ? 20 : 2)
        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: appeared)
        .padding(.top, -22)
    }
    .opacity(appeared ? 1 : 0)
    .offset(y: appeared ? 0 : 20)
    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15), value: appeared)
  }

  private var stats: some View {
    HStack(spacing: 22) {
      stat("SOLVED", "\(store.progress.solvedCount)/\(LevelCatalog.count)")
      Rectangle().fill(Palette.steel).frame(width: 1, height: 30)
      HStack(spacing: 6) {
        Image(systemName: "star.fill").foregroundStyle(Palette.green).font(
          .system(size: 13, weight: .bold))
        stat("STARS", "\(store.progress.totalStars)/\(LevelCatalog.count * 3)")
      }
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 12)
    .background(
      Capsule().fill(Palette.charcoal.opacity(0.85))
        .overlay(Capsule().strokeBorder(Palette.green.opacity(0.35), lineWidth: 1))
    )
    .opacity(appeared ? 1 : 0)
    .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.mono(16, weight: .bold)).foregroundStyle(Palette.paper)
      Text(label).font(.mono(9)).tracking(1.5).foregroundStyle(Palette.mist)
    }
  }
}

/// Animated hero: a PSU on the left, a fan on the right, and three lanes routing between.
struct LogoCables: View {
  let phase: Double
  var body: some View {
    Canvas { ctx, size in
      let w = size.width
      let h = size.height
      let lanes: [(CGFloat, Color)] = [
        (0.25, Palette.green), (0.5, Palette.amber), (0.75, Palette.green),
      ]
      for (i, lane) in lanes.enumerated() {
        var path = Path()
        let y = h * lane.0
        let mid = w * (0.38 + 0.1 * CGFloat(i))
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: mid - 18, y: y))
        let targetY = h * 0.5 + CGFloat(i - 1) * 14
        path.addQuadCurve(
          to: CGPoint(x: mid + 18, y: targetY), control: CGPoint(x: mid, y: (y + targetY) / 2))
        path.addLine(to: CGPoint(x: w - 62, y: targetY))
        ctx.stroke(
          path, with: .color(Palette.ink),
          style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
        ctx.stroke(
          path, with: .color(lane.1),
          style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        var glow = ctx
        glow.addFilter(.shadow(color: lane.1.opacity(0.8), radius: 8))
        glow.stroke(
          path, with: .color(.white.opacity(0.9)),
          style: StrokeStyle(
            lineWidth: 3, lineCap: .round, dash: [6, 16],
            dashPhase: -CGFloat(phase * 60) - CGFloat(i) * 7))
      }
      // PSU block
      let psu = CGRect(x: 0, y: h * 0.15, width: 46, height: h * 0.7)
      ctx.fill(Path(roundedRect: psu, cornerRadius: 8), with: .color(Palette.steel))
      ctx.stroke(
        Path(roundedRect: psu, cornerRadius: 8), with: .color(Palette.green.opacity(0.7)),
        lineWidth: 1.5)
      for i in 0..<4 {
        let dot = CGRect(x: 10 + CGFloat(i) * 7, y: h * 0.78, width: 4, height: 4)
        ctx.fill(Path(ellipseIn: dot), with: .color(Palette.green))
      }
      // GPU fan
      let center = CGPoint(x: w - 34, y: h * 0.5)
      let card = CGRect(x: w - 68, y: h * 0.1, width: 68, height: h * 0.8)
      ctx.fill(Path(roundedRect: card, cornerRadius: 10), with: .color(Palette.charcoal))
      var glowCtx = ctx
      glowCtx.addFilter(.shadow(color: Palette.green.opacity(0.7), radius: 10))
      glowCtx.stroke(
        Path(roundedRect: card, cornerRadius: 10), with: .color(Palette.green), lineWidth: 1.5)
      ctx.stroke(
        Path(ellipseIn: CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)),
        with: .color(Palette.steel), lineWidth: 2)
      for i in 0..<5 {
        let angle = CGFloat(i) * (.pi * 2 / 5) + CGFloat(phase * 5)
        var blade = Path()
        blade.move(to: center)
        blade.addLine(to: CGPoint(x: center.x + cos(angle) * 20, y: center.y + sin(angle) * 20))
        ctx.stroke(
          blade, with: .color(Palette.green), style: StrokeStyle(lineWidth: 5, lineCap: .round))
      }
      ctx.fill(
        Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)),
        with: .color(Palette.ink))
    }
  }
}

struct SettingsSheet: View {
  @EnvironmentObject var store: GameStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirmReset = false
  var body: some View {
    ZStack {
      Palette.charcoal.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 22) {
        HStack {
          Text("OPTIONS").font(.display(24)).tracking(3).foregroundStyle(Palette.green)
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(
              Palette.mist
            )
            .frame(width: 36, height: 36).background(Circle().fill(Palette.slate))
          }
        }
        toggle(
          "Sound", detail: "Synthesized clicks, sizzle and the boot chime.",
          icon: "speaker.wave.2.fill", on: store.progress.soundEnabled
        ) { store.toggleSound() }
        toggle(
          "Haptics", detail: "Taps, connections and meltdowns you can feel.",
          icon: "iphone.radiowaves.left.and.right", on: store.progress.hapticsEnabled
        ) { store.toggleHaptics() }
        Divider().overlay(Palette.steel)
        VStack(alignment: .leading, spacing: 8) {
          Text("HOW TO PLAY").font(.mono(11)).tracking(2).foregroundStyle(Palette.mist)
          rule("Tap any cable tile to rotate it a quarter turn clockwise.")
          rule("Route every PSU connector to its matching GPU port before the timer hits zero.")
          rule("Green = 12VHPWR power. Amber = PCIe lane. Mixing them shorts the board.")
          rule(
            "Cables beside a hot chip glow orange while powered, then melt. Reroute or depower them."
          )
          rule("Stars: solve it, keep 40% of the clock, and stay near par.")
        }
        Spacer()
        Button(confirmReset ? "Tap again to wipe progress" : "Reset progress") {
          if confirmReset {
            store.resetProgress()
            confirmReset = false
          } else {
            confirmReset = true
          }
        }
        .buttonStyle(NeonButtonStyle(tint: Palette.red, filled: confirmReset))
      }
      .padding(24)
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private func toggle(
    _ title: String, detail: String, icon: String, on: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(
          on ? Palette.green : Palette.steel
        ).frame(width: 30)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.label(16)).foregroundStyle(Palette.paper)
          Text(detail).font(.label(12)).foregroundStyle(Palette.mist)
        }
        Spacer()
        Capsule().fill(on ? Palette.green : Palette.steel).frame(width: 46, height: 26)
          .overlay(alignment: on ? .trailing : .leading) {
            Circle().fill(Palette.ink).frame(width: 20, height: 20).padding(3)
          }
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: on)
      }
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.slate.opacity(0.7)))
    }
    .buttonStyle(.plain)
  }

  private func rule(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Circle().fill(Palette.green).frame(width: 6, height: 6).padding(.top, 6)
      Text(text).font(.label(13)).foregroundStyle(Palette.paper.opacity(0.9))
    }
  }
}
