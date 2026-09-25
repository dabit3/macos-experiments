import SwiftUI

struct BoardGeometry {
  let cell: CGFloat
  let origin: CGPoint
  init(size: CGSize, level: Level) {
    cell = max(
      1, min(size.width / CGFloat(level.width + 1), size.height / CGFloat(level.height + 2)))
    origin = CGPoint(
      x: (size.width - CGFloat(level.width) * cell) / 2,
      y: (size.height - CGFloat(level.height) * cell) / 2 + cell * 0.3)
  }
}

struct KitchenCanvas: View {
  let level: Level
  var snapshot: Snapshot?
  var previous: Snapshot?
  var received = Date()
  var playerID: String?
  var effects: [VisualEvent] = []
  var onTile: ((Int, Int) -> Void)?
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      TimelineView(.animation(minimumInterval: 1 / 60, paused: snapshot == nil || reduceMotion)) {
        timeline in
        Canvas { context, size in
          let layout = BoardGeometry(size: size, level: level)
          context.translateBy(x: layout.origin.x, y: layout.origin.y)
          context.scaleBy(x: layout.cell, y: layout.cell)
          let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
          var painter = KitchenPainter(context: context, time: time, dark: scheme == .dark)
          painter.frame(width: Double(level.width), height: Double(level.height))
          let cells = Kitchen.cells(level: level, snapshot: snapshot)
          for cell in cells { painter.ground(cell) }
          for cell in cells.sorted(by: { $0.y < $1.y }) { painter.station(cell) }
          for cell in cells { painter.contents(cell) }
          if let snapshot {
            if let me = snapshot.chefs.first(where: { $0.id == playerID }) {
              painter.target(
                x: floor(me.x) + Double(me.facing.dx), y: floor(me.y) + Double(me.facing.dy))
            }
            let alpha =
              reduceMotion ? 1 : min(1, max(0, timeline.date.timeIntervalSince(received) / 0.05))
            for chef in snapshot.chefs.sorted(by: { $0.y < $1.y }) {
              var drawn = chef
              var moving = false
              if let old = previous?.chefs.first(where: { $0.id == chef.id }),
                hypot(old.x - chef.x, old.y - chef.y) < 2
              {
                moving = hypot(old.x - chef.x, old.y - chef.y) > 0.002
                drawn.x = old.x + (chef.x - old.x) * alpha
                drawn.y = old.y + (chef.y - old.y) * alpha
              }
              painter.chef(drawn, local: chef.id == playerID, moving: moving && !reduceMotion)
            }
            if !reduceMotion {
              for effect in effects {
                painter.effect(
                  effect.event, age: timeline.date.timeIntervalSince(effect.date),
                  snapshot: snapshot)
              }
            }
          } else {
            for cell in cells where ["1", "2", "3", "4"].contains(cell.symbol) {
              let slot = (cell.symbol.wholeNumberValue ?? 1) - 1
              painter.ellipse(cell.x + 0.25, cell.y + 0.25, 0.5, 0.5, PantryStyle.chefs[slot])
            }
          }
        }
      }
      .contentShape(Rectangle())
      .onTapGesture { point in
        let layout = BoardGeometry(size: geometry.size, level: level)
        let x = Int(floor((point.x - layout.origin.x) / layout.cell))
        let y = Int(floor((point.y - layout.origin.y) / layout.cell))
        if x >= 0 && y >= 0 && x < level.width && y < level.height { onTile?(x, y) }
      }
      .accessibilityLabel("\(level.name) kitchen. \(level.gimmick)")
    }
  }
}

struct IngredientPicture: View {
  let ingredient: Ingredient
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width, y: size.height)
      var painter = KitchenPainter(context: context, time: 0, dark: false)
      painter.ingredient(ingredient, chopped: false, x: 0.5, y: 0.5, scale: 1.3)
    }.accessibilityLabel(ingredient.rawValue)
  }
}

struct ChefPortrait: View {
  let slot: Int
  let bot: Bool
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width, y: size.width)
      var painter = KitchenPainter(context: context, time: 0, dark: false)
      let chef = Chef(
        id: "", slot: slot, name: "", bot: bot, x: 0.5, y: 1.0,
        facing: .down, held: nil, dash: nil, working: nil, emote: nil, offline: nil)
      painter.chef(chef, local: false, moving: false, label: false)
    }.accessibilityHidden(true)
  }
}

struct KitchenPainter {
  var context: GraphicsContext
  let time: Double
  let dark: Bool
  private let ink = PantryStyle.ink
  private let cream = PantryStyle.cream

  func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
    CGRect(x: x, y: y, width: w, height: h)
  }
  mutating func box(
    _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color, radius: Double = 0.07
  ) {
    context.fill(Path(roundedRect: rect(x, y, w, h), cornerRadius: radius), with: .color(color))
  }
  mutating func ellipse(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
    context.fill(Path(ellipseIn: rect(x, y, w, h)), with: .color(color))
  }
  mutating func line(_ points: [CGPoint], _ color: Color, width: Double = 0.03) {
    var path = Path()
    path.addLines(points)
    context.stroke(
      path, with: .color(color),
      style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
  }
  mutating func text(
    _ value: String, x: Double, y: Double, size: Double = 0.2, color: Color = .white
  ) {
    context.draw(
      Text(value).font(.custom("Nunito-ExtraBold", fixedSize: size)).foregroundStyle(color),
      at: CGPoint(x: x, y: y))
  }
  mutating func tag(_ value: String, x: Double, y: Double, color: Color, fontSize: Double = 0.17) {
    let width = max(0.5, Double(value.count) * fontSize * 0.57 + 0.17)
    box(x - width / 2, y - 0.12, width, 0.25, color, radius: 0.1)
    text(value, x: x, y: y, size: fontSize)
  }
  mutating func frame(width: Double, height: Double) {
    box(-0.32, -0.23, width + 0.64, height + 0.66, ink.opacity(0.4), radius: 0.35)
    box(-0.25, -0.25, width + 0.5, height + 0.5, PantryStyle.butter, radius: 0.3)
    box(-0.19, -0.19, width + 0.38, height + 0.38, Color(hex: 0xB7654B), radius: 0.22)
    for x in stride(from: 0.0, to: width, by: 0.55) {
      line([CGPoint(x: x, y: -0.19), CGPoint(x: x, y: 0)], ink.opacity(0.4))
      line([CGPoint(x: x, y: height), CGPoint(x: x, y: height + 0.19)], ink.opacity(0.4))
    }
  }
  mutating func ground(_ cell: KitchenCell) {
    let x = cell.x
    let y = cell.y
    if cell.symbol == "~" {
      box(x, y, 1, 1, Color(hex: dark ? 0x173C53 : 0x4F96AF), radius: 0)
      let shift = sin(time * 2 + x + y) * 0.1
      line(
        [CGPoint(x: x + 0.2 + shift, y: y + 0.4), CGPoint(x: x + 0.5 + shift, y: y + 0.4)],
        .white.opacity(0.16))
    } else if cell.platform {
      box(x, y, 1, 1, Color(hex: 0xAD875E), radius: 0.02)
      for i in 0..<4 {
        box(
          x + 0.025, y + Double(i) * 0.25 + 0.025, 0.95, 0.21,
          Color(hex: i.isMultiple(of: 2) ? 0xD6AE77 : 0xC29A68), radius: 0.02)
      }
      ellipse(x + 0.07, y + 0.07, 0.06, 0.06, ink.opacity(0.5))
    } else {
      let even = (Int(x) + Int(y)).isMultiple(of: 2)
      box(x, y, 1, 1, Color(hex: dark ? 0x315054 : 0xDEDAC5), radius: 0)
      box(
        x + 0.015, y + 0.015, 0.97, 0.97,
        Color(hex: dark ? (even ? 0x59777B : 0x416368) : (even ? 0xF2E8D2 : 0xD5DDCB)), radius: 0.04
      )
    }
  }
  mutating func station(_ cell: KitchenCell) {
    let x = cell.x
    let y = cell.y
    let symbol = cell.symbol
    if ".1234~".contains(symbol) { return }
    if symbol == "#" {
      box(x, y, 1, 1, Color(hex: 0x573C38))
      for row in 0..<3 {
        for column in 0..<2 {
          box(
            x + Double(column) * 0.49 + 0.025, y + Double(row) * 0.31 + 0.025,
            0.45, 0.27, Color(hex: dark ? 0x77524E : 0xCB795C), radius: 0.025)
        }
      }
      return
    }
    box(x + 0.02, y + 0.13, 0.98, 0.9, .black.opacity(0.2), radius: 0.1)
    let steel = "SKPD".contains(symbol)
    let wood = "TOMLB".contains(symbol)
    let body = steel ? Color(hex: 0x657E8B) : (wood ? Color(hex: 0xBB8E59) : Color(hex: 0x249B95))
    box(x + 0.02, y - 0.03, 0.96, 0.98, body, radius: 0.1)
    box(x + 0.08, y + 0.63, 0.84, 0.24, ink.opacity(0.2), radius: 0.04)
    box(
      x + 0.035, y - 0.05, 0.93, 0.73, wood ? Color(hex: 0xE7BC82) : Color(hex: 0xCADBD2),
      radius: 0.09)
    line(
      [CGPoint(x: x + 0.1, y: y + 0.02), CGPoint(x: x + 0.85, y: y + 0.02)], .white.opacity(0.55),
      width: 0.025)
    if "CEBR".contains(symbol) {
      box(x + 0.36, y + 0.74, 0.27, 0.045, cream, radius: 0.02)
    }
    switch symbol {
    case "T", "O", "M", "L":
      box(x + 0.1, y + 0.01, 0.8, 0.6, Color(hex: 0x93704B))
      for i in 0..<3 {
        let ing: Ingredient =
          symbol == "T"
          ? .tomato : (symbol == "O" ? .onion : (symbol == "M" ? .mushroom : .lettuce))
        ingredient(ing, chopped: false, x: x + 0.27 + Double(i) * 0.23, y: y + 0.28, scale: 0.65)
      }
      box(x + 0.12, y + 0.52, 0.76, 0.12, Color(hex: 0xD9A565), radius: 0.02)
    case "B":
      box(x + 0.1, y + 0.05, 0.8, 0.51, Color(hex: 0xBA8E5D), radius: 0.08)
      box(x + 0.14, y + 0.04, 0.72, 0.45, Color(hex: 0xF0CE99))
      line(
        [CGPoint(x: x + 0.25, y: y + 0.18), CGPoint(x: x + 0.6, y: y + 0.34)], Color(hex: 0xBE9B72))
      box(x + 0.73, y + 0.13, 0.1, 0.24, Color(hex: 0xE2E9E9), radius: 0.01)
      box(x + 0.75, y + 0.35, 0.06, 0.13, ink, radius: 0.01)
    case "S":
      ellipse(x + 0.16, y + 0.06, 0.68, 0.46, ink)
      ellipse(
        x + 0.24, y + 0.11, 0.52, 0.33, PantryStyle.paprika.opacity(0.7 + sin(time * 4) * 0.2))
      ellipse(x + 0.32, y + 0.16, 0.36, 0.22, ink)
      for i in 0..<3 { ellipse(x + 0.22 + Double(i) * 0.23, y + 0.75, 0.09, 0.09, ink) }
    case "K":
      box(x + 0.13, y + 0.06, 0.74, 0.5, Color(hex: 0x547E94), radius: 0.13)
      box(x + 0.2, y + 0.13, 0.6, 0.33, Color(hex: 0x74BDCF), radius: 0.11)
      box(x + 0.44, y - 0.04, 0.08, 0.22, ink)
      box(x + 0.46, y - 0.04, 0.19, 0.07, ink)
      for i in 0..<3 {
        ellipse(x + 0.25 + Double(i) * 0.17, y + 0.28, 0.07, 0.06, .white.opacity(0.55))
      }
    case "P", "D":
      box(x + 0.12, y + 0.05, 0.76, 0.5, ink)
      if symbol == "D" {
        box(x + 0.2, y + 0.12, 0.6, 0.33, PantryStyle.basil.opacity(0.65 + sin(time * 3) * 0.2))
        text("RETURN", x: x + 0.5, y: y + 0.3, size: 0.12)
      } else {
        text("⇧ ⇧", x: x + 0.5, y: y + 0.25, size: 0.34)
        text("SERVE", x: x + 0.5, y: y + 0.8, size: 0.12)
      }
    case "X":
      box(x + 0.22, y + 0.05, 0.56, 0.48, ink, radius: 0.05)
      box(x + 0.16, y + 0.02, 0.68, 0.09, Color(hex: 0x76828B))
      text("×", x: x + 0.5, y: y + 0.3, size: 0.36)
    case ">", "<", "^", "v":
      box(x + 0.02, y - 0.02, 0.96, 0.9, Color(hex: 0x3B3B45))
      box(x + 0.1, y + 0.03, 0.8, 0.77, Color(hex: 0x55555F))
      for i in 0..<3 {
        let phase = (time * 1.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        let dx = symbol == ">" ? 1.0 : (symbol == "<" ? -1.0 : 0)
        let dy = symbol == "v" ? 1.0 : (symbol == "^" ? -1.0 : 0)
        let cx = x + 0.5 + dx * (phase - 0.5) * 0.6
        let cy = y + 0.4 + dy * (phase - 0.5) * 0.6
        text(
          String(symbol == "^" ? "↑" : (symbol == "v" ? "↓" : (symbol == ">" ? "›" : "‹"))),
          x: cx, y: cy, size: 0.3, color: PantryStyle.butter)
      }
    default: break
    }
  }
  mutating func contents(_ cell: KitchenCell) {
    if let item = cell.state.item {
      let direction = cell.symbol == ">" ? 1.0 : (cell.symbol == "<" ? -1.0 : 0)
      let dy = cell.symbol == "v" ? 1.0 : (cell.symbol == "^" ? -1.0 : 0)
      let phase = (cell.state.conveyor ?? 0) - 0.5
      drawItem(item, x: cell.x + 0.5 + direction * phase, y: cell.y + 0.32 + dy * phase)
      if case .pot(let contents, let cook, let burn, let burnt) = item, !contents.isEmpty, !burnt {
        if cook < 1 {
          progress(cook, x: cell.x, y: cell.y - 0.3, color: PantryStyle.basil)
        } else {
          tag(
            burn > 0.5 ? "FIRE!" : "READY", x: cell.x + 0.5, y: cell.y - 0.25,
            color: burn > 0.5 ? PantryStyle.paprika : PantryStyle.basil)
        }
      }
    }
    if let p = cell.state.progress, p > 0 {
      progress(
        p, x: cell.x, y: cell.y - 0.3,
        color: cell.symbol == "K" ? PantryStyle.blueberry : PantryStyle.basil)
    }
    if let fire = cell.state.fire, fire > 0 { flame(x: cell.x + 0.5, y: cell.y + 0.45) }
  }
  mutating func progress(_ value: Double, x: Double, y: Double, color: Color) {
    box(x + 0.08, y, 0.84, 0.28, .white)
    box(x + 0.14, y + 0.08, 0.72, 0.12, Color(hex: 0xD8D3C8))
    box(x + 0.14, y + 0.08, 0.72 * min(1, max(0, value)), 0.12, color)
  }
  mutating func flame(x: Double, y: Double) {
    for i in 0..<3 {
      let center = x + Double(i - 1) * 0.18
      let height = 0.5 + sin(time * 9 + Double(i) * 2) * 0.12
      var path = Path()
      path.move(to: CGPoint(x: center - 0.14, y: y))
      path.addQuadCurve(
        to: CGPoint(x: center, y: y - height),
        control: CGPoint(x: center - 0.23, y: y - height * 0.7))
      path.addQuadCurve(
        to: CGPoint(x: center + 0.14, y: y), control: CGPoint(x: center + 0.3, y: y - height * 0.5))
      path.closeSubpath()
      context.fill(path, with: .color(Color(hex: 0xFF791A)))
      ellipse(center - 0.075, y - height * 0.42, 0.15, height * 0.45, PantryStyle.butter)
    }
  }
  mutating func ingredient(
    _ ingredient: Ingredient, chopped: Bool, x: Double, y: Double, scale: Double = 1
  ) {
    let s = 0.25 * scale
    let color = PantryStyle.ingredient(ingredient)
    ellipse(x - s, y - s * 0.3, s * 2, s * 1.5, .black.opacity(0.18))
    if chopped {
      for i in -1...1 {
        let cx = x + Double(i) * s * 0.6
        ellipse(cx - s * 0.4, y - s * 0.3, s * 0.9, s * 0.65, color)
        ellipse(cx - s * 0.2, y - s * 0.2, s * 0.5, s * 0.36, cream.opacity(0.5))
      }
    } else {
      switch ingredient {
      case .tomato:
        ellipse(x - s, y - s, s * 2, s * 2, color)
        line(
          [
            CGPoint(x: x - s * 0.6, y: y - s), CGPoint(x: x, y: y - s * 0.7),
            CGPoint(x: x + s * 0.5, y: y - s * 1.2),
          ], PantryStyle.basil, width: 0.05 * scale)
      case .onion:
        ellipse(x - s, y - s, s * 2, s * 2, color)
        ellipse(x - s * 0.6, y - s * 0.7, s * 1.2, s * 1.4, cream.opacity(0.4))
        box(x - s * 0.1, y - s * 1.3, s * 0.3, s * 0.5, PantryStyle.plum)
      case .mushroom:
        box(x - s * 0.35, y - s * 0.1, s * 0.7, s * 1.1, cream)
        ellipse(x - s, y - s, s * 2, s * 1.3, color)
        ellipse(x - s * 0.4, y - s * 0.7, s * 0.4, s * 0.3, cream)
      case .lettuce:
        for i in 0..<5 {
          let angle = Double(i) * .pi * 2 / 5
          ellipse(
            x + cos(angle) * s * 0.5 - s * 0.6, y + sin(angle) * s * 0.5 - s * 0.6,
            s * 1.3, s * 1.3, color)
        }
        ellipse(x - s * 0.5, y - s * 0.5, s, s, PantryStyle.basil)
      }
      ellipse(x - s * 0.5, y - s * 0.6, s * 0.5, s * 0.3, .white.opacity(0.35))
    }
  }
  mutating func drawItem(_ item: Item, x: Double, y: Double, scale: Double = 1) {
    let saved = context
    context.translateBy(x: x, y: y)
    context.scaleBy(x: scale, y: scale)
    switch item {
    case .ingredient(let ingredient, let chopped):
      self.ingredient(ingredient, chopped: chopped, x: 0, y: 0)
    case .pot(let contents, let cook, _, let burnt):
      ellipse(-0.42, 0.1, 0.84, 0.3, .black.opacity(0.25))
      box(-0.36, -0.16, 0.72, 0.5, Color(hex: 0x8FA3B8), radius: 0.12)
      box(-0.36, 0.17, 0.72, 0.13, Color(hex: 0x5C7084))
      box(-0.5, -0.05, 0.2, 0.09, ink)
      box(0.3, -0.05, 0.2, 0.09, ink)
      ellipse(-0.38, -0.27, 0.76, 0.32, Color(hex: 0xC3D2E0))
      let color =
        burnt
        ? Color(hex: 0x2A211B) : contents.first.map(PantryStyle.ingredient) ?? Color(hex: 0x5C7084)
      ellipse(-0.32, -0.23, 0.64, 0.24, color)
      if cook < 1 && !burnt {
        for (index, ingredient) in contents.enumerated() {
          self.ingredient(
            ingredient, chopped: true, x: -0.18 + Double(index) * 0.18, y: -0.12, scale: 0.35)
        }
      }
      if cook >= 1 || burnt {
        for i in 0..<2 {
          let phase = (time * 0.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
          ellipse(
            Double(i) * 0.2 - 0.2, -0.3 - phase * 0.5, 0.12, 0.16,
            (burnt ? Color.gray : Color.white).opacity((1 - phase) * 0.7))
        }
      }
    case .plate(let contents, let cooked):
      plate(x: 0, y: 0)
      if cooked, let first = contents.first {
        ellipse(-0.27, -0.1, 0.54, 0.2, PantryStyle.ingredient(first))
      } else {
        for (index, ingredient) in contents.enumerated() {
          self.ingredient(
            ingredient, chopped: true, x: -0.12 + Double(index) * 0.2, y: -0.05, scale: 0.6)
        }
      }
    case .stack(let count, let dirty):
      for index in 0..<min(5, max(0, count)) { plate(x: 0, y: -Double(index) * 0.08, dirty: dirty) }
      if count > 0 { tag("\(count)", x: 0.33, y: -0.32, color: ink, fontSize: 0.14) }
    case .extinguisher:
      box(-0.17, -0.32, 0.34, 0.62, PantryStyle.paprika, radius: 0.11)
      box(-0.07, -0.42, 0.14, 0.16, ink)
      box(0.06, -0.31, 0.22, 0.08, ink)
      box(-0.11, -0.08, 0.22, 0.22, .white)
    }
    context = saved
  }
  mutating func plate(x: Double, y: Double, dirty: Bool = false) {
    ellipse(x - 0.4, y - 0.12, 0.8, 0.35, .black.opacity(0.2))
    ellipse(x - 0.4, y - 0.17, 0.8, 0.35, dirty ? Color(hex: 0xB8A98F) : .white)
    ellipse(x - 0.3, y - 0.12, 0.6, 0.23, dirty ? Color(hex: 0x8E7B5F) : Color(hex: 0xE6E2DA))
    if dirty { ellipse(x + 0.05, y - 0.08, 0.1, 0.08, Color(hex: 0x6B4F2E)) }
  }
  mutating func target(x: Double, y: Double) {
    context.stroke(
      Path(roundedRect: rect(x + 0.04, y - 0.05, 0.92, 0.9), cornerRadius: 0.12),
      with: .color(.white.opacity(0.75)), lineWidth: 0.035)
  }
  mutating func chef(_ chef: Chef, local: Bool, moving: Bool, label: Bool = true) {
    let x = chef.x
    let y = chef.y
    let color = PantryStyle.chefs[max(0, chef.slot) % 4]
    let bob = moving ? sin(time * 16) * 0.035 : 0
    let bodyY = y - 0.35 + bob
    ellipse(x - 0.38, y + 0.2, 0.76, 0.27, .black.opacity(0.3))
    if local {
      context.stroke(
        Path(ellipseIn: rect(x - 0.45, y + 0.16, 0.9, 0.35)), with: .color(.white), lineWidth: 0.05)
    }
    if (chef.dash ?? 0) > 0 { ellipse(x - 0.6, bodyY - 0.45, 1.2, 1.2, color.opacity(0.2)) }
    let step = moving ? sin(time * 16) * 0.06 : 0
    ellipse(x - 0.3, y + 0.2 + step, 0.22, 0.13, ink)
    ellipse(x + 0.08, y + 0.2 - step, 0.22, 0.13, ink)
    box(x - 0.36, bodyY, 0.72, 0.61, ink, radius: 0.23)
    box(x - 0.34, bodyY, 0.68, 0.58, color, radius: 0.23)
    if chef.facing != .up {
      box(x - 0.18, bodyY + 0.03, 0.36, 0.45, .white, radius: 0.12)
      for i in 0..<3 { ellipse(x - 0.025, bodyY + 0.1 + Double(i) * 0.12, 0.05, 0.05, ink) }
    } else {
      box(x - 0.18, bodyY + 0.25, 0.36, 0.05, .white)
    }
    let skin =
      chef.bot
      ? Color(hex: 0xCFD4DA)
      : Color(hex: [0xF4BB8D, 0xD5986F, 0xB97952, 0xF0C9A1][max(0, chef.slot) % 4])
    ellipse(x - 0.48, bodyY + 0.15, 0.2, 0.25, color)
    ellipse(x + 0.28, bodyY + 0.15, 0.2, 0.25, color)
    ellipse(x - 0.45, bodyY + 0.29, 0.14, 0.13, skin)
    ellipse(x + 0.31, bodyY + 0.29, 0.14, 0.13, skin)
    ellipse(x - 0.33, bodyY - 0.47, 0.66, 0.66, skin)
    if chef.facing != .up {
      let dx = Double(chef.facing.dx) * 0.09
      for i in [-1.0, 1.0] {
        ellipse(x + dx + i * 0.105 - 0.04, bodyY - 0.19, 0.08, 0.1, ink)
        ellipse(x + dx + i * 0.105 - 0.02, bodyY - 0.18, 0.025, 0.025, .white)
      }
      ellipse(x + dx - 0.04, bodyY - 0.07, 0.1, 0.07, PantryStyle.paprika.opacity(0.4))
      line(
        [
          CGPoint(x: x + dx - 0.07, y: bodyY + 0.02), CGPoint(x: x + dx, y: bodyY + 0.045),
          CGPoint(x: x + dx + 0.07, y: bodyY + 0.02),
        ], ink, width: 0.02)
    }
    box(x - 0.29, bodyY - 0.59, 0.58, 0.18, .white)
    box(x - 0.28, bodyY - 0.43, 0.56, 0.04, color)
    ellipse(x - 0.38, bodyY - 0.86, 0.4, 0.4, cream)
    ellipse(x - 0.02, bodyY - 0.86, 0.4, 0.4, cream)
    ellipse(x - 0.24, bodyY - 0.98, 0.48, 0.48, .white)
    if chef.bot {
      line([CGPoint(x: x, y: bodyY - 0.94), CGPoint(x: x, y: bodyY - 1.11)], ink)
      ellipse(x - 0.045, bodyY - 1.16, 0.09, 0.09, color)
    }
    if let held = chef.held {
      drawItem(
        held, x: x + Double(chef.facing.dx) * 0.38,
        y: bodyY + 0.4 + Double(chef.facing.dy) * 0.12, scale: 0.75)
    }
    if chef.working == true {
      for i in 0..<3 {
        let angle = time * 12 + Double(i) * 2
        ellipse(
          x + Double(chef.facing.dx) * 0.6 + cos(angle) * 0.13,
          y + Double(chef.facing.dy) * 0.5 + sin(angle) * 0.13, 0.07, 0.07, PantryStyle.butter)
      }
    }
    if label {
      tag(chef.name, x: x, y: y + 0.58, color: color.opacity(chef.offline == true ? 0.4 : 1))
    }
    if chef.offline == true { tag("offline", x: x, y: bodyY - 1.18, color: ink) }
    if let emote = chef.emote, Chef.emotes.indices.contains(emote) {
      tag(Chef.emotes[emote], x: x + 0.35, y: bodyY - 1.24, color: PantryStyle.plum, fontSize: 0.22)
    }
  }
  mutating func effect(_ event: GameEvent, age: Double, snapshot: Snapshot) {
    guard age >= 0 && age < 1.5 else { return }
    let chef = snapshot.chefs.first { $0.id == event.chef }
    let x = event.x.map { Double($0) + 0.5 } ?? chef?.x ?? 1.5
    let y = event.y.map { Double($0) + 0.5 } ?? chef?.y ?? 1.0
    let color: Color =
      ["burnt", "wrong", "expired", "fire"].contains(event.kind)
      ? PantryStyle.paprika : PantryStyle.butter
    for i in 0..<7 {
      let angle = Double(i) * .pi * 2 / 7
      let radius = age * 0.8
      ellipse(
        x + cos(angle) * radius, y + sin(angle) * radius - age * 0.3,
        0.08, 0.08, color.opacity(1 - age / 1.5))
    }
    let label: String
    switch event.kind {
    case "served": label = "+\(event.value ?? 0)"
    case "expired": label = "−10"
    case "cooked": label = "READY!"
    case "burnt": label = "BURNT!"
    case "wrong": label = "WRONG!"
    case "extinguished": label = "SAVED!"
    default: label = ""
    }
    if !label.isEmpty { text(label, x: x, y: y - 0.5 - age * 0.7, size: 0.4, color: color) }
  }
}
