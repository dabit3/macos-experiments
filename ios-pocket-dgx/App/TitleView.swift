import SwiftUI

struct TitleView: View {
  @EnvironmentObject var store: AppStore
  @State private var appeared = false

  var body: some View {
    ZStack {
      CircuitBackdrop()
      VStack(spacing: 0) {
        Spacer(minLength: 24)
        HeroRack()
          .frame(height: 210)
          .scaleEffect(appeared ? 1 : 0.9)
          .opacity(appeared ? 1 : 0)
        VStack(spacing: 6) {
          Text("POCKET").font(.label(15)).tracking(9).foregroundStyle(Palette.mint)
          Text("DGX").font(.display(78)).tracking(2).foregroundStyle(Palette.cream)
            .shadow(color: Palette.green.opacity(0.65), radius: 22)
          Text("Drop a supercomputer in your living room.")
            .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.muted)
        }
        .padding(.top, 8)
        .offset(y: appeared ? 0 : 16)
        .opacity(appeared ? 1 : 0)
        Spacer(minLength: 20)
        VStack(spacing: 12) {
          ForEach(RigKind.allCases, id: \.self) { kind in
            RigCard(kind: kind, selected: store.kind == kind) { store.enter(kind) }
          }
        }
        .padding(.horizontal, 22)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        Spacer(minLength: 18)
        StatsPlaque(stats: store.stats)
          .padding(.horizontal, 22)
          .opacity(appeared ? 1 : 0)
        HStack {
          Text(store.caption).font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.7)
          Spacer()
          Button {
            store.sound.toggle()
          } label: {
            Image(systemName: store.sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(store.sound ? Palette.mint : Palette.muted)
              .frame(width: 40, height: 36)
          }
          .accessibilityLabel(store.sound ? "Mute sound" : "Enable sound")
        }
        .padding(.horizontal, 26)
        .padding(.top, 10)
        .padding(.bottom, 8)
      }
    }
    .onAppear {
      withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) { appeared = true }
    }
  }
}

/// Selectable card for one of the two toys.
struct RigCard: View {
  var kind: RigKind
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        ZStack {
          Chamfer(cut: 8).fill(Palette.charcoal)
          Chamfer(cut: 8).stroke(Palette.green.opacity(0.5), lineWidth: 1)
          Image(systemName: kind == .rack ? "server.rack" : "cpu.fill")
            .font(.system(size: 26, weight: .medium)).foregroundStyle(Palette.mint)
        }
        .frame(width: 58, height: 58)
        VStack(alignment: .leading, spacing: 3) {
          Text(kind.title.uppercased()).font(.label(17)).tracking(2).foregroundStyle(Palette.cream)
          Text(kind.subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
          Text("\(Format.tokens(kind.peakTokensPerSecond)) tok/s · \(Format.watts(kind.peakWatts))")
            .font(.mono(11)).foregroundStyle(Palette.green)
        }
        Spacer()
        Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold)).foregroundStyle(
          Palette.green)
      }
      .padding(14)
      .background(Chamfer(cut: 12).fill(Palette.ink.opacity(0.7)))
      .overlay(
        Chamfer(cut: 12).stroke(
          Palette.green.opacity(selected ? 0.9 : 0.3), lineWidth: selected ? 1.5 : 1)
      )
      .shadow(color: Palette.green.opacity(selected ? 0.35 : 0), radius: 14)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Launch \(kind.title)")
  }
}

struct StatsPlaque: View {
  var stats: RigStats
  var body: some View {
    HStack(spacing: 0) {
      stat("RANK", stats.rank)
      divider
      stat("BOOTS", "\(stats.powerOns)")
      divider
      stat("PHOTOS", "\(stats.photos)")
      divider
      stat("TOKENS", Format.tokens(stats.totalTokens))
    }
    .padding(.vertical, 10)
    .background(Chamfer(cut: 8).fill(Palette.ink.opacity(0.6)))
    .overlay(Chamfer(cut: 8).stroke(Palette.green.opacity(0.25), lineWidth: 1))
  }
  private var divider: some View {
    Rectangle().fill(Palette.green.opacity(0.25)).frame(width: 1, height: 26)
  }
  private func stat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 3) {
      Text(label).font(.label(9)).tracking(2).foregroundStyle(Palette.muted)
      Text(value).font(.mono(12)).foregroundStyle(Palette.cream).lineLimit(1).minimumScaleFactor(
        0.6)
    }
    .frame(maxWidth: .infinity)
  }
}

/// Animated 2D rack: blades with breathing LED bars and a token stream rising above.
struct HeroRack: View {
  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      Canvas { context, size in
        let rackWidth = size.width * 0.34
        let rackHeight = size.height * 0.86
        let origin = CGPoint(x: size.width / 2 - rackWidth / 2, y: size.height - rackHeight - 4)
        let glowPulse = 0.6 + 0.4 * sin(time * 2.4)
        // Floor glow.
        let halo = CGRect(
          x: origin.x - rackWidth * 0.7, y: size.height - 26, width: rackWidth * 2.4, height: 40)
        context.fill(
          Path(ellipseIn: halo),
          with: .radialGradient(
            Gradient(colors: [Palette.green.opacity(0.35 * glowPulse), .clear]),
            center: CGPoint(x: halo.midX, y: halo.midY), startRadius: 0, endRadius: halo.width / 2))
        // Cabinet.
        let body = CGRect(origin: origin, size: CGSize(width: rackWidth, height: rackHeight))
        context.fill(Path(roundedRect: body, cornerRadius: 6), with: .color(Palette.slate))
        context.stroke(
          Path(roundedRect: body, cornerRadius: 6), with: .color(Palette.green.opacity(0.5)),
          lineWidth: 1.2)
        for side in [body.minX - 3, body.maxX + 1] {
          context.fill(
            Path(
              CGRect(x: side, y: body.minY + rackHeight * 0.1, width: 2, height: rackHeight * 0.8)),
            with: .color(Palette.green.opacity(0.35 + 0.35 * glowPulse)))
        }
        // Blades.
        let blades = 8
        let bladeHeight = rackHeight * 0.085
        let gap = (rackHeight - CGFloat(blades) * bladeHeight) / CGFloat(blades + 1)
        for index in 0..<blades {
          let y = body.minY + gap + CGFloat(index) * (bladeHeight + gap)
          let blade = CGRect(x: body.minX + 7, y: y, width: rackWidth - 14, height: bladeHeight)
          context.fill(Path(roundedRect: blade, cornerRadius: 2), with: .color(Palette.charcoal))
          for fan in 0..<3 {
            let radius = bladeHeight * 0.34
            let center = CGPoint(
              x: blade.minX + blade.width * (0.2 + 0.3 * CGFloat(fan)), y: blade.midY - 1)
            context.stroke(
              Path(
                ellipseIn: CGRect(
                  x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
              ),
              with: .color(Palette.muted.opacity(0.5)), lineWidth: 1)
            let spin = time * 9 + Double(index) * 0.7
            for spoke in 0..<3 {
              let angle = spin + Double(spoke) * 2 * .pi / 3
              var path = Path()
              path.move(to: center)
              path.addLine(
                to: CGPoint(
                  x: center.x + cos(angle) * radius * 0.85, y: center.y + sin(angle) * radius * 0.85
                ))
              context.stroke(path, with: .color(Palette.muted.opacity(0.6)), lineWidth: 1.4)
            }
          }
          let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(time * 3 + Double(index) * 0.8))
          let bar = CGRect(
            x: blade.minX + 4, y: blade.maxY - 3.5, width: blade.width - 8, height: 2)
          context.fill(Path(bar), with: .color(Palette.green.opacity(pulse)))
        }
        // Rising token stream.
        var random = SeededRandom(state: 31)
        for index in 0..<26 {
          let speed = 18 + random.next() * 26
          let lane = random.next()
          let offset = random.next() * 200
          let progress = ((time * speed + offset).truncatingRemainder(dividingBy: 160)) / 160
          let x = body.minX + rackWidth * (0.1 + lane * 0.8) + sin(time + Double(index)) * 4
          let y = body.minY - 6 - progress * 70
          let alpha = (1 - progress) * 0.9
          let size = 2 + random.next() * 2.5
          context.fill(
            Path(roundedRect: CGRect(x: x, y: y, width: size, height: size), cornerRadius: 0.5),
            with: .color(Palette.mint.opacity(alpha)))
        }
      }
    }
    .accessibilityHidden(true)
  }
}
