import SwiftUI

enum Palette {
  static let background = Color(red: 0.025, green: 0.09, blue: 0.12)
  static let panel = Color(red: 0.055, green: 0.15, blue: 0.18)
  static let mint = Color(red: 0.55, green: 0.98, blue: 0.82)
  static let coral = Color(red: 1, green: 0.51, blue: 0.40)
  static let ink = Color(red: 0.89, green: 0.97, blue: 0.96)
  static let muted = Color(red: 0.58, green: 0.72, blue: 0.74)
  static let line = Color(red: 0.17, green: 0.29, blue: 0.33)
}

struct InstrumentBackground: View {
  var body: some View {
    ZStack {
      Palette.background
      RadialGradient(
        colors: [Palette.mint.opacity(0.065), .clear],
        center: .topTrailing, startRadius: 10, endRadius: 540)
      Canvas { context, size in
        for x in stride(from: 14.0, to: size.width, by: 24) {
          for y in stride(from: 14.0, to: size.height, by: 24) {
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
              with: .color(Palette.muted.opacity(0.12)))
          }
        }
      }
    }
    .ignoresSafeArea()
  }
}

struct MicroLabel: View {
  let text: String
  var color: Color = Palette.muted

  var body: some View {
    Text(text)
      .font(.system(.caption, design: .monospaced, weight: .medium))
      .tracking(1.0)
      .foregroundStyle(color)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

struct ActionButton: View {
  let title: String
  let symbol: String
  var primary = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(title)
          .font(.system(.subheadline, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
      }
      .foregroundStyle(primary ? Palette.background : Palette.ink)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .frame(minHeight: 54)
      .background(primary ? Palette.mint : Palette.panel, in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(primary ? .clear : Palette.line.opacity(0.7), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

struct IconButton: View {
  let symbol: String
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Palette.ink)
        .frame(width: 46, height: 46)
        .background(Palette.panel, in: Circle())
        .overlay { Circle().strokeBorder(Palette.line, lineWidth: 1) }
    }
    .accessibilityLabel(label)
    .buttonStyle(.plain)
  }
}

struct CircuitTrace: Shape {
  let mask: Int

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    for direction in Direction.allCases where mask & direction.bit != 0 {
      path.move(to: center)
      path.addLine(
        to: CGPoint(
          x: center.x + CGFloat(direction.columnOffset) * rect.width / 2,
          y: center.y + CGFloat(direction.rowOffset) * rect.height / 2))
    }
    return path
  }
}

struct TileView: View {
  let level: CircuitLevel
  let index: Int
  let turns: Int
  let distance: Int?
  let hint: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isSource: Bool { index == level.source }
  private var isReceiver: Bool { level.receivers.contains(index) }
  private var powered: Bool { distance != nil }
  private var color: Color {
    if isReceiver && !powered { return Palette.coral }
    return powered ? Palette.mint : Palette.muted
  }

  var body: some View {
    ZStack {
      if level.masks[index] == 0 {
        RoundedRectangle(cornerRadius: 14)
          .fill(Palette.panel.opacity(0.45))
          .overlay {
            RoundedRectangle(cornerRadius: 14)
              .strokeBorder(
                Palette.line.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
          }
          .overlay {
            Image(systemName: "plus")
              .font(.system(size: 10, weight: .light))
              .foregroundStyle(Palette.muted.opacity(0.5))
          }
      } else {
        RoundedRectangle(cornerRadius: 14)
          .fill(
            LinearGradient(
              colors: [
                (powered ? Palette.mint : Palette.muted).opacity(powered ? 0.13 : 0.08),
                Palette.panel.opacity(0.7),
              ], startPoint: .topLeading, endPoint: .bottomTrailing))
        RoundedRectangle(cornerRadius: 14)
          .strokeBorder(
            hint ? Palette.coral : (powered ? Palette.mint.opacity(0.4) : Palette.line),
            lineWidth: hint ? 2 : 1)
        CircuitTrace(mask: level.masks[index])
          .stroke(color.opacity(0.12), style: StrokeStyle(lineWidth: 14, lineCap: .round))
          .rotationEffect(.degrees(Double(turns) * 90))
          .padding(5)
        CircuitTrace(mask: level.masks[index])
          .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .rotationEffect(.degrees(Double(turns) * 90))
          .padding(5)
          .shadow(color: powered ? Palette.mint.opacity(0.5) : .clear, radius: 6)
        if powered && !reduceMotion {
          TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            Canvas { context, size in
              let time = timeline.date.timeIntervalSinceReferenceDate
              let phase = (time * 0.65 - Double(distance ?? 0) * 0.13)
              let progress = phase - floor(phase)
              let mask = Direction.rotate(level.masks[index], turns: turns)
              for direction in Direction.allCases where mask & direction.bit != 0 {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let point = CGPoint(
                  x: center.x + CGFloat(direction.columnOffset) * (size.width / 2 - 5) * progress,
                  y: center.y + CGFloat(direction.rowOffset) * (size.height / 2 - 5) * progress)
                context.fill(
                  Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
                  with: .color(.white.opacity(1 - progress * 0.65)))
              }
            }
          }
          .allowsHitTesting(false)
        }
        if isSource || isReceiver {
          Circle().fill(Palette.background).frame(width: 29, height: 29)
          Circle().strokeBorder(color, lineWidth: 1.5).frame(width: 29, height: 29)
          Image(systemName: isSource ? "bolt.fill" : (powered ? "checkmark" : "diamond.fill"))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
        } else {
          Circle().fill(Palette.panel).frame(width: 9, height: 9)
          Circle().strokeBorder(color, lineWidth: 1.5).frame(width: 9, height: 9)
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

struct HeroCircuit: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let points: [CGPoint] = [
    CGPoint(x: 0.06, y: 0.70), CGPoint(x: 0.28, y: 0.70),
    CGPoint(x: 0.28, y: 0.25), CGPoint(x: 0.57, y: 0.25),
    CGPoint(x: 0.57, y: 0.70), CGPoint(x: 0.94, y: 0.70),
  ]

  var body: some View {
    TimelineView(.animation(minimumInterval: 0.05, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let nodes = points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        var path = Path()
        path.addLines(nodes)
        context.stroke(
          path, with: .color(Palette.mint.opacity(0.035)),
          style: StrokeStyle(lineWidth: 32, lineCap: .round, lineJoin: .round))
        context.stroke(
          path, with: .color(Palette.mint.opacity(0.08)),
          style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
        for node in nodes {
          let rect = CGRect(x: node.x - 23, y: node.y - 23, width: 46, height: 46)
          context.fill(Path(roundedRect: rect, cornerRadius: 11), with: .color(Palette.panel))
          context.stroke(
            Path(roundedRect: rect, cornerRadius: 11),
            with: .color(Palette.mint.opacity(0.25)), lineWidth: 1)
        }
        context.stroke(
          path, with: .color(Palette.mint.opacity(0.8)),
          style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        for node in nodes {
          let circle = Path(ellipseIn: CGRect(x: node.x - 4, y: node.y - 4, width: 8, height: 8))
          context.fill(circle, with: .color(Palette.panel))
          context.stroke(circle, with: .color(Palette.mint), lineWidth: 1.5)
        }
        let phase = (timeline.date.timeIntervalSinceReferenceDate * 0.8).truncatingRemainder(
          dividingBy: 5)
        let segment = Int(phase)
        let fraction = phase - Double(segment)
        let first = nodes[segment]
        let second = nodes[segment + 1]
        let pulse = CGPoint(
          x: first.x + (second.x - first.x) * fraction,
          y: first.y + (second.y - first.y) * fraction)
        context.fill(
          Path(ellipseIn: CGRect(x: pulse.x - 3, y: pulse.y - 3, width: 6, height: 6)),
          with: .color(.white))
        for (node, symbol, color) in [
          (nodes[0], "bolt.fill", Palette.mint),
          (nodes[5], "checkmark", Palette.mint),
        ] {
          let ring = Path(ellipseIn: CGRect(x: node.x - 13, y: node.y - 13, width: 26, height: 26))
          context.fill(ring, with: .color(Palette.background))
          context.stroke(ring, with: .color(color), lineWidth: 1.5)
          context.draw(
            Text(Image(systemName: symbol)).font(.system(size: 10, weight: .bold))
              .foregroundStyle(color), at: node)
        }
      }
    }
    .accessibilityHidden(true)
  }
}

struct SheetHeader: View {
  let title: String
  let closeLabel: String
  let close: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      MicroLabel(text: title, color: Palette.mint)
      Spacer(minLength: 8)
      IconButton(symbol: "xmark", label: closeLabel, action: close)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background {
      Palette.background
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
  }
}
