import SwiftUI

enum Palette {
  static let ink = Color(red: 0.035, green: 0.053, blue: 0.061)
  static let stone = Color(red: 0.16, green: 0.20, blue: 0.20)
  static let gold = Color(red: 0.78, green: 0.64, blue: 0.43)
  static let paper = Color(red: 0.96, green: 0.91, blue: 0.80)
  static let muted = Color(red: 0.65, green: 0.68, blue: 0.65)
  static let velvet = Color(red: 0.25, green: 0.055, blue: 0.095)
  static let ruby = Color(red: 1, green: 0.18, blue: 0.32)
  static let mint = Color(red: 0.48, green: 0.86, blue: 0.75)
  static let amber = Color(red: 1, green: 0.69, blue: 0.27)
}

struct Diamond: Shape {
  func path(in rect: CGRect) -> Path {
    Path { p in
      p.move(to: CGPoint(x: rect.midX, y: rect.minY))
      p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
      p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
      p.closeSubpath()
    }
  }
}

struct Jewel: View {
  var size: CGFloat = 100
  var artifactID = 1
  var color: Color { ArtifactShape.color(artifactID) }
  var body: some View {
    ZStack {
      Circle().fill(color.opacity(0.12)).blur(radius: size * 0.2)
      ArtifactShape(id: artifactID).fill(
        LinearGradient(
          colors: [color, color.opacity(0.35), Palette.ink], startPoint: .topLeading,
          endPoint: .bottomTrailing)
      )
      .overlay(ArtifactShape(id: artifactID).stroke(Palette.paper.opacity(0.7), lineWidth: 1))
      .frame(width: size * 0.62, height: size * 0.88)
      if artifactID == 1 {
        Diamond().fill(
          LinearGradient(
            colors: [Palette.paper.opacity(0.7), color.opacity(0.1), color],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        ).frame(width: size * 0.3, height: size * 0.88)
        Diamond().stroke(Palette.paper.opacity(0.35), lineWidth: 0.7)
          .frame(width: size * 0.3, height: size * 0.88)
        Rectangle().fill(Palette.paper.opacity(0.5)).frame(width: size * 0.62, height: 0.6)
      }
      Circle().fill(Palette.paper).frame(width: 4, height: 4).offset(
        x: -size * 0.15, y: -size * 0.22)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

struct MuseumBoard: View {
  let room: Room
  let state: HeistState
  var interactive = true
  var showForecast = true
  var tap: (Tile) -> Void = { _ in }
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let cell = min(
        geometry.size.width / CGFloat(room.width), geometry.size.height / CGFloat(room.height))
      let boardSize = CGSize(width: cell * CGFloat(room.width), height: cell * CGFloat(room.height))
      ZStack(alignment: .topLeading) {
        Canvas { context, _ in
          drawMuseum(context: context, cell: cell)
        }
        .accessibilityHidden(true)
        if interactive {
          ForEach(
            room.tiles.filter {
              room.walkable($0) || room.nodes.contains($0) || room.mirrors.contains($0)
            }, id: \.self
          ) { tile in
            Button {
              tap(tile)
            } label: {
              Color.clear.contentShape(Rectangle())
            }
            .frame(width: cell, height: cell)
            .position(center(tile, cell))
            .accessibilityLabel(label(tile))
            .accessibilityIdentifier("tile-\(tile.x)-\(tile.y)")
            .accessibilityHint(
              state.player.distance(to: tile) == 1
                ? "Double tap to use this tile" : "Move to a neighboring tile first")
          }
        }
        ThiefFigure()
          .frame(width: cell * 0.72, height: cell * 0.80)
          .position(center(state.player, cell))
          .shadow(color: .black.opacity(0.8), radius: 5, x: 3, y: 5)
          .animation(
            reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.78), value: state.player
          )
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .frame(width: boardSize.width, height: boardSize.height)
      .background(Palette.ink)
      .overlay {
        EngravedFrame().stroke(Palette.gold.opacity(0.48), lineWidth: 0.7)
          .allowsHitTesting(false)
      }
      .shadow(color: .black.opacity(0.65), radius: 18, y: 12)
      .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    .aspectRatio(CGFloat(room.width) / CGFloat(room.height), contentMode: .fit)
  }

  private func center(_ tile: Tile, _ cell: CGFloat) -> CGPoint {
    CGPoint(x: (CGFloat(tile.x) + 0.5) * cell, y: (CGFloat(tile.y) + 0.5) * cell)
  }

  private func label(_ tile: Tile) -> String {
    let position = "column \(tile.x + 1), row \(tile.y + 1)"
    if tile == state.player { return "You, \(position)" }
    if room.nodes.contains(tile) { return "Power node \(room.circuit(at: tile) + 1), \(position)" }
    if room.mirrors.contains(tile) { return "Rotate mirror, \(position)" }
    if tile == room.artifact && !state.hasArtifact { return "\(room.artifactName), \(position)" }
    if tile == room.start { return "Exit, \(position)" }
    if HeistEngine.field(room, state).danger.contains(tile) { return "Danger, \(position)" }
    if HeistEngine.field(room, state, nextTurn: true).danger.contains(tile) {
      return "Next sweep, \(position)"
    }
    return "Step to \(position)"
  }

  private func drawMuseum(context: GraphicsContext, cell: CGFloat) {
    let field = HeistEngine.field(room, state)
    let next = HeistEngine.field(room, state, nextTurn: true)
    for tile in room.tiles {
      let rect = CGRect(
        x: CGFloat(tile.x) * cell, y: CGFloat(tile.y) * cell, width: cell, height: cell)
      let c = center(tile, cell)
      if room.mark(tile) == "#" {
        context.fill(
          Path(rect),
          with: .linearGradient(
            Gradient(colors: [Palette.stone.opacity(0.6), Palette.ink]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        if tile.x > 0 && tile.x < room.width - 1 && tile.y > 0 && tile.y < room.height - 1 {
          context.fill(
            Path(rect.insetBy(dx: 1, dy: 1).offsetBy(dx: 3, dy: 5)),
            with: .color(.black.opacity(0.7)))
          context.fill(
            Path(rect.insetBy(dx: 1, dy: 1)),
            with: .linearGradient(
              Gradient(colors: [Palette.gold.opacity(0.5), Palette.stone, Palette.ink]),
              startPoint: CGPoint(x: rect.minX, y: rect.minY),
              endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
          context.stroke(
            Path(rect.insetBy(dx: 5, dy: 5)), with: .color(Palette.gold.opacity(0.4)),
            lineWidth: 0.6)
          context.stroke(
            Diamond().path(in: rect.insetBy(dx: cell * 0.31, dy: cell * 0.31)),
            with: .color(Palette.gold.opacity(0.38)), lineWidth: 0.7)
        } else if tile.y == 0 || tile.y == room.height - 1 {
          let line = CGRect(
            x: rect.minX, y: tile.y == 0 ? rect.maxY - 5 : rect.minY + 3, width: cell,
            height: 2)
          context.fill(Path(line), with: .color(Palette.gold.opacity(0.5)))
          context.fill(Path(line.offsetBy(dx: 0, dy: 3)), with: .color(.black.opacity(0.5)))
          if tile.x == 2 || tile.x == 4 {
            let art = CGRect(
              x: c.x - cell * 0.29, y: c.y - cell * 0.22, width: cell * 0.58, height: cell * 0.44)
            context.fill(Path(art.offsetBy(dx: 2, dy: 3)), with: .color(.black.opacity(0.7)))
            context.fill(
              Path(art),
              with: .linearGradient(
                Gradient(colors: [Palette.velvet, Palette.ink]),
                startPoint: CGPoint(x: art.minX, y: art.minY),
                endPoint: CGPoint(x: art.maxX, y: art.maxY)))
            context.stroke(
              Path(art.insetBy(dx: -2, dy: -2)), with: .color(Palette.gold.opacity(0.7)),
              lineWidth: 1)
            context.stroke(
              Path(art.insetBy(dx: 1, dy: 1)), with: .color(Palette.gold.opacity(0.3)),
              lineWidth: 0.5)
            context.fill(
              ArtifactShape(id: room.id + tile.x).path(in: art.insetBy(dx: cell * 0.17, dy: 4)),
              with: .linearGradient(
                Gradient(colors: [Palette.paper, Palette.gold.opacity(0.5)]),
                startPoint: CGPoint(x: art.minX, y: art.minY),
                endPoint: CGPoint(x: art.maxX, y: art.maxY))
            )
          }
        } else {
          let pillar = CGRect(
            x: c.x - cell * 0.17, y: c.y - cell * 0.37,
            width: cell * 0.34, height: cell * 0.74)
          context.fill(
            Path(pillar.offsetBy(dx: 4, dy: 4)), with: .color(.black.opacity(0.45)))
          context.fill(
            Path(roundedRect: pillar, cornerRadius: 2),
            with: .linearGradient(
              Gradient(colors: [
                Palette.ink, Palette.stone, Palette.gold.opacity(0.36), Palette.ink,
              ]),
              startPoint: CGPoint(x: pillar.minX, y: c.y), endPoint: CGPoint(x: pillar.maxX, y: c.y)
            ))
          for line in 1..<5 {
            let x = pillar.minX + CGFloat(line) * pillar.width / 5
            context.fill(
              Path(CGRect(x: x, y: pillar.minY + 3, width: 0.5, height: pillar.height - 6)),
              with: .color(Palette.ink.opacity(0.6)))
          }
          for y in [pillar.minY, pillar.maxY - 3] {
            context.fill(
              Path(CGRect(x: pillar.minX - 3, y: y, width: pillar.width + 6, height: 3)),
              with: .linearGradient(
                Gradient(colors: [
                  Palette.gold.opacity(0.3), Palette.gold, Palette.gold.opacity(0.2),
                ]),
                startPoint: CGPoint(x: pillar.minX, y: y),
                endPoint: CGPoint(x: pillar.maxX, y: y)))
          }
        }
        continue
      }
      let pale = (tile.x + tile.y).isMultiple(of: 2)
      let marble =
        pale
        ? Color(red: 0.29, green: 0.32, blue: 0.30)
        : Color(red: 0.13, green: 0.17, blue: 0.18)
      context.fill(
        Path(rect.insetBy(dx: 0.6, dy: 0.6)),
        with: .linearGradient(
          Gradient(colors: [marble, marble.opacity(0.75)]),
          startPoint: CGPoint(x: rect.minX, y: rect.minY),
          endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
      context.stroke(
        Path(rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(Palette.paper.opacity(0.055)),
        lineWidth: 0.5)
      for index in 0..<3 {
        let seed = CGFloat((tile.x * 17 + tile.y * 13 + index * 7) % 19) / 19
        var vein = Path()
        vein.move(to: CGPoint(x: rect.minX, y: rect.minY + cell * seed))
        vein.addCurve(
          to: CGPoint(x: rect.maxX, y: rect.minY + cell * (1 - seed)),
          control1: CGPoint(x: rect.minX + cell * 0.35, y: rect.minY + cell * seed),
          control2: CGPoint(x: rect.midX, y: rect.minY + cell * (1 - seed)))
        context.stroke(
          vein, with: .color(Palette.paper.opacity(pale ? 0.055 : 0.03)),
          lineWidth: index == 0 ? 1 : 0.4)
      }
      if tile.x == room.width / 2 {
        let carpet = CGRect(
          x: rect.minX + cell * 0.15, y: rect.minY, width: cell * 0.7, height: cell)
        context.fill(
          Path(carpet),
          with: .linearGradient(
            Gradient(colors: [
              Palette.velvet.opacity(0.75), Palette.velvet, Palette.velvet.opacity(0.7),
            ]),
            startPoint: CGPoint(x: carpet.minX, y: c.y),
            endPoint: CGPoint(x: carpet.maxX, y: c.y)))
        for x in [carpet.minX + 2, carpet.maxX - 3] {
          context.fill(
            Path(CGRect(x: x, y: rect.minY, width: 0.6, height: cell)),
            with: .color(Palette.gold.opacity(0.5)))
        }
        context.stroke(
          Diamond().path(in: CGRect(x: c.x - 4, y: c.y - 7, width: 8, height: 14)),
          with: .color(Palette.gold.opacity(0.16)), lineWidth: 0.7)
      }
      if showForecast && next.danger.contains(tile) && !field.danger.contains(tile) {
        context.stroke(
          Path(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 4),
          with: .color(Palette.amber.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
      }
      if interactive && state.outcome == .playing && state.player.distance(to: tile) == 1
        && room.walkable(tile)
      {
        let unsafe = field.danger.contains(tile) || next.danger.contains(tile)
        let marker =
          field.danger.contains(tile) ? Palette.ruby : (unsafe ? Palette.amber : Palette.mint)
        context.stroke(
          Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 5),
          with: .color(marker.opacity(0.7)), lineWidth: 1.2)
        if unsafe {
          context.draw(
            Text("×").font(.system(size: cell * 0.28, weight: .light)).foregroundColor(marker),
            at: CGPoint(x: c.x, y: c.y + cell * 0.22))
        } else {
          context.fill(
            Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 5),
            with: .color(Palette.mint.opacity(0.075)))
          context.fill(
            Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)),
            with: .color(marker))
        }
      }
    }
    for segment in field.segments {
      let from = center(segment.from, cell)
      let to = center(segment.to, cell)
      var path = Path()
      path.move(to: from)
      path.addLine(to: to)
      let color = segment.searchlight ? Palette.amber : Palette.ruby
      context.drawLayer { glow in
        glow.addFilter(.blur(radius: segment.searchlight ? 6 : 4))
        glow.stroke(
          path, with: .color(color.opacity(0.5)), lineWidth: segment.searchlight ? cell * 0.47 : 7)
      }
      context.stroke(
        path, with: .color(color.opacity(segment.searchlight ? 0.22 : 0.95)),
        style: StrokeStyle(lineWidth: segment.searchlight ? cell * 0.3 : 2, lineCap: .round))
      if !segment.searchlight {
        context.stroke(path, with: .color(Palette.paper.opacity(0.8)), lineWidth: 0.6)
      }
    }
    for tile in room.tiles {
      let c = center(tile, cell)
      let rect = CGRect(
        x: c.x - cell * 0.28, y: c.y - cell * 0.28, width: cell * 0.56, height: cell * 0.56)
      if tile == room.start {
        context.stroke(
          Path(roundedRect: rect, cornerRadius: 5), with: .color(Palette.mint.opacity(0.8)),
          style: StrokeStyle(lineWidth: 1.5, dash: [4, 2]))
        context.draw(
          Text("EXIT").font(.system(size: cell * 0.18, weight: .bold, design: .monospaced))
            .foregroundColor(Palette.mint), at: CGPoint(x: c.x, y: c.y + cell * 0.4))
      }
      if tile == room.artifact {
        context.drawLayer { light in
          light.addFilter(.blur(radius: 12))
          light.fill(
            Path(ellipseIn: rect.insetBy(dx: -cell * 0.4, dy: -cell * 0.4)),
            with: .color(Palette.gold.opacity(0.3)))
        }
        context.fill(
          Path(ellipseIn: rect.offsetBy(dx: 3, dy: cell * 0.12)), with: .color(.black.opacity(0.4)))
        context.fill(
          Path(ellipseIn: rect.offsetBy(dx: 0, dy: cell * 0.08)),
          with: .linearGradient(
            Gradient(colors: [Palette.gold.opacity(0.6), Palette.ink]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.fill(
          Path(ellipseIn: rect),
          with: .linearGradient(
            Gradient(colors: [Palette.paper.opacity(0.8), Palette.stone, Palette.ink]),
            startPoint: CGPoint(x: c.x, y: rect.minY), endPoint: CGPoint(x: c.x, y: rect.maxY)))
        context.stroke(
          Path(ellipseIn: rect.insetBy(dx: 2, dy: 2)),
          with: .color(Palette.gold.opacity(0.7)), lineWidth: 0.7)
        if !state.hasArtifact {
          let jewel = rect.insetBy(dx: cell * 0.1, dy: cell * 0.04).offsetBy(
            dx: 0, dy: -cell * 0.08)
          context.fill(
            ArtifactShape(id: room.id).path(in: jewel),
            with: .linearGradient(
              Gradient(colors: [
                Palette.paper, ArtifactShape.color(room.id),
                ArtifactShape.color(room.id).opacity(0.4),
              ]),
              startPoint: CGPoint(x: jewel.minX, y: jewel.minY),
              endPoint: CGPoint(x: jewel.maxX, y: jewel.maxY)))
          context.stroke(
            ArtifactShape(id: room.id).path(in: jewel), with: .color(Palette.paper.opacity(0.7)),
            lineWidth: 0.7)
          if room.id == 1 {
            let facet = CGRect(
              x: jewel.midX - jewel.width * 0.2, y: jewel.minY,
              width: jewel.width * 0.4, height: jewel.height)
            context.fill(
              Diamond().path(in: facet),
              with: .linearGradient(
                Gradient(colors: [Palette.paper.opacity(0.8), Palette.ruby, Palette.velvet]),
                startPoint: CGPoint(x: facet.minX, y: facet.minY),
                endPoint: CGPoint(x: facet.maxX, y: facet.maxY)))
          }
        }
      }
      if let index = room.mirrors.firstIndex(of: tile) {
        let slash = (room.mark(tile) == "/") != (state.mirrorBits & (1 << index) != 0)
        context.fill(
          Path(ellipseIn: rect.offsetBy(dx: 3, dy: 4)), with: .color(.black.opacity(0.5)))
        context.fill(
          Path(ellipseIn: rect),
          with: .linearGradient(
            Gradient(colors: [Palette.gold, Palette.ink, Palette.stone]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.gold), lineWidth: 1.2)
        context.stroke(
          Path(ellipseIn: rect.insetBy(dx: 3, dy: 3)),
          with: .color(Palette.paper.opacity(0.3)), lineWidth: 0.5)
        var line = Path()
        line.move(to: CGPoint(x: rect.minX + 4, y: slash ? rect.maxY - 4 : rect.minY + 4))
        line.addLine(to: CGPoint(x: rect.maxX - 4, y: slash ? rect.minY + 4 : rect.maxY - 4))
        context.stroke(
          line, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        context.stroke(
          line, with: .color(Palette.paper.opacity(0.85)),
          style: StrokeStyle(lineWidth: 1, lineCap: .round))
      }
      if room.nodes.contains(tile) {
        let active = state.power & (1 << room.circuit(at: tile)) != 0
        context.fill(
          Path(roundedRect: rect.offsetBy(dx: 2, dy: 3), cornerRadius: 5),
          with: .color(.black.opacity(0.6)))
        context.fill(
          Path(roundedRect: rect, cornerRadius: 3),
          with: .linearGradient(
            Gradient(colors: [Palette.gold.opacity(0.6), Palette.stone, Palette.ink]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        context.fill(
          Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 1),
          with: .color(Palette.ink))
        context.stroke(
          Path(roundedRect: rect, cornerRadius: 3),
          with: .color(active ? Palette.gold : Palette.mint), lineWidth: 1)
        context.draw(
          Text(room.circuit(at: tile) == 0 ? "I" : "II").font(
            .system(size: cell * 0.30, weight: .semibold, design: .serif)
          ).foregroundColor(active ? Palette.gold : Palette.mint), at: c)
        context.fill(
          Path(ellipseIn: CGRect(x: c.x - 2, y: rect.maxY - 6, width: 4, height: 4)),
          with: .color(active ? Palette.ruby : Palette.mint))
      }
      if let emitter = room.emitters.first(where: { $0.tile == tile }) {
        let active = state.power & (1 << emitter.circuit) != 0
        context.fill(
          Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 5), with: .color(Palette.ink))
        context.stroke(
          Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 5),
          with: .color(Palette.gold.opacity(0.5)), lineWidth: 1)
        context.fill(
          Path(ellipseIn: rect.insetBy(dx: cell * 0.16, dy: cell * 0.16)),
          with: .color(active ? Palette.ruby : Palette.muted))
      }
      if let sentry = room.sentries.first(where: { $0.tile == tile }) {
        let direction = Direction(rawValue: (sentry.facing.rawValue + state.turn) % 4)!
        context.fill(Path(ellipseIn: rect), with: .color(Palette.ink))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.amber), lineWidth: 1)
        context.draw(
          Text(Image(systemName: direction.symbol)).font(
            .system(size: cell * 0.27, weight: .medium)
          ).foregroundColor(Palette.amber), at: c)
      }
    }
  }
}

struct ThiefFigure: View {
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      ZStack {
        Circle().fill(Palette.paper.opacity(0.13)).blur(radius: 4).frame(width: w * 1.1)
        Circle().stroke(Palette.paper.opacity(0.65), lineWidth: 1).frame(width: w * 0.92).offset(
          y: h * 0.03)
        Ellipse().fill(.black.opacity(0.5)).frame(width: w * 0.8, height: h * 0.25).offset(
          y: h * 0.3)
        Capsule().fill(
          LinearGradient(
            colors: [Palette.paper.opacity(0.7), Palette.stone, Palette.ink],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        ).frame(
          width: w * 0.55, height: h * 0.62
        ).offset(y: h * 0.13)
        Capsule().fill(Palette.gold).frame(width: w * 0.12, height: h * 0.38).rotationEffect(
          .degrees(-22)
        ).offset(x: w * 0.2, y: h * 0.1)
        Ellipse().fill(Palette.paper).frame(width: w * 0.39, height: h * 0.32).offset(y: -h * 0.07)
        Capsule().fill(Palette.ink).frame(width: w * 0.4, height: h * 0.085).offset(y: -h * 0.04)
        Ellipse().fill(Palette.ink).overlay(
          Ellipse().stroke(Palette.gold.opacity(0.8), lineWidth: 1)
        )
        .frame(width: w * 0.86, height: h * 0.23).rotationEffect(.degrees(-12)).offset(y: -h * 0.2)
        RoundedRectangle(cornerRadius: 4).fill(Palette.ink).overlay(
          RoundedRectangle(cornerRadius: 4).stroke(Palette.gold.opacity(0.5), lineWidth: 0.8)
        )
        .frame(width: w * 0.5, height: h * 0.28).rotationEffect(.degrees(-12)).offset(y: -h * 0.3)
      }
      .frame(width: w, height: h)
    }
  }
}
