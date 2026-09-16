import SwiftUI

/// One board cell. Cables spin with a spring; powered lanes glow and carry a moving
/// dash pattern; hot tiles pulse; stressed cables blush orange before melting.
struct TileView: View {
  let tile: Tile
  let powered: Set<Net>
  let isShort: Bool
  let solved: Bool
  let phase: Double
  let size: CGFloat

  private var laneColor: Color {
    if isShort { return Palette.red }
    if let net = powered.first { return Palette.net(net) }
    return Palette.steel
  }
  private var isPowered: Bool { !powered.isEmpty }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(Palette.slate.opacity(tile.kind == .empty ? 0.35 : 0.9))
        .overlay(
          RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .strokeBorder(Palette.steel.opacity(tile.kind == .empty ? 0.25 : 0.6), lineWidth: 1))
      switch tile.kind {
      case .empty:
        Circle().fill(Palette.steel.opacity(0.35)).frame(width: size * 0.08, height: size * 0.08)
      case .hot:
        HotTile(size: size, phase: phase)
      case .slag:
        SlagTile(size: size)
      case .source(let net):
        SourceTile(net: net, powered: isPowered, size: size, rotation: tile.rotation)
      case .sink(let net):
        SinkTile(
          net: net, powered: powered.contains(net) && !isShort, solved: solved, size: size,
          rotation: tile.rotation, phase: phase)
      default:
        cable
      }
    }
    .frame(width: size, height: size)
    .contentShape(Rectangle())
  }

  private var cable: some View {
    ZStack {
      CableShape(openings: tile.kind.baseOpenings, size: size)
        .stroke(
          Palette.ink, style: StrokeStyle(lineWidth: size * 0.34, lineCap: .round, lineJoin: .round)
        )
      CableShape(openings: tile.kind.baseOpenings, size: size)
        .stroke(
          laneColor, style: StrokeStyle(lineWidth: size * 0.24, lineCap: .round, lineJoin: .round)
        )
        .shadow(
          color: isPowered ? laneColor.opacity(0.9) : .clear, radius: isPowered ? size * 0.16 : 0)
      if isPowered {
        CableShape(openings: tile.kind.baseOpenings, size: size)
          .stroke(
            Color.white.opacity(0.85),
            style: StrokeStyle(
              lineWidth: size * 0.07, lineCap: .round, dash: [size * 0.12, size * 0.28],
              dashPhase: -phase * size * 0.8)
          )
          .blendMode(.plusLighter)
      }
      if tile.heat > 0 {
        CableShape(openings: tile.kind.baseOpenings, size: size)
          .stroke(
            Palette.ember.opacity(0.35 + 0.65 * tile.heat),
            style: StrokeStyle(lineWidth: size * 0.24, lineCap: .round, lineJoin: .round)
          )
          .shadow(color: Palette.ember.opacity(tile.heat), radius: size * 0.2 * tile.heat)
          .blendMode(.screen)
      }
      Circle()
        .fill(Palette.ink)
        .frame(width: size * 0.16, height: size * 0.16)
        .overlay(Circle().strokeBorder(laneColor.opacity(0.9), lineWidth: 1.5))
    }
    .rotationEffect(.degrees(Double(tile.rotation) * 90))
    .animation(.spring(response: 0.32, dampingFraction: 0.68), value: tile.rotation)
    .scaleEffect(tile.heat > 0 ? 1 + 0.03 * sin(phase * 18) * tile.heat : 1)
  }
}

struct CableShape: Shape {
  var openings: Set<Direction>
  var size: CGFloat
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let c = CGPoint(x: rect.midX, y: rect.midY)
    for d in openings.sorted(by: { $0.rawValue < $1.rawValue }) {
      path.move(to: c)
      switch d {
      case .up: path.addLine(to: CGPoint(x: c.x, y: rect.minY))
      case .right: path.addLine(to: CGPoint(x: rect.maxX, y: c.y))
      case .down: path.addLine(to: CGPoint(x: c.x, y: rect.maxY))
      case .left: path.addLine(to: CGPoint(x: rect.minX, y: c.y))
      }
    }
    return path
  }
}

struct HotTile: View {
  let size: CGFloat
  let phase: Double
  var body: some View {
    let pulse = 0.5 + 0.5 * sin(phase * 4)
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(
          RadialGradient(
            colors: [
              Palette.ember.opacity(0.75 + 0.25 * pulse), Palette.red.opacity(0.35), Palette.slate,
            ],
            center: .center, startRadius: 0, endRadius: size * 0.6)
        )
        .shadow(color: Palette.ember.opacity(0.5 + 0.4 * pulse), radius: size * 0.22)
      ForEach(0..<3, id: \.self) { i in
        RoundedRectangle(cornerRadius: 2)
          .fill(Palette.ink.opacity(0.85))
          .frame(width: size * 0.62, height: size * 0.06)
          .offset(y: CGFloat(i - 1) * size * 0.16)
      }
      Image(systemName: "flame.fill")
        .font(.system(size: size * 0.34, weight: .bold))
        .foregroundStyle(Palette.paper.opacity(0.9))
        .shadow(color: Palette.ember, radius: 6)
        .scaleEffect(1 + 0.08 * pulse)
    }
    .accessibilityLabel("Hot chip")
  }
}

struct SlagTile: View {
  let size: CGFloat
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(Color(red: 0.1, green: 0.07, blue: 0.06))
      Image(systemName: "xmark")
        .font(.system(size: size * 0.3, weight: .black))
        .foregroundStyle(Palette.ember.opacity(0.6))
      Circle().fill(Palette.ember.opacity(0.18)).frame(width: size * 0.5, height: size * 0.5).blur(
        radius: 6)
    }
    .accessibilityLabel("Melted cable")
  }
}

struct SourceTile: View {
  let net: Net
  let powered: Bool
  let size: CGFloat
  let rotation: Int
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Palette.steel, Palette.charcoal], startPoint: .top, endPoint: .bottom))
      // connector stub
      Rectangle()
        .fill(Palette.net(net))
        .frame(width: size * 0.3, height: size * 0.24)
        .offset(x: size * 0.4)
        .shadow(color: Palette.net(net).opacity(0.8), radius: 6)
        .rotationEffect(.degrees(Double(rotation) * 90))
      VStack(spacing: 2) {
        Text("PSU")
          .font(.mono(size * 0.2, weight: .black))
          .foregroundStyle(Palette.paper)
        Text(net == .power ? "12V" : "PCIe")
          .font(.mono(size * 0.15))
          .foregroundStyle(Palette.net(net))
      }
      HStack(spacing: 2) {
        ForEach(0..<4, id: \.self) { _ in
          Circle().fill(Palette.net(net).opacity(powered ? 0.95 : 0.35)).frame(width: 3, height: 3)
        }
      }
      .offset(y: size * 0.34)
    }
    .accessibilityLabel("\(net.label) power supply connector")
  }
}

struct SinkTile: View {
  let net: Net
  let powered: Bool
  let solved: Bool
  let size: CGFloat
  let rotation: Int
  let phase: Double
  var body: some View {
    let spin = solved ? phase * 900 : (powered ? phase * 220 : 0)
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Palette.charcoal, Palette.ink], startPoint: .top, endPoint: .bottom)
        )
        .overlay(
          RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .strokeBorder(powered ? Palette.net(net) : Palette.steel, lineWidth: powered ? 2 : 1)
        )
        .shadow(color: powered ? Palette.net(net).opacity(0.8) : .clear, radius: size * 0.2)
      Rectangle()
        .fill(powered ? Palette.net(net) : Palette.steel)
        .frame(width: size * 0.3, height: size * 0.24)
        .offset(x: size * 0.4)
        .rotationEffect(.degrees(Double(rotation) * 90))
      // fan
      ZStack {
        Circle().strokeBorder(Palette.steel, lineWidth: 2).frame(
          width: size * 0.56, height: size * 0.56)
        ForEach(0..<5, id: \.self) { i in
          Capsule()
            .fill(powered ? Palette.net(net) : Palette.mist.opacity(0.7))
            .frame(width: size * 0.09, height: size * 0.24)
            .offset(y: -size * 0.14)
            .rotationEffect(.degrees(Double(i) * 72 + spin))
        }
        Circle().fill(Palette.ink).frame(width: size * 0.16, height: size * 0.16)
          .overlay(
            Circle().strokeBorder(powered ? Palette.net(net) : Palette.steel, lineWidth: 1.5))
      }
      .offset(y: -size * 0.06)
      Text(net == .power ? "GPU" : "x16")
        .font(.mono(size * 0.14, weight: .black))
        .foregroundStyle(powered ? Palette.net(net) : Palette.mist)
        .offset(y: size * 0.34)
    }
    .accessibilityLabel("GPU \(net.label) connector\(powered ? ", powered" : "")")
  }
}
