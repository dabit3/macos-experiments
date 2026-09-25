import SwiftUI

final class TerrainImage: ObservableObject {
  let image: CGImage?
  init(_ island: Island) {
    var pixels: [UInt8] = []
    pixels.reserveCapacity(island.n * island.n * 4)
    for tile in island.terrain {
      pixels += [
        UInt8((tile.rgb >> 16) & 255), UInt8((tile.rgb >> 8) & 255), UInt8(tile.rgb & 255), 255,
      ]
    }
    let provider = CGDataProvider(data: Data(pixels) as CFData)
    image = provider.flatMap {
      CGImage(
        width: island.n, height: island.n, bitsPerComponent: 8, bitsPerPixel: 32,
        bytesPerRow: island.n * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: $0, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
  }
}
struct Camera {
  let x, y, scale: Double
  let size: CGSize
  @MainActor init(match: MatchReplica, size: CGSize) {
    self.size = size
    if let bus = match.state?.bus, match.target?.s == .inBus {
      x = bus.x
      y = bus.y
    } else {
      x = match.target?.x ?? match.start.rules.mapSize / 2
      y = match.target?.y ?? match.start.rules.mapSize / 2
    }
    let altitude = match.target?.s == .dropping ? match.target?.alt ?? 0 : 0
    scale = min(size.width, size.height) / ((size.width < 650 ? 46 : 60) * (1 + altitude * 0.9))
  }
  func world(_ point: CGPoint) -> CGPoint {
    CGPoint(x: x + (point.x - size.width / 2) / scale, y: y + (point.y - size.height / 2) / scale)
  }
  func visible(_ px: Double, _ py: Double, padding: Double = 8) -> Bool {
    abs(px - x) < size.width / scale / 2 + padding
      && abs(py - y) < size.height / scale / 2 + padding
  }
}
struct GameCanvas: View {
  @ObservedObject var match: MatchReplica
  let catalogue: Catalogue
  let terrain: TerrainImage
  let reducedMotion: Bool
  let aim: Double
  var body: some View {
    TimelineView(.animation(minimumInterval: reducedMotion ? 1.0 / 30 : 1.0 / 60)) { timeline in
      Canvas { context, size in
        let camera = Camera(match: match, size: size)
        var world = context
        world.translateBy(x: size.width / 2, y: size.height / 2)
        world.scaleBy(x: camera.scale, y: camera.scale)
        world.translateBy(x: -camera.x, y: -camera.y)
        let rules = match.start.rules
        let island = match.island
        if let image = terrain.image {
          world.draw(
            Image(decorative: image, scale: 1),
            in: CGRect(x: 0, y: 0, width: rules.mapSize, height: rules.mapSize))
        }
        for structure in island.structures.values
        where camera.visible(island.center(structure.gx), island.center(structure.gy)) {
          drawStructure(structure, context: world, tile: rules.tileSize)
        }
        for chest in island.chests.values where camera.visible(chest.x, chest.y) {
          if !chest.o { world.ellipse(chest.x, chest.y, 3.2, 3.2, .yellow.opacity(0.22)) }
          world.rectangle(
            CGRect(x: chest.x - 0.9, y: chest.y - 0.6, width: 1.8, height: 1.2),
            chest.o ? Color(rgb: 0x7A5A3A) : Color(rgb: 0xC98A2E), radius: 0.2)
          world.rectangle(
            CGRect(x: chest.x - 0.16, y: chest.y - 0.6, width: 0.32, height: 1.2), .yellow)
          if chest.o {
            world.line(
              [
                CGPoint(x: chest.x - 0.8, y: chest.y - 0.7),
                CGPoint(x: chest.x + 0.8, y: chest.y - 0.7),
              ], .black.opacity(0.6), width: 0.3)
          }
        }
        for drop in match.loot where camera.visible(drop.x, drop.y) {
          drawLoot(drop, context: world, at: timeline.date)
        }
        for node in island.nodes.values where node.hp > 0 && camera.visible(node.x, node.y) {
          drawNode(node, context: world)
        }
        for player in match.players.values where player.s != .inBus && player.s != .eliminated {
          let position = match.position(player, at: timeline.date)
          if camera.visible(position.x, position.y) {
            drawPlayer(player, x: position.x, y: position.y, context: world, at: timeline.date)
          }
        }
        if let me = match.me, me.bm && me.s == .alive {
          let tile = targetTile(me, island: island)
          let box = CGRect(
            x: Double(tile.x) * rules.tileSize + 0.1, y: Double(tile.y) * rules.tileSize + 0.1,
            width: rules.tileSize - 0.2, height: rules.tileSize - 0.2)
          let sufficient = (me.mats?[safe: (me.bmat ?? .wood).index] ?? 0) >= rules.pieceCost
          let free = island.structures[island.key(tile.x, tile.y)] == nil
          let color: Color =
            sufficient && free && island.inBounds(tile.x, tile.y) ? .lfShield : .lfDanger
          world.rectangle(box, color.opacity(0.2), radius: 0.2)
          world.stroke(
            Path(roundedRect: box, cornerRadius: 0.2), with: .color(color), lineWidth: 0.18)
          world.label(
            (me.bp ?? .wall).rawValue.uppercased(), box.midX, box.midY, size: 0.75, color: color)
        }
        drawEffects(context: world, at: timeline.date)
        if let storm = match.state?.storm {
          var outside = Path(
            CGRect(x: -1000, y: -1000, width: rules.mapSize + 2000, height: rules.mapSize + 2000))
          let eye = CGRect(
            x: storm.cx - storm.r, y: storm.cy - storm.r, width: storm.r * 2, height: storm.r * 2)
          outside.addEllipse(in: eye)
          world.fill(
            outside, with: .color(.lfStorm.opacity(0.35)), style: FillStyle(eoFill: true))
          world.stroke(Path(ellipseIn: eye), with: .color(.lfStorm), lineWidth: 0.5)
          world.stroke(
            Path(
              ellipseIn: CGRect(
                x: storm.tx - storm.tr, y: storm.ty - storm.tr, width: storm.tr * 2,
                height: storm.tr * 2)),
            with: .color(.white.opacity(0.6)),
            style: StrokeStyle(lineWidth: 0.15, dash: [0.8, 0.8]))
        }
        if let bus = match.state?.bus {
          world.ellipse(bus.x, bus.y - 3, 7, 9, .lfShield)
          world.rectangle(
            CGRect(x: bus.x - 1.6, y: bus.y + 1, width: 3.2, height: 5.8), .lfAccent, radius: 0.5)
          world.rectangle(
            CGRect(x: bus.x - 1.2, y: bus.y + 1.4, width: 2.4, height: 1.2), .lfShield,
            radius: 0.2)
          world.line(
            [CGPoint(x: bus.x - 2, y: bus.y - 1), CGPoint(x: bus.x - 1, y: bus.y + 1)], .white,
            width: 0.12)
          world.line(
            [CGPoint(x: bus.x + 2, y: bus.y - 1), CGPoint(x: bus.x + 1, y: bus.y + 1)], .white,
            width: 0.12)
        }
        if let me = match.me, me.s == .alive {
          let cx = (me.x - camera.x) * camera.scale + size.width / 2 + cos(aim) * 4 * camera.scale
          let cy = (me.y - camera.y) * camera.scale + size.height / 2 + sin(aim) * 4 * camera.scale
          context.line([CGPoint(x: cx - 7, y: cy), CGPoint(x: cx - 2, y: cy)], .white)
          context.line([CGPoint(x: cx + 2, y: cy), CGPoint(x: cx + 7, y: cy)], .white)
          context.line([CGPoint(x: cx, y: cy - 7), CGPoint(x: cx, y: cy - 2)], .white)
          context.line([CGPoint(x: cx, y: cy + 2), CGPoint(x: cx, y: cy + 7)], .white)
        }
      }
    }.background(Color(rgb: 0x0E2A40)).allowsHitTesting(false)
  }
  func targetTile(_ player: Player, island: Island) -> (x: Int, y: Int) {
    let reach = island.rules.tileSize * 1.1
    return (island.tile(player.x + cos(aim) * reach), island.tile(player.y + sin(aim) * reach))
  }
  private func drawStructure(_ value: Structure, context: GraphicsContext, tile: Double) {
    let rect = CGRect(
      x: Double(value.gx) * tile + 0.1, y: Double(value.gy) * tile + 0.1, width: tile - 0.2,
      height: tile - 0.2)
    let color = materialColor(value.m)
    context.rectangle(rect.offsetBy(dx: 0.15, dy: 0.3), .black.opacity(0.22), radius: 0.2)
    context.rectangle(rect, color.opacity(value.p == .wall ? 1 : 0.75), radius: 0.2)
    context.stroke(
      Path(roundedRect: rect, cornerRadius: 0.2), with: .color(.black.opacity(0.35)),
      lineWidth: 0.16)
    if value.p == .floor || value.m == .wood {
      for offset in stride(from: 0.6, to: tile, by: 0.7) {
        context.line(
          [
            CGPoint(x: rect.minX, y: rect.minY + offset),
            CGPoint(x: rect.maxX, y: rect.minY + offset),
          ], .black.opacity(0.2), width: 0.06)
      }
    }
    if value.p == .wall {
      context.rectangle(
        CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 0.45), .white.opacity(0.25),
        radius: 0.1)
      if value.e == .door {
        context.rectangle(
          CGRect(x: rect.midX - 0.65, y: rect.minY, width: 1.3, height: rect.height),
          .lfInk.opacity(0.9), radius: 0.1)
      } else if value.e == .window {
        context.rectangle(
          CGRect(x: rect.midX - 0.7, y: rect.midY - 0.65, width: 1.4, height: 1.3), .lfInk,
          radius: 0.1)
      }
    } else if value.p == .ramp {
      var rotated = context
      rotated.translateBy(x: rect.midX, y: rect.midY)
      rotated.rotate(by: .degrees(Double(value.d) * 90))
      rotated.line(
        [CGPoint(x: -1, y: -1), CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 1)], .white.opacity(0.8),
        width: 0.2)
    } else if value.p == .roof {
      context.line(
        [
          CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.midX, y: rect.minY),
          CGPoint(x: rect.maxX, y: rect.maxY),
        ], .white.opacity(0.65), width: 0.18)
    }
    if value.hp < value.max {
      context.rectangle(
        CGRect(
          x: rect.minX, y: rect.maxY - 0.2,
          width: rect.width * Double(value.hp) / Double(value.max), height: 0.18), .lfHealth)
    }
  }
  private func drawNode(_ node: ResourceNode, context: GraphicsContext) {
    let x = node.x
    let y = node.y
    context.ellipse(
      x + 0.4, y + 0.8, node.k.radius * 2.5, node.k.radius * 1.8, .black.opacity(0.25))
    switch node.k {
    case .tree:
      context.rectangle(
        CGRect(x: x - 0.3, y: y, width: 0.6, height: 1.6), Color(rgb: 0x775130), radius: 0.1)
      context.ellipse(x, y, 3.5, 3.8, Color(rgb: 0x396C42))
      context.ellipse(
        x - 0.3, y - 0.5, 2.8, 2.8, Color(rgb: node.v.isMultiple(of: 2) ? 0x60964A : 0x4C8848))
      context.ellipse(x - 0.55, y - 0.9, 1.6, 1.5, Color(rgb: 0x84AE62))
    case .rock:
      var path = Path()
      let points = [
        CGPoint(x: x - 1.3, y: y + 0.7), CGPoint(x: x - 1.5, y: y - 0.4),
        CGPoint(x: x - 0.5, y: y - 1.3),
        CGPoint(x: x + 0.9, y: y - 0.8), CGPoint(x: x + 1.4, y: y + 0.7),
      ]
      path.addLines(points)
      path.closeSubpath()
      context.fill(path, with: .color(Color(rgb: 0x91A5B2)))
      context.line([points[1], points[2], points[3]], Color(rgb: 0xCAD6D7), width: 0.22)
    case .car:
      let palette: [UInt32] = [0xB65F4B, 0x4B8A9D, 0xB5A868, 0x617F68]
      for sign in [-1.0, 1] {
        context.rectangle(
          CGRect(x: x + sign * 1.05 - 0.2, y: y - 1.1, width: 0.4, height: 0.65), .black,
          radius: 0.1)
        context.rectangle(
          CGRect(x: x + sign * 1.05 - 0.2, y: y + 0.8, width: 0.4, height: 0.65), .black,
          radius: 0.1)
      }
      context.rectangle(
        CGRect(x: x - 1, y: y - 1.7, width: 2, height: 3.6), Color(rgb: palette[node.v % 4]),
        radius: 0.4)
      context.rectangle(
        CGRect(x: x - 0.8, y: y - 0.6, width: 1.6, height: 1.2), .lfInk, radius: 0.3)
    }
    if node.hp < node.max { context.label("\(node.hp)", x, y - 2, size: 0.7) }
  }
  private func drawLoot(_ drop: Loot, context: GraphicsContext, at date: Date) {
    let color = Color(rgb: (drop.i.r ?? .common).rgb)
    let x = drop.x
    let y =
      drop.y + (reducedMotion ? 0 : sin(date.timeIntervalSince1970 * 4 + Double(drop.id)) * 0.12)
    context.ellipse(x, y, 2.2, 2.2, color.opacity(0.3))
    switch drop.i.t {
    case .weapon:
      context.rectangle(CGRect(x: x - 0.8, y: y - 0.2, width: 1.6, height: 0.4), color, radius: 0.1)
      context.rectangle(CGRect(x: x - 0.2, y: y, width: 0.4, height: 0.5), color)
    case .consumable:
      context.rectangle(
        CGRect(x: x - 0.4, y: y - 0.5, width: 0.8, height: 1), .lfShield, radius: 0.2)
      context.rectangle(CGRect(x: x - 0.2, y: y - 0.65, width: 0.4, height: 0.2), .white)
    case .ammo:
      for offset in [-0.32, 0, 0.32] {
        context.rectangle(
          CGRect(x: x + offset - 0.12, y: y - 0.4, width: 0.24, height: 0.8), .yellow, radius: 0.1)
      }
    case .material:
      context.rectangle(
        CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1), materialColor(drop.i.m ?? .wood),
        radius: 0.1)
    }
    if let me = match.me, hypot(me.x - x, me.y - y) < 3 {
      context.label(drop.i.label, x, y - 1.3, size: 0.8, color: color)
    }
  }
  private func drawPlayer(
    _ player: Player, x: Double, y: Double, context: GraphicsContext, at date: Date
  ) {
    let outfit = catalogue.cosmetic(player.ld.o)
    let primary = Color(rgb: outfit?.primary ?? 0x4C6A8A)
    let secondary = Color(rgb: outfit?.secondary ?? 0x2E3D4F)
    let accent = Color(rgb: outfit?.accent ?? 0xE8EDF2)
    var canvas = context
    canvas.translateBy(x: x, y: y - player.alt * 3)
    canvas.ellipse(0.2, 0.5 + player.alt * 3, 1.8, 1.2, .black.opacity(0.3))
    let mate = player.t == match.me?.t
    if mate || player.id == match.localID {
      canvas.stroke(
        Path(ellipseIn: CGRect(x: -1.1, y: -1.1, width: 2.2, height: 2.2)),
        with: .color(player.id == match.localID ? .white : .lfShield), lineWidth: 0.15)
    }
    if player.alt > 0.02 {
      let glider = catalogue.cosmetic(player.ld.g)
      var canopy = Path()
      canopy.move(to: CGPoint(x: -1.8, y: -0.4))
      canopy.addQuadCurve(to: CGPoint(x: 1.8, y: -0.4), control: CGPoint(x: 0, y: -3))
      canopy.addQuadCurve(to: CGPoint(x: -1.8, y: -0.4), control: CGPoint(x: 0, y: -1))
      canvas.fill(canopy, with: .color(Color(rgb: glider?.primary ?? 0x4C6A8A)))
      canvas.stroke(canopy, with: .color(Color(rgb: glider?.accent ?? 0xE8EDF2)), lineWidth: 0.12)
    }
    var body = canvas
    body.rotate(by: .radians(player.id == match.localID ? aim : player.a))
    let pick = catalogue.cosmetic(player.ld.p)
    body.rectangle(
      CGRect(x: 0.3, y: -0.12, width: player.slot > 0 ? 1.8 : 1.6, height: 0.24),
      player.slot > 0 ? .lfInk : Color(rgb: pick?.secondary ?? 0x3E2A18), radius: 0.1)
    if player.slot == 0 {
      body.rectangle(
        CGRect(x: 1.4, y: -0.5, width: 0.4, height: 1), Color(rgb: pick?.primary ?? 0x8B6B4A),
        radius: 0.1)
    }
    for sign in [-1.0, 1] {
      body.rectangle(
        CGRect(x: -0.48, y: sign * 0.58 - 0.28, width: 0.76, height: 0.55), primary, radius: 0.2)
    }
    body.rectangle(CGRect(x: -0.74, y: -0.55, width: 0.98, height: 1.1), secondary, radius: 0.25)
    body.rectangle(CGRect(x: -0.48, y: -0.53, width: 1.17, height: 1.06), primary, radius: 0.4)
    body.rectangle(
      CGRect(x: 0.38, y: -0.36, width: 0.28, height: 0.72), .lfInk, radius: 0.12)
    body.rectangle(CGRect(x: 0.47, y: -0.27, width: 0.1, height: 0.54), accent, radius: 0.05)
    body.line(
      [CGPoint(x: -0.32, y: -0.23), CGPoint(x: 0.15, y: -0.32)], .white.opacity(0.65), width: 0.08)
    if player.em && !reducedMotion {
      for index in 0..<5 {
        let angle = date.timeIntervalSince1970 * 3 + Double(index) * 1.26
        canvas.ellipse(cos(angle) * 1.7, sin(angle) * 1.7, 0.3, 0.3, accent)
      }
    }
    canvas.label(
      player.n + (player.con ? "" : " · offline"), 0, -2.6, size: 0.72,
      color: mate ? .lfShield : .white)
    if mate && player.id != match.localID {
      canvas.rectangle(
        CGRect(x: -1.3, y: -1.8, width: 2.6 * Double(player.hp) / 100, height: 0.2), .lfHealth)
      canvas.rectangle(
        CGRect(x: -1.3, y: -2.1, width: 2.6 * Double(player.sh) / 100, height: 0.18), .lfShield)
    }
  }
  private func drawEffects(context: GraphicsContext, at date: Date) {
    guard !reducedMotion else { return }
    for effect in match.effects {
      let age = date.timeIntervalSince(effect.date)
      let event = effect.event
      if age < 0.18, case .shots(let shots) = event.s, let shooter = match.players[event.p ?? 0] {
        for shot in shots {
          context.line(
            [CGPoint(x: shooter.x, y: shooter.y), CGPoint(x: shot.x, y: shot.y)],
            .lfAmber.opacity(1 - age / 0.18), width: 0.09)
        }
      }
      if age < 0.8, let damage = event.d, let victim = match.players[event.p ?? 0] {
        context.label(
          "\(damage)", victim.x, victim.y - 2 - age * 2, size: 1.1,
          color: event.sh == true ? .lfShield : .lfDanger)
      }
    }
  }
}
func materialColor(_ material: BuildingMaterial) -> Color {
  Color(rgb: material == .wood ? 0xBE8D57 : material == .stone ? 0xB7785F : 0x91A5B2)
}
extension Collection {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
