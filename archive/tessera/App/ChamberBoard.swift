import SwiftUI

struct BoardLayout {
  let size: CGSize
  var step: CGFloat { min(size.width / 8.4, size.height / 10.3) }
  func point(_ cell: Cell) -> CGPoint {
    CGPoint(
      x: (size.width - 6 * step) / 2 + CGFloat(cell.x) * step,
      y: (size.height - 8 * step) / 2 + CGFloat(cell.y) * step)
  }
}

struct ChamberBoard: View {
  let chamber: Chamber
  let state: ChamberState
  let trace: Trace
  let selected: String?
  let rotate: (Optic) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let layout = BoardLayout(size: geometry.size)
      ZStack {
        architecture(layout)
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { timeline in
          beams(layout, time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
        }.allowsHitTesting(false).accessibilityHidden(true)
        ForEach(chamber.receivers) { receiver in
          receiverView(receiver, lit: trace.powered.contains(receiver.id), size: layout.step)
            .position(layout.point(receiver.cell))
        }
        source(size: layout.step)
          .position(layout.point(chamber.source))
        ForEach(chamber.optics) { optic in
          Button {
            rotate(optic)
          } label: {
            opticView(optic, size: layout.step)
              .frame(width: max(44, layout.step + 5), height: max(44, layout.step + 5))
              .contentShape(Rectangle())
          }
          .buttonStyle(OpticButtonStyle())
          .position(layout.point(optic.cell))
          .accessibilityLabel("\(optic.kind == .mirror ? "Mirror" : "Prism") \(optic.id)")
          .accessibilityValue(
            optic.kind == .mirror
              ? (state.orientations[optic.id] == 0 ? "slash" : "backslash")
              : ["right", "down", "left", "up"][state.orientations[optic.id] ?? 0]
          )
          .accessibilityHint("Tap to rotate clockwise")
          .accessibilityIdentifier("optic-\(optic.id)")
        }
      }
    }
    .background {
      RoundedRectangle(cornerRadius: 26)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.055, green: 0.08, blue: 0.105),
              Color(red: 0.025, green: 0.044, blue: 0.065),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 14)
    }
    .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.065), lineWidth: 1))
  }

  private func architecture(_ layout: BoardLayout) -> some View {
    Canvas { context, size in
      let step = layout.step
      for x in 0..<7 {
        for y in 0..<9 {
          let point = layout.point(Cell(x, y))
          let rect = CGRect(
            x: point.x - step * 0.4, y: point.y - step * 0.4,
            width: step * 0.8, height: step * 0.8)
          let tile = Path(roundedRect: rect, cornerRadius: 5)
          context.fill(tile, with: .color(.white.opacity((x + y) % 2 == 0 ? 0.017 : 0.009)))
          context.fill(
            Path(ellipseIn: CGRect(x: point.x - 0.7, y: point.y - 0.7, width: 1.4, height: 1.4)),
            with: .color(Palette.muted.opacity(0.35)))
        }
      }
      for cell in chamber.walls {
        let point = layout.point(cell)
        let rect = CGRect(
          x: point.x - step * 0.43, y: point.y - step * 0.43,
          width: step * 0.86, height: step * 0.86)
        context.fill(
          Path(roundedRect: rect.offsetBy(dx: 2, dy: 5), cornerRadius: 4),
          with: .color(.black.opacity(0.45)))
        context.fill(
          Path(roundedRect: rect, cornerRadius: 4),
          with: .linearGradient(
            Gradient(colors: [
              Color(red: 0.14, green: 0.18, blue: 0.21),
              Color(red: 0.06, green: 0.09, blue: 0.12),
            ]),
            startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        var edge = Path()
        edge.move(to: CGPoint(x: rect.minX + 4, y: rect.minY))
        edge.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
        context.stroke(edge, with: .color(.white.opacity(0.13)), lineWidth: 1)
      }
      for x in 0..<7 {
        let point = layout.point(Cell(x, 0))
        context.draw(
          Text(String(UnicodeScalar(65 + x)!)).font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Palette.muted),
          at: CGPoint(x: point.x, y: 14))
      }
      for y in 0..<9 {
        let point = layout.point(Cell(0, y))
        context.draw(
          Text("\(y + 1)").font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Palette.muted),
          at: CGPoint(x: size.width - 12, y: point.y))
      }
      context.draw(
        Text("OPTICAL STUDY  /  \(String(format: "%02d", chamber.id + 1))")
          .font(.system(size: 6, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.45)),
        at: CGPoint(x: size.width / 2, y: size.height - 12))
    }.accessibilityHidden(true)
  }

  private func beams(_ layout: BoardLayout, time: Double) -> some View {
    Canvas { context, _ in
      for beam in trace.beams {
        let start = layout.point(beam.start)
        let end = layout.point(beam.end)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.drawLayer { glow in
          glow.addFilter(.blur(radius: 6))
          glow.stroke(path, with: .color(beam.color.tint.opacity(0.25)), lineWidth: 8)
        }
        context.stroke(path, with: .color(beam.color.tint.opacity(0.22)), lineWidth: 5)
        context.stroke(path, with: .color(beam.color.tint.opacity(0.9)), lineWidth: 1.4)
        let phase = (time * 0.6).truncatingRemainder(dividingBy: 1)
        let point = CGPoint(
          x: start.x + (end.x - start.x) * phase,
          y: start.y + (end.y - start.y) * phase)
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
          with: .color(.white.opacity(0.85)))
      }
    }.clipShape(RoundedRectangle(cornerRadius: 26))
  }

  private func source(size: CGFloat) -> some View {
    ZStack {
      Circle().fill(Palette.pearl.opacity(0.1)).frame(width: size * 0.65)
      Circle().stroke(Palette.pearl.opacity(0.3), lineWidth: 1).frame(width: size * 0.5)
      Circle().fill(Palette.pearl).frame(width: 6).shadow(color: Palette.pearl, radius: 8)
    }.frame(width: size, height: size)
      .accessibilityLabel("Pearl light source")
  }

  private func receiverView(_ receiver: Receiver, lit: Bool, size: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .stroke(receiver.color.tint.opacity(lit ? 0.6 : 0.2), lineWidth: 1)
        .frame(width: size * 0.77, height: size * 0.77)
      RoundedRectangle(cornerRadius: 4)
        .fill(receiver.color.tint.opacity(lit ? 0.85 : 0.13))
        .frame(width: size * 0.4, height: size * 0.4).rotationEffect(.degrees(45))
        .overlay {
          if lit {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
              .foregroundStyle(Palette.background)
          } else {
            Circle().fill(receiver.color.tint.opacity(0.8)).frame(width: 3, height: 3)
          }
        }
        .shadow(color: receiver.color.tint.opacity(lit ? 0.65 : 0), radius: 12)
    }.frame(width: size, height: size)
      .accessibilityLabel(
        "\(receiver.color.title) receiver \(receiver.id), \(lit ? "powered" : "unlit")")
  }

  private func opticView(_ optic: Optic, size: CGFloat) -> some View {
    let angle = state.orientations[optic.id] ?? optic.initial
    return ZStack {
      Circle().fill(.black.opacity(0.6)).offset(y: 4)
      Circle().fill(
        LinearGradient(
          colors: [.white.opacity(0.12), .white.opacity(0.025)],
          startPoint: .topLeading, endPoint: .bottomTrailing))
      Circle().stroke(Palette.pearl.opacity(selected == optic.id ? 0.7 : 0.25), lineWidth: 1)
      if optic.kind == .mirror {
        RoundedRectangle(cornerRadius: 3)
          .fill(
            LinearGradient(
              colors: [.white, Color(red: 0.44, green: 0.66, blue: 0.76), Palette.pearl],
              startPoint: .top, endPoint: .bottom)
          )
          .frame(width: size * 0.8, height: 5)
          .shadow(color: Palette.pearl.opacity(0.4), radius: 6)
          .rotationEffect(.degrees(angle == 0 ? -45 : 45))
      } else {
        Triangle().fill(
          AngularGradient(
            colors: [.pink.opacity(0.9), .cyan, Palette.teal, .pink.opacity(0.9)],
            center: .center)
        )
        .frame(width: size * 0.67, height: size * 0.63)
        .rotationEffect(.degrees(Double(angle) * 90 + 90))
        .shadow(color: .cyan.opacity(0.4), radius: 8)
        Image(systemName: "arrow.right")
          .font(.system(size: size * 0.25, weight: .bold))
          .foregroundStyle(Palette.background)
          .rotationEffect(.degrees(Double(angle) * 90))
      }
    }.frame(width: size * 0.9, height: size * 0.9)
      .animation(.spring(response: 0.3, dampingFraction: 0.75), value: angle)
  }
}

struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

struct OpticButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.scaleEffect(configuration.isPressed ? 0.88 : 1)
  }
}
