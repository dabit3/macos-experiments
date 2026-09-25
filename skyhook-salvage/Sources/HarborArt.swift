import SwiftUI

enum HarborPalette {
  static let ink = Color(red: 0.12, green: 0.23, blue: 0.24)
  static let sky = Color(red: 0.80, green: 0.86, blue: 0.84)
  static let cream = Color(red: 0.96, green: 0.945, blue: 0.90)
  static let orange = Color(red: 0.68, green: 0.29, blue: 0.16)
  static let brass = Color(red: 0.60, green: 0.47, blue: 0.28)
  static let pale = Color(red: 0.87, green: 0.89, blue: 0.80)
  static let paper = Color(red: 0.985, green: 0.975, blue: 0.94)
  static let muted = Color(red: 0.39, green: 0.45, blue: 0.42)
  static let sage = Color(red: 0.30, green: 0.44, blue: 0.37)
  static let rule = Color(red: 0.78, green: 0.79, blue: 0.72)
  static let fog = Color(red: 0.94, green: 0.96, blue: 0.95)
  static let surface = Color(red: 0.985, green: 0.99, blue: 0.985)
}

enum HarborType {
  static let title = Font.system(.title, design: .default).weight(.bold)
  static let heading = Font.system(.title2, design: .default).weight(.semibold)
  static let action = Font.system(.headline, design: .default)
  static let body = Font.system(.subheadline, design: .default)
  static let caption = Font.system(.footnote, design: .default)
  static let readout = Font.system(.title, design: .default).weight(.semibold)
}

enum HarborSpacing {
  static let page: CGFloat = 20
  static let section: CGFloat = 16
  static let row: CGFloat = 8
}

extension CargoKind {
  var displayHeight: Double {
    switch self {
    case .clock, .piano, .telescope: 60
    case .trunk: 40
    case .plant: 36
    }
  }

  var assetName: String {
    switch self {
    case .trunk: "CargoTrunk"
    case .clock: "CargoClock"
    case .plant: "CargoPlant"
    case .piano: "CargoPiano"
    case .telescope: "CargoTelescope"
    }
  }
}

struct HarborCanvas: View {
  let game: GameModel
  var decorative = false
  var reducedMotion = false

  var body: some View {
    Canvas { context, size in
      let minimumHeight =
        decorative ? 340.0 : 254.0 + game.contract.cargo.reduce(0) { $0 + $1.displayHeight }
      let scale = min(size.width / 390, size.height / minimumHeight)
      context.draw(Image("HarborBackdrop"), in: CGRect(origin: .zero, size: size))
      context.translateBy(x: (size.width - 390 * scale) / 2, y: 0)
      context.scaleBy(x: scale, y: scale)
      let height = size.height / scale
      let deck = height - 109
      let dock = height - 57
      let clock = reducedMotion ? 0 : game.clock
      HarborArt.dock(&context, y: dock)
      let cargoStack =
        decorative
        ? [
          StackedCargo(id: 0, kind: .trunk, x: 251),
          StackedCargo(id: 1, kind: .clock, x: 255),
          StackedCargo(id: 2, kind: .piano, x: 250),
        ] : game.stack
      var ship = context
      let wobble = reducedMotion ? 0 : sin(clock * 9) * game.impact * 0.035
      ship.translateBy(x: DockRules.shipX, y: deck)
      ship.rotate(by: .radians((decorative ? -0.025 : game.balance * 0.12) + wobble))
      ship.translateBy(x: -DockRules.shipX, y: -deck)
      HarborArt.airship(&ship, x: DockRules.shipX, y: deck, clock: clock)
      var cargoY = deck
      for item in cargoStack {
        cargoY -= item.kind.displayHeight
        HarborArt.cargo(
          &ship, kind: item.kind, x: item.x, y: cargoY)
      }
      HarborArt.balanceGauge(&ship, x: DockRules.shipX, y: deck + 16, balance: game.balance)
      if decorative {
        HarborArt.cargo(&context, kind: .plant, x: DockRules.dockX, y: dock - 36)
        HarborArt.crane(
          &context, anchor: 106, hookX: 102 + sin(clock * 0.6) * 15,
          hookY: max(60, deck - 147), height: dock, loaded: false)
        HarborArt.label(&context, "THE LITTLE SHIP THAT COULD", x: 244, y: deck + 99, size: 8)
      } else {
        drawGame(&context, deck: deck, dock: dock)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      decorative
        ? "A brass airship carrying a piano, clock and trunk above a powder blue harbor"
        : "\(game.cargo.title). \(game.stack.count) treasures aboard. Ship balance \(Int(abs(game.balance) * 100)) percent of limit."
    )
  }

  private func drawGame(_ context: inout GraphicsContext, deck: Double, dock: Double) {
    let phase = game.phase
    let pickup = phase == .pickup || phase == .lowering
    let anchor = pickup ? DockRules.dockX : DockRules.shipX
    let cargoHeight = game.cargo.displayHeight
    let stackHeight = HarborArt.stackHeight(game.stack)
    let targetY = deck - stackHeight - cargoHeight
    let suspensionY = max(58, min(deck * 0.42, targetY - cargoHeight - 22))
    var x = game.hookX
    var y = suspensionY
    if phase == .lowering {
      x = game.actionX
      y += (dock - cargoHeight - 8 - suspensionY) * min(1, game.phaseTime / 0.6)
    } else if phase == .hoisting {
      let t = min(1, game.phaseTime / 1.1)
      let smooth = t * t * (3 - 2 * t)
      x = game.actionX + (game.hookX - game.actionX) * smooth
      y = dock - cargoHeight - 8 + (suspensionY - (dock - cargoHeight - 8)) * smooth
    } else if phase == .falling {
      x = game.actionStartX
    }
    if pickup {
      HarborArt.cargo(&context, kind: game.cargo, x: DockRules.dockX, y: dock - cargoHeight)
      HarborArt.line(
        &context, from: CGPoint(x: 46, y: dock + 4), to: CGPoint(x: 120, y: dock + 4),
        color: HarborPalette.orange, width: 4)
    }
    if game.actionable {
      let target = pickup ? DockRules.dockX : game.targetX
      let width = pickup ? game.cargo.width + 20 : (game.stack.last?.kind.width ?? 150)
      let floor = pickup ? dock - cargoHeight - 4 : deck - stackHeight - 4
      let projected = game.projectedX
      let guideColor = game.onTarget ? HarborPalette.sage : HarborPalette.orange
      HarborArt.rounded(
        &context, rect: CGRect(x: target - width / 2, y: floor, width: width, height: 9),
        radius: 2, color: guideColor.opacity(0.17))
      for edge in [-1.0, 1.0] {
        let edgeX = target + edge * width / 2
        HarborArt.line(
          &context, from: CGPoint(x: edgeX, y: floor - 10),
          to: CGPoint(x: edgeX, y: floor + 7), color: guideColor, width: 2)
      }
      var guide = Path()
      guide.move(to: CGPoint(x: projected, y: y + (pickup ? 13 : cargoHeight + 8)))
      guide.addLine(to: CGPoint(x: projected, y: floor))
      context.stroke(
        guide, with: .color(guideColor),
        style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
      HarborArt.ellipse(
        &context, CGRect(x: projected - 6, y: floor - 2, width: 12, height: 5), guideColor)
      let captionX = pickup ? 267.0 : 102.0
      context.draw(
        Text(pickup ? "Collect" : "Land cargo")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(HarborPalette.muted), at: CGPoint(x: captionX, y: 85))
      HarborArt.label(
        &context, pickup ? "Left dock" : "Airship deck", x: captionX, y: 104, size: 11)
    }
    HarborArt.crane(
      &context, anchor: anchor, hookX: x, hookY: y, height: dock,
      loaded: phase == .hoisting || phase == .release)
    if phase == .hoisting || phase == .release {
      HarborArt.cargo(&context, kind: game.cargo, x: x, y: y + 8)
    }
    if phase == .falling {
      let t = min(1, game.phaseTime / 0.7)
      let dropY = suspensionY + 8 + (targetY - suspensionY - 8) * t * t
      let dropX = game.actionStartX + (game.actionX - game.actionStartX) * t
      HarborArt.cargo(&context, kind: game.cargo, x: dropX, y: dropY)
    }
    if phase == .settling {
      let rewardY = max(65, deck - stackHeight - 38)
      context.draw(
        Text("+\(game.lastAward)").font(.system(size: 29, weight: .semibold))
          .foregroundStyle(HarborPalette.ink), at: CGPoint(x: 255, y: rewardY))
      HarborArt.label(
        &context, game.preciseLanding ? "Precise landing" : "Cargo secured",
        x: 255, y: rewardY + 22, size: 11)
      for index in 0..<12 {
        let angle = Double(index) * .pi / 6
        let distance = game.phaseTime * 50
        let point = CGPoint(
          x: game.actionX + cos(angle) * distance,
          y: targetY + 25 + sin(angle) * distance)
        HarborArt.ellipse(
          &context, CGRect(x: point.x, y: point.y, width: 5, height: 5),
          HarborPalette.orange.opacity(max(0, 1 - game.phaseTime)))
      }
    }
    HarborArt.label(&context, "Salvage dock", x: 84, y: dock + 28, size: 11)
    HarborArt.label(
      &context, abs(game.balance) > 0.65 ? "Balance: caution" : "Balance: steady",
      x: 258, y: deck + 98, size: 11)
  }
}

enum HarborArt {
  static func stackHeight(_ stack: [StackedCargo]) -> Double {
    stack.reduce(0) { $0 + $1.kind.displayHeight }
  }

  static func dock(_ c: inout GraphicsContext, y: Double) {
    let p = HarborPalette.self
    rounded(&c, rect: CGRect(x: 0, y: y, width: 134, height: 11), radius: 1, color: p.ink)
    rounded(
      &c, rect: CGRect(x: 0, y: y + 2, width: 134, height: 3), radius: 0, color: p.brass)
    for x in [18.0, 113.0] {
      rounded(
        &c, rect: CGRect(x: x, y: y + 11, width: 9, height: 70), radius: 0,
        color: p.ink.opacity(0.7))
    }
    line(
      &c, from: CGPoint(x: 23, y: y + 37), to: CGPoint(x: 117, y: y + 12),
      color: p.ink.opacity(0.45), width: 4)
  }

  static func crane(
    _ c: inout GraphicsContext, anchor: Double, hookX: Double, hookY: Double, height: Double,
    loaded: Bool
  ) {
    let p = HarborPalette.self
    for x in [18.0, 33.0] {
      line(
        &c, from: CGPoint(x: x, y: 19), to: CGPoint(x: x, y: height), color: p.ink, width: 2)
    }
    for index in 0..<Int(max(1, height / 36)) {
      let y = 24 + Double(index) * 36
      line(
        &c, from: CGPoint(x: 18, y: y), to: CGPoint(x: 33, y: y + 31),
        color: p.ink.opacity(0.6), width: 1)
      ellipse(&c, CGRect(x: 16.5, y: y - 1, width: 3, height: 3), p.brass)
      ellipse(&c, CGRect(x: 31.5, y: y + 30, width: 3, height: 3), p.brass)
    }
    rounded(&c, rect: CGRect(x: 11, y: 18, width: 357, height: 12), radius: 2, color: p.ink)
    line(
      &c, from: CGPoint(x: 18, y: 13), to: CGPoint(x: 355, y: 13),
      color: p.brass, width: 2)
    for index in 0..<18 {
      let x = 21 + Double(index) * 19
      line(
        &c, from: CGPoint(x: x, y: 20), to: CGPoint(x: x + 9, y: 28),
        color: p.sky.opacity(0.5))
    }
    rounded(
      &c, rect: CGRect(x: anchor - 16, y: 11, width: 32, height: 25), radius: 5, color: p.orange)
    ellipse(&c, CGRect(x: anchor - 9, y: 19, width: 7, height: 7), p.ink)
    ellipse(&c, CGRect(x: anchor + 2, y: 19, width: 7, height: 7), p.ink)
    line(
      &c, from: CGPoint(x: anchor, y: 35), to: CGPoint(x: hookX, y: hookY),
      color: p.ink.opacity(0.85), width: 1)
    line(
      &c, from: CGPoint(x: anchor + 3, y: 35), to: CGPoint(x: hookX + 3, y: hookY),
      color: p.brass.opacity(0.75), width: 0.7)
    ellipse(&c, CGRect(x: hookX - 6, y: hookY - 8, width: 13, height: 16), p.brass)
    c.stroke(
      Path(ellipseIn: CGRect(x: hookX - 3, y: hookY - 5, width: 7, height: 10)),
      with: .color(p.ink.opacity(0.7)), lineWidth: 0.8)
    var hook = Path()
    hook.move(to: CGPoint(x: hookX, y: hookY + 2))
    hook.addCurve(
      to: CGPoint(x: hookX + 5, y: hookY + 8),
      control1: CGPoint(x: hookX - 6, y: hookY + 17),
      control2: CGPoint(x: hookX + 10, y: hookY + 19))
    c.stroke(hook, with: .color(p.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    if loaded {
      line(
        &c, from: CGPoint(x: hookX, y: hookY + 8),
        to: CGPoint(x: hookX - 26, y: hookY + 25), color: p.ink.opacity(0.7))
      line(
        &c, from: CGPoint(x: hookX, y: hookY + 8),
        to: CGPoint(x: hookX + 26, y: hookY + 25), color: p.ink.opacity(0.7))
    }
  }

  static func airship(_ c: inout GraphicsContext, x: Double, y: Double, clock: Double) {
    let p = HarborPalette.self
    c.draw(Image("Airship"), in: CGRect(x: x - 115, y: y + 1, width: 236, height: 89))
    rounded(
      &c, rect: CGRect(x: x - 88, y: y - 1, width: 176, height: 7), radius: 1, color: p.ink)
    rounded(
      &c, rect: CGRect(x: x - 87, y: y, width: 174, height: 2), radius: 0, color: p.brass)
    for index in 0..<19 {
      ellipse(&c, CGRect(x: x - 82 + Double(index) * 9, y: y + 3, width: 1, height: 1), p.brass)
    }
    ellipse(
      &c, CGRect(x: x + 116, y: y + 28, width: 2, height: 25),
      p.brass.opacity(0.3 + abs(sin(clock * 14)) * 0.35))
  }

  static func balanceGauge(
    _ c: inout GraphicsContext, x: Double, y: Double, balance: Double
  ) {
    rounded(
      &c, rect: CGRect(x: x - 34, y: y, width: 68, height: 18), radius: 9,
      color: HarborPalette.ink)
    c.stroke(
      Path(roundedRect: CGRect(x: x - 34, y: y, width: 68, height: 18), cornerRadius: 9),
      with: .color(HarborPalette.brass), lineWidth: 0.8)
    line(
      &c, from: CGPoint(x: x - 24, y: y + 9), to: CGPoint(x: x + 24, y: y + 9),
      color: HarborPalette.cream.opacity(0.6))
    line(
      &c, from: CGPoint(x: x, y: y + 4), to: CGPoint(x: x, y: y + 14),
      color: HarborPalette.cream.opacity(0.5))
    ellipse(
      &c, CGRect(x: x - 5 + max(-1, min(1, balance)) * 24, y: y + 4, width: 10, height: 10),
      abs(balance) > 0.65 ? HarborPalette.orange : HarborPalette.cream)
  }

  static func cargo(_ c: inout GraphicsContext, kind: CargoKind, x: Double, y: Double) {
    let image = c.resolve(Image(kind.assetName))
    let scale = min(
      (kind.width - 8) / image.size.width, (kind.displayHeight - 7) / image.size.height)
    let width = image.size.width * scale
    let height = image.size.height * scale
    c.draw(
      image,
      in: CGRect(
        x: x - width / 2, y: y + kind.displayHeight - height - 3, width: width, height: height))
    for edge in [-1.0, 1.0] {
      let railX = x + edge * (kind.width / 2 - 1)
      line(
        &c, from: CGPoint(x: railX, y: y + 1),
        to: CGPoint(x: railX, y: y + kind.displayHeight - 2),
        color: HarborPalette.brass.opacity(0.7), width: 0.8)
    }
    rounded(
      &c, rect: CGRect(x: x - kind.width / 2, y: y, width: kind.width, height: 1.5),
      radius: 0, color: HarborPalette.brass)
    rounded(
      &c,
      rect: CGRect(
        x: x - kind.width / 2, y: y + kind.displayHeight - 3, width: kind.width, height: 3),
      radius: 0, color: HarborPalette.ink)
  }

  static func rounded(
    _ c: inout GraphicsContext, rect: CGRect, radius: Double, color: Color
  ) {
    c.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
  }

  static func ellipse(_ c: inout GraphicsContext, _ rect: CGRect, _ color: Color) {
    c.fill(Path(ellipseIn: rect), with: .color(color))
  }

  static func line(
    _ c: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: Double = 1
  ) {
    var path = Path()
    path.move(to: from)
    path.addLine(to: to)
    c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
  }

  static func label(
    _ c: inout GraphicsContext, _ text: String, x: Double, y: Double, size: Double
  ) {
    c.draw(
      Text(text).font(.system(size: size, weight: .medium, design: .monospaced))
        .foregroundStyle(HarborPalette.ink), at: CGPoint(x: x, y: y))
  }
}
