import SwiftUI

enum Palette {
  static let background = Color(red: 0.055, green: 0.070, blue: 0.076)
  static let panel = Color(red: 0.095, green: 0.112, blue: 0.118)
  static let stone = Color(red: 0.19, green: 0.215, blue: 0.218)
  static let muted = Color(red: 0.59, green: 0.64, blue: 0.63)
  static let cream = Color(red: 0.94, green: 0.91, blue: 0.81)
  static let amber = Color(red: 1, green: 0.69, blue: 0.30)
  static let gold = Color(red: 0.75, green: 0.52, blue: 0.27)
}

struct LanternArt: View {
  var victory = false
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let center = CGPoint(x: w * 0.5, y: h * 0.48)
      context.fill(
        Path(ellipseIn: CGRect(x: 0, y: 0, width: w, height: h)),
        with: .radialGradient(
          Gradient(colors: [Palette.amber.opacity(victory ? 0.38 : 0.19), .clear]),
          center: center, startRadius: 4, endRadius: w * 0.49))
      for row in 0..<4 {
        for column in 0..<7 {
          let x = CGFloat(column) * w / 7 + (row % 2 == 0 ? 0 : -w / 14)
          let y = h * 0.09 + CGFloat(row) * h * 0.16
          let rect = CGRect(x: x, y: y, width: w / 7 - 3, height: h * 0.16 - 4)
          context.fill(
            Path(roundedRect: rect, cornerRadius: 3),
            with: .color(Palette.stone.opacity(0.10 + Double((row + column) % 3) * 0.02)))
        }
      }
      var arch = Path()
      arch.move(to: CGPoint(x: w * 0.30, y: h * 0.79))
      arch.addLine(to: CGPoint(x: w * 0.30, y: h * 0.36))
      arch.addQuadCurve(
        to: CGPoint(x: w * 0.70, y: h * 0.36),
        control: CGPoint(x: w * 0.50, y: -h * 0.02))
      arch.addLine(to: CGPoint(x: w * 0.70, y: h * 0.79))
      arch.closeSubpath()
      context.fill(arch, with: .color(Palette.background.opacity(0.9)))
      context.stroke(arch, with: .color(Palette.gold.opacity(0.38)), lineWidth: 1.5)
      for row in 0..<2 {
        let y = h * 0.80 + CGFloat(row) * h * 0.07
        let half = w * (0.17 + CGFloat(row) * 0.048)
        let rect = CGRect(x: w / 2 - half, y: y, width: half * 2, height: h * 0.037)
        context.fill(
          Path(roundedRect: rect, cornerRadius: 2),
          with: .color(Palette.stone.opacity(0.4 - Double(row) * 0.055)))
        context.fill(
          Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1)),
          with: .color(Palette.gold.opacity(0.3)))
      }
      let lantern = CGRect(x: w * 0.385, y: h * 0.22, width: w * 0.23, height: h * 0.45)
      Artwork.lantern(&context, rect: lantern)
      for i in 0..<30 {
        let x = w * (0.18 + CGFloat((i * 37) % 67) / 100)
        let y = h * (0.12 + CGFloat((i * 23) % 75) / 100)
        let radius = CGFloat(i % 3 + 1) * 0.7
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
          with: .color(Palette.amber.opacity(Double(i % 5 + 1) * 0.12)))
      }
    }
    .accessibilityHidden(true)
  }
}

enum Artwork {
  static func lantern(_ context: inout GraphicsContext, rect: CGRect) {
    let x = rect.midX
    let y = rect.midY
    let w = rect.width
    let h = rect.height
    context.fill(
      Path(ellipseIn: CGRect(x: x - w * 2, y: y - w * 2, width: w * 4, height: w * 4)),
      with: .radialGradient(
        Gradient(colors: [Palette.amber.opacity(0.5), .clear]),
        center: CGPoint(x: x, y: y), startRadius: 0, endRadius: w * 2))
    let glass = CGRect(x: x - w * 0.29, y: y - h * 0.18, width: w * 0.58, height: h * 0.49)
    context.fill(
      Path(roundedRect: glass, cornerRadius: w * 0.07),
      with: .linearGradient(
        Gradient(colors: [Palette.amber.opacity(0.3), Palette.amber.opacity(0.85)]),
        startPoint: CGPoint(x: x, y: glass.minY),
        endPoint: CGPoint(x: x, y: glass.maxY)))
    var frame = Path()
    frame.move(to: CGPoint(x: x - w * 0.33, y: y - h * 0.19))
    frame.addLine(to: CGPoint(x: x - w * 0.23, y: y - h * 0.31))
    frame.addLine(to: CGPoint(x: x + w * 0.23, y: y - h * 0.31))
    frame.addLine(to: CGPoint(x: x + w * 0.33, y: y - h * 0.19))
    frame.closeSubpath()
    context.fill(frame, with: .color(Palette.gold))
    context.stroke(
      Path(roundedRect: glass, cornerRadius: w * 0.07),
      with: .color(Palette.gold), lineWidth: max(1, w * 0.05))
    let handle = CGRect(x: x - w * 0.16, y: y - h * 0.52, width: w * 0.32, height: h * 0.27)
    context.stroke(Path(ellipseIn: handle), with: .color(Palette.gold), lineWidth: max(1, w * 0.05))
    context.fill(
      Path(
        roundedRect: CGRect(
          x: x - w * 0.35, y: y + h * 0.29,
          width: w * 0.7, height: h * 0.07), cornerRadius: 2),
      with: .color(Palette.gold))
    var flame = Path()
    flame.move(to: CGPoint(x: x, y: y - h * 0.13))
    flame.addQuadCurve(
      to: CGPoint(x: x + w * 0.12, y: y + h * 0.18),
      control: CGPoint(x: x + w * 0.3, y: y + h * 0.15))
    flame.addQuadCurve(
      to: CGPoint(x: x - w * 0.1, y: y + h * 0.17),
      control: CGPoint(x: x - w * 0.15, y: y + h * 0.29))
    flame.addQuadCurve(
      to: CGPoint(x: x, y: y - h * 0.13),
      control: CGPoint(x: x - w * 0.17, y: y + h * 0.07))
    context.fill(flame, with: .color(Palette.cream))
  }

  static func gem(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
    var diamond = Path()
    diamond.move(to: CGPoint(x: center.x, y: center.y - radius))
    diamond.addLine(to: CGPoint(x: center.x + radius * 0.65, y: center.y))
    diamond.addLine(to: CGPoint(x: center.x, y: center.y + radius))
    diamond.addLine(to: CGPoint(x: center.x - radius * 0.65, y: center.y))
    diamond.closeSubpath()
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: center.x - radius * 2.5, y: center.y - radius * 2.5,
          width: radius * 5, height: radius * 5)),
      with: .radialGradient(
        Gradient(colors: [Palette.amber.opacity(0.5), .clear]),
        center: center, startRadius: 0, endRadius: radius * 2.5))
    context.fill(
      diamond,
      with: .linearGradient(
        Gradient(colors: [Palette.cream, Palette.amber, .orange]),
        startPoint: CGPoint(x: center.x - radius, y: center.y - radius),
        endPoint: CGPoint(x: center.x + radius, y: center.y + radius)))
  }
}

struct DungeonView: View {
  let journey: Journey

  var body: some View {
    Canvas { context, size in
      let room = journey.room
      let tile = min(size.width / CGFloat(room.width), size.height / CGFloat(room.height))
      let offsetX = (size.width - tile * CGFloat(room.width)) / 2
      let offsetY = (size.height - tile * CGFloat(room.height)) / 2
      for cell in room.cells {
        let rect = CGRect(
          x: offsetX + CGFloat(cell.x) * tile,
          y: offsetY + CGFloat(cell.y) * tile, width: tile, height: tile)
        let seen = journey.turn.revealed.contains(cell)
        let nearby =
          abs(cell.x - journey.turn.position.x) <= 2 && abs(cell.y - journey.turn.position.y) <= 2
        let opacity: Double = seen ? (nearby ? 1 : 0.68) : 0.06
        var tileContext = context
        tileContext.opacity = opacity
        let value = room.tile(at: cell)
        if value == "#" {
          let stone = rect.insetBy(dx: 1.5, dy: 1.5)
          tileContext.fill(
            Path(roundedRect: stone, cornerRadius: 3),
            with: .color(Palette.panel))
          tileContext.stroke(
            Path(roundedRect: stone, cornerRadius: 3),
            with: .color(Palette.stone.opacity(0.7)), lineWidth: 1)
          tileContext.fill(
            Path(
              CGRect(
                x: stone.minX + 2, y: stone.minY + 1,
                width: stone.width - 4, height: 3)),
            with: .color(Palette.stone))
          var crack = Path()
          crack.move(to: CGPoint(x: stone.minX + tile * 0.6, y: stone.minY))
          crack.addLine(to: CGPoint(x: stone.minX + tile * 0.53, y: stone.minY + tile * 0.22))
          crack.addLine(to: CGPoint(x: stone.minX + tile * 0.67, y: stone.minY + tile * 0.37))
          if (cell.x * 3 + cell.y) % 4 == 0 {
            tileContext.stroke(crack, with: .color(Palette.background.opacity(0.7)), lineWidth: 1)
          }
        } else {
          tileContext.fill(
            Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 2),
            with: .color(Color(red: 0.25, green: 0.28, blue: 0.26)))
          tileContext.stroke(
            Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 2),
            with: .color(Palette.muted.opacity(0.12)), lineWidth: 0.5)
          tileContext.fill(
            Path(
              ellipseIn: CGRect(
                x: rect.midX + 7, y: rect.midY + 8,
                width: 2, height: 2)),
            with: .color(Palette.muted.opacity(0.3)))
          if seen {
            drawItem(&tileContext, value: value, cell: cell, rect: rect)
          }
        }
      }
      if journey.turn.outcome == .escaped {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .radialGradient(
            Gradient(colors: [Palette.amber.opacity(0.25), .clear]),
            center: center, startRadius: 0, endRadius: size.width * 0.6))
        for index in 0..<24 {
          let x = size.width * CGFloat((index * 37 + 13) % 100) / 100
          let y = size.height * CGFloat((index * 23 + 7) % 100) / 100
          Artwork.gem(&context, center: CGPoint(x: x, y: y), radius: CGFloat(index % 3 + 1))
        }
      }
      let player = journey.turn.position
      let playerRect = CGRect(
        x: offsetX + CGFloat(player.x) * tile,
        y: offsetY + CGFloat(player.y) * tile, width: tile, height: tile)
      let glow = playerRect.insetBy(dx: -tile * 1.7, dy: -tile * 1.7)
      context.fill(
        Path(ellipseIn: glow),
        with: .radialGradient(
          Gradient(colors: [Palette.amber.opacity(0.16), .clear]),
          center: CGPoint(x: playerRect.midX, y: playerRect.midY),
          startRadius: 0, endRadius: tile * 2.2))
      var cloak = Path()
      cloak.move(to: CGPoint(x: playerRect.midX, y: playerRect.minY + tile * 0.27))
      cloak.addQuadCurve(
        to: CGPoint(x: playerRect.midX + tile * 0.23, y: playerRect.maxY - tile * 0.16),
        control: CGPoint(x: playerRect.midX + tile * 0.2, y: playerRect.midY))
      cloak.addQuadCurve(
        to: CGPoint(x: playerRect.midX - tile * 0.23, y: playerRect.maxY - tile * 0.16),
        control: CGPoint(x: playerRect.midX, y: playerRect.maxY))
      cloak.closeSubpath()
      context.fill(cloak, with: .color(Color(red: 0.43, green: 0.57, blue: 0.53)))
      context.fill(
        Path(
          ellipseIn: CGRect(
            x: playerRect.midX - tile * 0.13, y: playerRect.minY + tile * 0.17,
            width: tile * 0.26, height: tile * 0.27)),
        with: .color(Palette.cream))
      Artwork.lantern(
        &context,
        rect: CGRect(
          x: playerRect.midX + tile * 0.08,
          y: playerRect.midY - tile * 0.15,
          width: tile * 0.32, height: tile * 0.43))
    }
    .aspectRatio(CGFloat(journey.room.width) / CGFloat(journey.room.height), contentMode: .fit)
    .accessibilityLabel("Dungeon map")
    .accessibilityValue(
      "Explorer at column \(journey.turn.position.x), row \(journey.turn.position.y). \(surroundings)"
    )
  }

  var surroundings: String {
    Direction.allCases.map { direction in
      let cell = journey.turn.position.moved(direction)
      let tile = journey.room.tile(at: cell)
      let label: String
      switch tile {
      case "#": label = "wall"
      case "e": label = journey.turn.collected.contains(cell) ? "path" : "ember"
      case "k": label = journey.turn.collected.contains(cell) ? "path" : "key"
      case "D": label = journey.turn.opened.contains(cell) ? "open door" : "locked door"
      case "X": label = "exit"
      default: label = "path"
      }
      return "\(direction.rawValue): \(label)"
    }.joined(separator: ". ")
  }

  private func drawItem(
    _ context: inout GraphicsContext, value: Character, cell: Cell, rect: CGRect
  ) {
    guard !journey.turn.collected.contains(cell) else { return }
    Artwork.item(&context, value: value, rect: rect, opened: journey.turn.opened.contains(cell))
  }
}

extension Artwork {
  static func item(
    _ context: inout GraphicsContext, value: Character, rect: CGRect, opened: Bool = false
  ) {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let t = rect.width
    if value == "e" {
      Artwork.gem(&context, center: center, radius: t * 0.21)
    } else if value == "k" {
      context.stroke(
        Path(
          ellipseIn: CGRect(
            x: center.x - t * 0.22, y: center.y - t * 0.18,
            width: t * 0.22, height: t * 0.22)),
        with: .color(Palette.amber), lineWidth: 2.5)
      var key = Path()
      key.move(to: CGPoint(x: center.x - t * 0.03, y: center.y))
      key.addLine(to: CGPoint(x: center.x + t * 0.21, y: center.y + t * 0.24))
      key.addLine(to: CGPoint(x: center.x + t * 0.30, y: center.y + t * 0.15))
      context.stroke(
        key, with: .color(Palette.amber), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    } else if value == "D" {
      let door = rect.insetBy(dx: t * 0.18, dy: t * 0.12)
      context.stroke(
        Path(roundedRect: door, cornerRadius: t * 0.10),
        with: .color(Palette.gold), lineWidth: 2)
      if !opened {
        for fraction in [0.38, 0.62] {
          let bar = CGRect(x: rect.minX + t * fraction, y: door.minY, width: 2, height: door.height)
          context.fill(Path(bar), with: .color(Palette.gold))
        }
        context.fill(
          Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
          with: .color(Palette.amber))
      }
    } else if value == "X" {
      let portal = rect.insetBy(dx: t * 0.15, dy: t * 0.09)
      context.fill(
        Path(roundedRect: portal, cornerRadius: t * 0.24),
        with: .linearGradient(
          Gradient(colors: [Palette.cream, Palette.amber.opacity(0.18)]),
          startPoint: CGPoint(x: center.x, y: portal.minY),
          endPoint: CGPoint(x: center.x, y: portal.maxY)))
      context.stroke(
        Path(roundedRect: portal, cornerRadius: t * 0.24),
        with: .color(Palette.amber), lineWidth: 1)
    }
  }
}
