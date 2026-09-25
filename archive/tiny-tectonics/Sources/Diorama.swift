import SwiftUI

enum Earth {
  static let night = Color(hex: 0x101F1C)
  static let surface = Color(hex: 0x273D35)
  static let brass = Color(hex: 0xD2B27A)
  static let paper = Color(hex: 0xF5EBD8)
  static let ink = Color(hex: 0x263D36)
  static let muted = Color(hex: 0xA2B5A9)
  static let copper = Color(hex: 0xD9825A)
  static let clay = Color(hex: 0xB95E43)
  static let sand = Color(hex: 0xE7CC97)
  static let teal = Color(hex: 0x6DCAB5)
  static let gold = Color(hex: 0xE9AD42)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct IslandProjection {
  let scale: CGFloat
  let origin: CGPoint

  init(level: Landscape, size: CGSize) {
    let xs = level.route.map { CGFloat($0.x - $0.y) * 49 }
    let ys = level.route.map { CGFloat($0.x + $0.y) * 27 }
    let minX = (xs.min() ?? 0) - 68
    let maxX = (xs.max() ?? 0) + 68
    let minY = (ys.min() ?? 0) - 108
    let maxY = (ys.max() ?? 0) + 65
    scale = min(size.width / (maxX - minX), size.height / (maxY - minY))
    origin = CGPoint(
      x: size.width / 2 - (minX + maxX) / 2 * scale,
      y: size.height / 2 - (minY + maxY) / 2 * scale)
  }

  func point(_ grid: GridPoint, height: Double = 0) -> CGPoint {
    CGPoint(
      x: origin.x + CGFloat(grid.x - grid.y) * 49 * scale,
      y: origin.y + (CGFloat(grid.x + grid.y) * 27 - height * 16) * scale)
  }
}

struct HeightVector: VectorArithmetic {
  var values: [Double]
  static let zero = HeightVector(values: [])
  static func + (lhs: HeightVector, rhs: HeightVector) -> HeightVector {
    HeightVector(
      values: (0..<max(lhs.values.count, rhs.values.count)).map {
        (lhs.values.indices.contains($0) ? lhs.values[$0] : 0)
          + (rhs.values.indices.contains($0) ? rhs.values[$0] : 0)
      })
  }
  static func - (lhs: HeightVector, rhs: HeightVector) -> HeightVector {
    lhs + HeightVector(values: rhs.values.map { -$0 })
  }
  mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }
  var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }
}

struct Diorama: View, Animatable {
  let level: Landscape
  let heights: [Int]
  var selected: Int? = nil
  var travel: Double = 0
  var running = false
  var celebration = false
  var presentation = false
  var onSelect: ((Int) -> Void)? = nil
  var terrain: HeightVector

  var animatableData: HeightVector {
    get { terrain }
    set { terrain = newValue }
  }

  init(
    level: Landscape, heights: [Int], selected: Int? = nil, travel: Double = 0,
    running: Bool = false, celebration: Bool = false, presentation: Bool = false,
    onSelect: ((Int) -> Void)? = nil
  ) {
    self.level = level
    self.heights = heights
    self.selected = selected
    self.travel = travel
    self.running = running
    self.celebration = celebration
    self.presentation = presentation
    self.onSelect = onSelect
    terrain = HeightVector(values: heights.map(Double.init))
  }

  var body: some View {
    GeometryReader { geometry in
      let projection = IslandProjection(level: level, size: geometry.size)
      ZStack {
        Canvas { context, size in
          drawWorld(context: context, size: size, p: projection)
        }
        .accessibilityHidden(true)
        if let onSelect {
          ForEach(heights.indices, id: \.self) { index in
            let point = projection.point(level.route[index], height: terrain.values[index])
            Button {
              onSelect(index)
            } label: {
              Color.clear.contentShape(Rectangle())
            }
            .frame(width: max(44, 68 * projection.scale), height: max(44, 43 * projection.scale))
            .position(point)
            .accessibilityLabel(
              "Plate \(index + 1), elevation \(heights[index])\(level.fixed.contains(index) ? ", anchored" : "")"
            )
            .accessibilityHint("Select this terrain plate")
            .accessibilityIdentifier("plate-\(index + 1)")
          }
        }
      }
    }
  }

  private func drawWorld(context: GraphicsContext, size: CGSize, p: IslandProjection) {
    let s = p.scale
    func offset(_ point: CGPoint, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: point.x + x * s, y: point.y + y * s)
    }
    func polygon(_ points: [CGPoint]) -> Path {
      Path { path in
        path.addLines(points)
        path.closeSubpath()
      }
    }
    func diamond(_ center: CGPoint, _ width: CGFloat, _ height: CGFloat) -> Path {
      polygon([
        offset(center, 0, -height), offset(center, width, 0),
        offset(center, 0, height), offset(center, -width, 0),
      ])
    }
    let riverCenter = CGPoint(x: size.width * 0.48, y: size.height * 0.70)
    context.drawLayer { glow in
      glow.addFilter(.blur(radius: 28 * s))
      glow.fill(
        Path(
          ellipseIn: CGRect(
            x: size.width * 0.12, y: size.height * 0.35,
            width: size.width * 0.76, height: size.height * 0.55)),
        with: .color(Earth.teal.opacity(0.07)))
    }
    for ring in 0..<6 {
      let inset = CGFloat(ring) * 17 * s
      let rect = CGRect(
        x: riverCenter.x - 140 * s - inset, y: riverCenter.y - 43 * s - inset * 0.3,
        width: 280 * s + inset * 2, height: 86 * s + inset * 0.6)
      context.stroke(
        Path(ellipseIn: rect), with: .color(Earth.brass.opacity(ring == 0 ? 0.22 : 0.08)),
        lineWidth: 0.6)
    }
    var river = Path()
    river.move(to: CGPoint(x: size.width * 0.04, y: size.height * 0.64))
    river.addCurve(
      to: CGPoint(x: size.width * 0.96, y: size.height * 0.82),
      control1: CGPoint(x: size.width * 0.65, y: size.height * 0.5),
      control2: CGPoint(x: size.width * 0.22, y: size.height * 1.0))
    context.drawLayer { glow in
      glow.addFilter(.blur(radius: 12 * s))
      glow.stroke(
        river, with: .color(Earth.teal.opacity(0.18)),
        style: StrokeStyle(lineWidth: 42 * s, lineCap: .round))
    }
    context.stroke(
      river, with: .color(Color(hex: 0x385B50)),
      style: StrokeStyle(lineWidth: 39 * s, lineCap: .round))
    context.stroke(
      river,
      with: .linearGradient(
        Gradient(colors: [Color(hex: 0x1A5048), Color(hex: 0x5BAA98), Color(hex: 0x153B35)]),
        startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)),
      style: StrokeStyle(lineWidth: 34 * s, lineCap: .round))
    context.stroke(
      river, with: .color(Earth.teal.opacity(0.2)),
      style: StrokeStyle(lineWidth: 1 * s, lineCap: .round))
    for ripple in 0..<15 {
      let t = Double(ripple) / 15 + 0.015
      let u = 1 - t
      let x =
        (u * u * u * 0.04 + 3 * u * u * t * 0.65 + 3 * u * t * t * 0.22 + t * t * t * 0.96)
        * size.width
      let y =
        (u * u * u * 0.64 + 3 * u * u * t * 0.5 + 3 * u * t * t * 1.0 + t * t * t * 0.82)
        * size.height
      let drift = CGFloat((ripple * 13) % 17 - 8) * s
      var current = Path()
      current.move(to: CGPoint(x: x - 4 * s, y: y + drift))
      current.addQuadCurve(
        to: CGPoint(x: x + CGFloat(3 + ripple % 5) * s, y: y + drift - 1),
        control: CGPoint(x: x, y: y + drift - 2 * s))
      context.stroke(current, with: .color(.white.opacity(0.45)), lineWidth: 0.9 * s)
      if ripple % 4 == 0 {
        let stone = CGPoint(x: x, y: y + 17 * s)
        context.fill(
          diamond(stone, 5 + CGFloat(ripple % 3), 3),
          with: .color(Color(hex: 0x6C8A75)))
      }
    }

    for index in heights.indices {
      let base = p.point(level.route[index])
      context.drawLayer { shadow in
        shadow.addFilter(.blur(radius: 9 * s))
        shadow.fill(diamond(offset(base, 9, 28), 46, 22), with: .color(.black.opacity(0.55)))
      }
    }

    let order = heights.indices.sorted {
      level.route[$0].x + level.route[$0].y < level.route[$1].x + level.route[$1].y
    }
    for index in order {
      let top = p.point(level.route[index], height: terrain.values[index])
      let depth = terrain.values[index] * 7 + 24
      let west = offset(top, -44, 0)
      let south = offset(top, 0, 24)
      let east = offset(top, 44, 0)
      let weathering = CGFloat(index % 3)
      let leftRim = [west, offset(top, -29, 10 + weathering), offset(top, -17, 13), south]
      let rightRim = [south, offset(top, 15, 14 - weathering), offset(top, 31, 9), east]
      let rim = leftRim + rightRim.dropFirst()
      let plateau = polygon(
        rim + [offset(top, 28, -10), offset(top, 0, -24), offset(top, -26, -12)])
      let leftFace = polygon(leftRim + leftRim.reversed().map { offset($0, 0, depth) })
      let rightFace = polygon(rightRim + rightRim.reversed().map { offset($0, 0, depth) })
      context.fill(
        leftFace,
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xAF6046), Color(hex: 0x5C302C)]),
          startPoint: west, endPoint: offset(south, 0, depth)))
      context.fill(
        rightFace,
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xD49469), Color(hex: 0x82432F)]),
          startPoint: east, endPoint: offset(south, 0, depth)))
      context.drawLayer { strata in
        strata.clip(to: polygon(rim + rim.reversed().map { offset($0, 0, depth) }))
        let widths: [CGFloat] = [1.1, 3.8, 0.7, 2.4, 5.2, 0.8, 2.1]
        for band in 0..<7 {
          let d = depth * CGFloat(band + 1) / 8
          var line = Path()
          line.addLines(
            rim.enumerated().map { step, point in
              offset(point, 0, d + sin(Double(step * 2 + band + index)) * 1.7)
            })
          strata.stroke(
            line,
            with: .color(
              (band % 3 == 0 ? Earth.sand : Earth.copper)
                .opacity(band % 2 == 0 ? 0.48 : 0.3)),
            lineWidth: widths[band] * s)
        }
        for fleck in 0..<160 {
          let x = CGFloat((fleck * 43 + index * 7) % 89 - 44)
          let y = CGFloat((fleck * 31 + index * 13) % 103)
          let mark = offset(top, x, y)
          strata.fill(
            Path(CGRect(x: mark.x, y: mark.y, width: 0.6 * s, height: 0.4 * s)),
            with: .color(fleck % 2 == 0 ? Earth.sand.opacity(0.24) : .black.opacity(0.2)))
        }
        for crack in 0..<5 {
          let x = CGFloat(crack * 19 - 39)
          var line = Path()
          line.move(to: offset(top, x, 15))
          line.addLine(to: offset(top, x + 3, 29))
          line.addLine(to: offset(top, x + 1, 39))
          strata.stroke(line, with: .color(.black.opacity(0.11)), lineWidth: 0.6 * s)
        }
      }
      context.fill(
        plateau,
        with: .linearGradient(
          Gradient(colors: [Color(hex: 0xF9E9C3), Color(hex: 0xD6B47C)]),
          startPoint: offset(top, -30, -15), endPoint: offset(top, 30, 24)))
      context.stroke(plateau, with: .color(Color(hex: 0xFFE6B5).opacity(0.8)), lineWidth: 1.1 * s)
      context.drawLayer { texture in
        texture.clip(to: plateau)
        for fleck in 0..<110 {
          let point = offset(
            top, CGFloat((fleck * 17 + index * 11) % 87 - 43),
            CGFloat((fleck * 23) % 47 - 23))
          texture.fill(
            Path(ellipseIn: CGRect(x: point.x, y: point.y, width: 0.7 * s, height: 0.4 * s)),
            with: .color(Color(hex: 0x795A39).opacity(0.22)))
        }
      }
      for ring in 0..<3 {
        let contour = polygon(
          (0..<24).map { step in
            let angle = Double(step) * .pi / 12
            let variation = 1 + sin(angle * 3 + Double(index)) * 0.12
            return offset(
              top, -7 + cos(angle) * Double(31 - ring * 7) * variation,
              -4 + sin(angle) * Double(13 - ring * 3) * variation)
          })
        context.stroke(
          contour,
          with: .color(Color(hex: 0xB69B66).opacity(0.32)), lineWidth: 0.6 * s)
      }
      if selected == index {
        context.drawLayer { halo in
          halo.addFilter(.blur(radius: 4 * s))
          halo.stroke(plateau, with: .color(Earth.teal.opacity(0.55)), lineWidth: 6 * s)
        }
        context.stroke(plateau, with: .color(Earth.teal), lineWidth: 1.8 * s)
      }
      for rock in 0..<(1 + index % 3) {
        let center = offset(top, -12 + CGFloat(rock) * 6, -12 + CGFloat((rock + index) % 3))
        context.fill(diamond(center, 2.5, 1.8), with: .color(Color(hex: 0xA89A78).opacity(0.7)))
      }
      for tree in 0..<(index % 3 == 2 ? 1 : 2) {
        let trunk = offset(top, tree == 0 ? -24 : 23, tree == 0 ? -3 : -5)
        context.fill(
          polygon([offset(trunk, -3, 0), offset(trunk, 5, 3), offset(trunk, 16, -6)]),
          with: .color(Earth.ink.opacity(0.16)))
        var stem = Path()
        stem.move(to: trunk)
        stem.addLine(to: offset(trunk, 0, -11))
        context.stroke(stem, with: .color(Earth.copper), lineWidth: 2 * s)
        for tier in 0..<3 {
          let y = CGFloat(tier) * CGFloat(-4 - index % 2)
          let width = CGFloat(5 + (index + tree) % 3 - tier)
          context.fill(
            polygon([
              offset(trunk, -width, y - 4), offset(trunk, width, y - 4), offset(trunk, 0, y - 15),
            ]),
            with: .linearGradient(
              Gradient(colors: [Color(hex: 0x84A286), Color(hex: 0x2C5545)]),
              startPoint: offset(trunk, -width, 0), endPoint: offset(trunk, width, 0)))
          var needle = Path()
          needle.move(to: offset(trunk, 0, y - 14))
          needle.addLine(to: offset(trunk, 0, y - 5))
          context.stroke(needle, with: .color(Earth.sand.opacity(0.22)), lineWidth: 0.6 * s)
        }
      }
    }

    for index in 1..<heights.count {
      let from = p.point(level.route[index - 1], height: terrain.values[index - 1])
      let to = p.point(level.route[index], height: terrain.values[index])
      let safe = SlopeRules.fault(from: heights[index - 1], to: heights[index]) == nil
      var route = Path()
      route.move(to: from)
      route.addLine(to: to)
      if safe {
        context.stroke(
          route, with: .color(Color(hex: 0x704431).opacity(0.38)),
          style: StrokeStyle(lineWidth: 8 * s, lineCap: .round))
        context.stroke(
          route, with: .color(Color(hex: 0xFFF3D4)),
          style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round))
        context.stroke(
          route, with: .color(Earth.brass),
          style: StrokeStyle(lineWidth: 0.6 * s, dash: [1 * s, 4 * s]))
        if running, travel >= Double(index) {
          context.drawLayer { glow in
            glow.addFilter(.blur(radius: 2 * s))
            glow.stroke(route, with: .color(Earth.gold.opacity(0.55)), lineWidth: 5 * s)
          }
        }
      } else {
        context.stroke(
          route, with: .color(Earth.copper.opacity(0.5)),
          style: StrokeStyle(lineWidth: 1.5 * s, dash: [3 * s, 5 * s]))
        if !presentation {
          let center = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
          context.fill(
            Path(
              ellipseIn: CGRect(
                x: center.x - 6 * s, y: center.y - 6 * s, width: 12 * s, height: 12 * s)),
            with: .color(Color(hex: 0xA84730)))
          context.draw(
            Text("!").font(.system(size: 9 * s, weight: .heavy)).foregroundColor(.white), at: center
          )
        }
      }
    }

    for index in heights.indices {
      let top = p.point(level.route[index], height: terrain.values[index])
      let badge = offset(top, 0, 16)
      let selectedPlate = selected == index
      if !presentation {
        context.fill(
          Path(
            ellipseIn: CGRect(x: badge.x - 8 * s, y: badge.y - 8 * s, width: 16 * s, height: 16 * s)
          ),
          with: .color(selectedPlate ? Earth.teal : Earth.ink.opacity(0.85)))
        context.draw(
          Text("\(index + 1)").font(.system(size: 9 * s, weight: .semibold, design: .monospaced))
            .foregroundColor(selectedPlate ? Earth.ink : Earth.paper),
          at: badge)
      }
      if level.fossils.contains(index), !running || travel < Double(index) {
        let gem = offset(top, 0, -11)
        context.drawLayer { glow in
          glow.addFilter(.blur(radius: 5 * s))
          glow.fill(diamond(gem, 6, 9), with: .color(Earth.gold.opacity(0.45)))
        }
        context.fill(diamond(gem, 6, 9), with: .color(Earth.gold))
        context.fill(
          polygon([offset(gem, 0, -9), offset(gem, 6, 0), offset(gem, 0, 4)]),
          with: .color(Color(hex: 0xFFE2A1)))
        context.stroke(diamond(gem, 6, 9), with: .color(Earth.copper.opacity(0.5)), lineWidth: 0.7)
      }
    }

    let exit = p.point(level.route.last!, height: terrain.values.last!)
    let portal = offset(exit, 0, -15)
    context.fill(diamond(offset(exit, 0, 2), 16, 9), with: .color(Color(hex: 0xA88960)))
    context.fill(diamond(exit, 16, 9), with: .color(Color(hex: 0xF0D5A2)))
    var gate = Path()
    gate.move(to: offset(exit, -10, 0))
    gate.addLine(to: offset(exit, -10, -22))
    gate.addCurve(
      to: offset(exit, 10, -22),
      control1: offset(exit, -10, -38), control2: offset(exit, 10, -38))
    gate.addLine(to: offset(exit, 10, 0))
    context.drawLayer { glow in
      glow.addFilter(.blur(radius: 9 * s))
      glow.fill(diamond(portal, 12, 18), with: .color(Earth.teal.opacity(0.5)))
    }
    context.stroke(gate, with: .color(Color(hex: 0x4E6150)), lineWidth: 9 * s)
    context.stroke(
      gate,
      with: .linearGradient(
        Gradient(colors: [Color(hex: 0xF8E4B6), Color(hex: 0xA98F5D)]),
        startPoint: offset(exit, -10, -32), endPoint: exit), lineWidth: 6 * s)
    context.stroke(gate, with: .color(Earth.teal), lineWidth: 1.4 * s)

    let bounded = min(max(travel, 0), Double(heights.count - 1))
    let before = Int(bounded)
    let after = min(before + 1, heights.count - 1)
    let a = p.point(level.route[before], height: terrain.values[before])
    let b = p.point(level.route[after], height: terrain.values[after])
    let blend = bounded - Double(before)
    let explorer = CGPoint(x: a.x + (b.x - a.x) * blend, y: a.y + (b.y - a.y) * blend - 8 * s)
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: explorer.x - 10 * s, y: explorer.y + 5 * s, width: 22 * s, height: 8 * s)),
      with: .color(Earth.ink.opacity(0.2)))
    let sphere = Path(
      ellipseIn: CGRect(x: explorer.x - 9 * s, y: explorer.y - 9 * s, width: 18 * s, height: 18 * s)
    )
    context.fill(
      sphere,
      with: .radialGradient(
        Gradient(colors: [Color.white, Color(hex: 0xECE5C9), Color(hex: 0x9B9D86)]),
        center: offset(explorer, -3, -4), startRadius: 1, endRadius: 15 * s))
    context.stroke(sphere, with: .color(Earth.ink.opacity(0.2)), lineWidth: 0.7)
    let angle = travel * 7
    let speck = offset(explorer, cos(angle) * 5, sin(angle) * 5)
    context.fill(
      Path(ellipseIn: CGRect(x: speck.x - 2 * s, y: speck.y - 2 * s, width: 4 * s, height: 4 * s)),
      with: .color(Earth.copper))
    if running, before != after {
      for mote in 1...6 {
        let lag = max(0, blend - Double(mote) * 0.04)
        let dust = CGPoint(
          x: a.x + (b.x - a.x) * lag + sin(Double(mote) * 3) * 4 * s,
          y: a.y + (b.y - a.y) * lag - 2 * s)
        context.fill(
          Path(ellipseIn: CGRect(x: dust.x, y: dust.y, width: 2.5 * s, height: 2.5 * s)),
          with: .color(Earth.gold.opacity(0.7 - Double(mote) * 0.08)))
      }
    }
    if celebration {
      for dot in 0..<28 {
        let angle = Double(dot) * 2.399
        let radius = CGFloat(35 + (dot * 17) % 90) * s
        let point = CGPoint(
          x: exit.x + cos(angle) * radius, y: exit.y - 40 * s + sin(angle) * radius * 0.6)
        context.fill(
          diamond(point, 2, 3), with: .color(dot % 2 == 0 ? Earth.gold : Earth.teal.opacity(0.6)))
      }
    }
  }
}
