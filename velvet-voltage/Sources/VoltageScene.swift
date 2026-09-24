import SpriteKit
import UIKit

enum Ink {
  static let background = UIColor(red: 0.055, green: 0.032, blue: 0.07, alpha: 1)
  static let panel = UIColor(red: 0.16, green: 0.085, blue: 0.14, alpha: 1)
  static let brass = UIColor(red: 0.77, green: 0.59, blue: 0.35, alpha: 1)
  static let coral = UIColor(red: 1, green: 0.35, blue: 0.32, alpha: 1)
  static let cyan = UIColor(red: 0.40, green: 0.94, blue: 0.87, alpha: 1)
  static let cream = UIColor(red: 0.98, green: 0.92, blue: 0.78, alpha: 1)
}

@MainActor
final class VoltageScene: SKScene {
  weak var session: GameSession?
  private let ballNode = SKNode()
  private var leftNode = SKNode()
  private var rightNode = SKNode()
  private var districtRings: [SKShapeNode] = []
  private var districtCaps: [SKNode] = []
  private var progressLights: [SKShapeNode] = []
  private var trail: [SKShapeNode] = []
  private let mural = SKSpriteNode(imageNamed: "MidnightCity")
  private let cityGlow = SKShapeNode(ellipseOf: CGSize(width: 170, height: 220))
  private let plunger = SKNode()
  private var districtLamps: [SKShapeNode] = []
  private var lastTime = 0.0
  private var attractClock = 0.0
  private var trailClock = 0
  private var lastCircuit = 0
  private var progressLabel = SKLabelNode()

  init(session: GameSession) {
    self.session = session
    super.init(size: CGSize(width: 390, height: 620))
    scaleMode = .aspectFit
    backgroundColor = .clear
    buildTable()
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  @discardableResult
  private func line(
    _ points: [CGPoint], color: UIColor, width: CGFloat, glow: CGFloat = 0,
    parent: SKNode? = nil
  ) -> SKShapeNode {
    let path = CGMutablePath()
    if let first = points.first {
      path.move(to: first)
      for point in points.dropFirst() { path.addLine(to: point) }
    }
    let shape = SKShapeNode(path: path)
    shape.strokeColor = color
    shape.lineWidth = width
    shape.glowWidth = glow
    shape.lineCap = .round
    (parent ?? self).addChild(shape)
    return shape
  }

  @discardableResult
  private func label(
    _ text: String, x: Double, y: Double, size: CGFloat, color: UIColor,
    font: String = "AvenirNextCondensed-DemiBold", parent: SKNode? = nil
  ) -> SKLabelNode {
    let node = SKLabelNode(fontNamed: font)
    node.text = text
    node.fontSize = size
    node.fontColor = color
    node.position = CGPoint(x: x, y: y)
    (parent ?? self).addChild(node)
    return node
  }

  @discardableResult
  private func circle(
    radius: CGFloat, at point: CGPoint, fill: UIColor, stroke: UIColor,
    width: CGFloat = 1, parent: SKNode? = nil
  ) -> SKShapeNode {
    let node = SKShapeNode(circleOfRadius: radius)
    node.position = point
    node.fillColor = fill
    node.strokeColor = stroke
    node.lineWidth = width
    (parent ?? self).addChild(node)
    return node
  }

  private func buildTable() {
    let frame = SKShapeNode(
      rect: CGRect(x: 6, y: 14, width: 378, height: 595), cornerRadius: 42)
    frame.fillColor = Ink.panel
    frame.strokeColor = Ink.brass
    frame.lineWidth = 2
    addChild(frame)
    let crop = SKCropNode()
    let mask = SKShapeNode(
      rect: CGRect(x: 18, y: 29, width: 354, height: 568), cornerRadius: 34)
    mask.fillColor = .white
    crop.maskNode = mask
    mural.size = CGSize(width: 378, height: 590)
    mural.position = CGPoint(x: 195, y: 315)
    mural.color = Ink.background
    mural.colorBlendFactor = 0.2
    crop.addChild(mural)
    addChild(crop)
    for x in [11.0, 379.0] {
      line(
        [CGPoint(x: x, y: 65), CGPoint(x: x, y: 559)],
        color: Ink.cream.withAlphaComponent(0.18), width: 1)
    }
    for x in [30.0, 360.0] {
      for y in [38.0, 583.0] { screw(x: x, y: y) }
    }
    cityGlow.position = CGPoint(x: 195, y: 412)
    cityGlow.fillColor = Ink.cyan.withAlphaComponent(0.045)
    cityGlow.strokeColor = .clear
    cityGlow.glowWidth = 38
    cityGlow.blendMode = .add
    cityGlow.alpha = 0
    addChild(cityGlow)
    for x in [90.0, 195.0, 300.0] {
      let lamp = SKShapeNode(ellipseOf: CGSize(width: 110, height: 150))
      lamp.position = CGPoint(x: x, y: 470)
      lamp.fillColor = Ink.cream.withAlphaComponent(0.05)
      lamp.strokeColor = .clear
      lamp.glowWidth = 26
      lamp.blendMode = .add
      lamp.alpha = 0
      addChild(lamp)
      districtLamps.append(lamp)
    }
    buildInlays()
    buildPlunger()
    for rail in PinballEngine.rails {
      let points = [CGPoint(x: rail.a.x, y: rail.a.y), CGPoint(x: rail.b.x, y: rail.b.y)]
      line(points.map { CGPoint(x: $0.x + 2, y: $0.y - 4) }, color: .black, width: 10)
      line(points, color: UIColor(red: 0.32, green: 0.22, blue: 0.13, alpha: 1), width: 7)
      line(points, color: Ink.brass, width: 4)
      line(
        points.map { CGPoint(x: $0.x - 0.7, y: $0.y + 1) },
        color: Ink.cream.withAlphaComponent(0.9), width: 1)
    }
    for (index, center) in PinballEngine.districts.enumerated() {
      buildBumper(index: index, center: center)
    }
    let plaque = SKShapeNode(
      rect: CGRect(x: 100, y: 246, width: 190, height: 66), cornerRadius: 5)
    plaque.fillColor = Ink.background.withAlphaComponent(0.97)
    plaque.strokeColor = Ink.brass.withAlphaComponent(0.65)
    addChild(plaque)
    label("M I D N I G H T   C I R C U I T", x: 195, y: 293, size: 12, color: Ink.cream)
    progressLabel = label("FOLLOW THE LIGHT", x: 195, y: 272, size: 12, color: Ink.cream)
    for index in 0..<3 {
      progressLights.append(
        circle(
          radius: 4, at: CGPoint(x: 175 + index * 20, y: 257),
          fill: Ink.background, stroke: Ink.brass, width: 0.5))
    }
    label("Velvet", x: 195, y: 215, size: 25, color: Ink.cream, font: "Baskerville-Italic")
    label("V O L T A G E", x: 195, y: 198, size: 13, color: Ink.cream)
    label("ELECTRIC PINBALL • No. 01", x: 195, y: 180, size: 9, color: Ink.brass)
    leftNode = makeFlipper()
    rightNode = makeFlipper()
    for x in [114.0, 276.0] { screw(x: x, y: 101, z: 8) }
    for index in 0..<10 {
      let dot = circle(
        radius: CGFloat(1 + Double(index) * 0.4), at: .zero,
        fill: Ink.cyan, stroke: .clear)
      dot.alpha = CGFloat(index) / 35
      dot.isHidden = true
      dot.zPosition = 9
      trail.append(dot)
    }
    circle(
      radius: 9, at: CGPoint(x: 2, y: -3), fill: .black.withAlphaComponent(0.7),
      stroke: .clear, parent: ballNode
    ).zPosition = -1
    circle(
      radius: 8, at: .zero, fill: UIColor(white: 0.32, alpha: 1),
      stroke: Ink.cyan, width: 0.8, parent: ballNode)
    circle(
      radius: 6, at: CGPoint(x: -1, y: 1), fill: UIColor(white: 0.77, alpha: 1),
      stroke: .clear, parent: ballNode)
    circle(
      radius: 3.5, at: CGPoint(x: -2, y: 3), fill: .white,
      stroke: .clear, parent: ballNode)
    ballNode.zPosition = 10
    addChild(ballNode)
  }

  private func buildPlunger() {
    plunger.zPosition = 6
    plunger.position = CGPoint(x: 343, y: 200)
    addChild(plunger)
    line(
      [CGPoint(x: 0, y: 8), CGPoint(x: 0, y: -80)], color: Ink.background.withAlphaComponent(0.7),
      width: 6, parent: plunger)
    line(
      [CGPoint(x: 0, y: 8), CGPoint(x: 0, y: -80)], color: Ink.brass, width: 3, parent: plunger)
    let knob = SKShapeNode(rectOf: CGSize(width: 18, height: 14), cornerRadius: 4)
    knob.position = CGPoint(x: 0, y: -84)
    knob.fillColor = Ink.coral
    knob.strokeColor = Ink.cream.withAlphaComponent(0.7)
    knob.lineWidth = 0.8
    plunger.addChild(knob)
    let hint = label("PULL", x: 0, y: -108, size: 9, color: Ink.cyan, parent: plunger)
    hint.name = "hint"
    let arrow = label("\u{2193}", x: 0, y: -122, size: 12, color: Ink.cyan, parent: plunger)
    arrow.name = "hint"
    plunger.isHidden = true
  }

  private func buildInlays() {
    for left in [true, false] {
      let x: (Double) -> Double = { left ? $0 : 390 - $0 }
      let path = CGMutablePath()
      path.move(to: CGPoint(x: x(69), y: 255))
      path.addLine(to: CGPoint(x: x(82), y: 175))
      path.addLine(to: CGPoint(x: x(137), y: 139))
      path.closeSubpath()
      let plate = SKShapeNode(path: path)
      plate.fillColor = UIColor(red: 0.34, green: 0.12, blue: 0.14, alpha: 1)
      plate.strokeColor = Ink.brass
      addChild(plate)
      for step in 0..<5 {
        line(
          [
            CGPoint(x: x(78 + Double(step) * 3), y: 230 - Double(step) * 7),
            CGPoint(x: x(91 + Double(step) * 4), y: 178 - Double(step) * 3),
            CGPoint(x: x(119 + Double(step) * 2), y: 157 - Double(step) * 3),
          ],
          color: step == 0 ? Ink.coral : Ink.brass.withAlphaComponent(0.5),
          width: step == 0 ? 3 : 0.7, glow: step == 0 ? 1 : 0)
      }
      screw(x: x(82), y: 212)
    }
  }

  private func buildBumper(index: Int, center: Vector) {
    let cap = SKNode()
    cap.position = CGPoint(x: center.x, y: center.y)
    cap.zPosition = 4
    addChild(cap)
    circle(
      radius: 35, at: CGPoint(x: 2, y: -5), fill: .black.withAlphaComponent(0.8), stroke: .clear,
      parent: cap)
    circle(radius: 32, at: .zero, fill: Ink.panel, stroke: Ink.brass, width: 3, parent: cap)
    for step in 0..<24 {
      let angle = Double(step) * .pi / 12
      line(
        [
          CGPoint(x: cos(angle) * 28, y: sin(angle) * 28),
          CGPoint(x: cos(angle) * 31, y: sin(angle) * 31),
        ], color: Ink.cream.withAlphaComponent(0.65), width: 0.8, parent: cap)
    }
    let ring = circle(
      radius: 25, at: .zero, fill: Ink.background, stroke: Ink.brass, width: 2, parent: cap)
    districtRings.append(ring)
    circle(
      radius: 21, at: .zero, fill: Ink.panel, stroke: Ink.brass.withAlphaComponent(0.5), width: 0.5,
      parent: cap)
    label(
      "0\(index + 1)", x: 0, y: -8, size: 25, color: Ink.cream, font: "Baskerville", parent: cap)
    let tab = SKShapeNode(rect: CGRect(x: -44, y: -57, width: 88, height: 21), cornerRadius: 3)
    tab.fillColor = Ink.background
    tab.strokeColor = Ink.brass.withAlphaComponent(0.5)
    tab.lineWidth = 0.5
    cap.addChild(tab)
    label(
      ["ARCADE", "SPIRE", "RIVIERA"][index], x: 0, y: -52, size: 14, color: Ink.cream, parent: cap)
    districtCaps.append(cap)
  }

  private func screw(x: Double, y: Double, z: CGFloat = 3) {
    let node = SKNode()
    node.position = CGPoint(x: x, y: y)
    node.zPosition = z
    addChild(node)
    circle(
      radius: 3.5, at: .zero, fill: Ink.brass, stroke: Ink.cream.withAlphaComponent(0.7),
      width: 0.6, parent: node)
    line(
      [CGPoint(x: -1.7, y: -1), CGPoint(x: 1.7, y: 1)], color: Ink.background, width: 1,
      parent: node)
  }

  private func makeFlipper() -> SKNode {
    let node = SKNode()
    node.zPosition = 7
    addChild(node)
    line(
      [CGPoint(x: 1, y: -4), CGPoint(x: 69, y: -4)], color: .black.withAlphaComponent(0.8),
      width: 20, parent: node)
    line([.zero, CGPoint(x: 68, y: 0)], color: Ink.coral, width: 18, parent: node)
    line([CGPoint(x: 0, y: 2), CGPoint(x: 67, y: 2)], color: Ink.cream, width: 10, parent: node)
    line([CGPoint(x: 14, y: 3), CGPoint(x: 55, y: 3)], color: Ink.brass, width: 0.8, parent: node)
    return node
  }

  private func drawFlipper(_ node: SKNode, rail: Rail) {
    node.position = CGPoint(x: rail.a.x, y: rail.a.y)
    node.zRotation = atan2(rail.b.y - rail.a.y, rail.b.x - rail.a.x)
  }

  override func update(_ currentTime: TimeInterval) {
    guard let session else { return }
    let dt = lastTime == 0 ? 1 / 60 : min(currentTime - lastTime, 1 / 30)
    lastTime = currentTime
    if session.screen == .playing, !session.paused {
      let events = session.engine.advance(dt)
      for event in events {
        if case .bumper(let index, let completed) = event {
          burst(at: PinballEngine.districts[index], celebration: completed)
          if !session.reducedMotion {
            districtCaps[index].run(
              .sequence([.scale(to: 0.94, duration: 0.05), .scale(to: 1, duration: 0.18)]))
          }
        }
      }
      session.consume(events)
    }
    let engine = session.engine
    attractClock += dt
    let waiting = session.screen == .playing && !engine.inFlight && !session.paused
    plunger.isHidden = !waiting
    if waiting {
      plunger.position.y = 200 - session.plungerPull * 70
      for child in plunger.children where child.name == "hint" {
        child.alpha = session.plungerPull > 0.05 ? 0 : 0.6 + 0.4 * sin(attractClock * 4)
      }
    }
    let hits = engine.score.circuits > 0 ? 3 : engine.score.nextDistrict
    for (index, lamp) in districtLamps.enumerated() {
      let target: CGFloat = index < hits ? 1 : (session.screen == .home ? 0.35 : 0)
      lamp.alpha += (target - lamp.alpha) * min(1, dt * 4)
    }
    let dim = session.screen == .playing ? max(0, 0.45 - 0.15 * Double(hits)) : 0.2
    mural.colorBlendFactor += (dim - mural.colorBlendFactor) * min(1, dt * 3)
    progressLabel.text =
      engine.score.circuits > 0
      ? "\(engine.score.circuits) CIRCUIT\(engine.score.circuits == 1 ? "" : "S") LIVE"
      : "LIGHT ALL THREE DISTRICTS"
    for (index, lamp) in progressLights.enumerated() {
      lamp.fillColor =
        index < engine.score.nextDistrict ? Ink.cyan : Ink.brass.withAlphaComponent(0.3)
      lamp.glowWidth = index < engine.score.nextDistrict ? 2 : 0
    }
    drawFlipper(leftNode, rail: engine.flipper(left: true))
    drawFlipper(rightNode, rail: engine.flipper(left: false))
    ballNode.position = CGPoint(
      x: engine.ball.x, y: engine.ball.y - (waiting ? session.plungerPull * 70 : 0))
    ballNode.isHidden = session.screen == .home || session.screen == .tutorial
    if session.screen == .playing, !session.paused {
      trailClock += 1
      if trailClock % 2 == 0 {
        for index in 0..<trail.count - 1 { trail[index].position = trail[index + 1].position }
        trail[trail.count - 1].position = ballNode.position
      }
    }
    for dot in trail {
      dot.isHidden = !engine.inFlight || session.reducedMotion || session.screen != .playing
    }
    let attract = session.screen == .home || session.screen == .tutorial
    let attractIndex = Int(attractClock / 0.7) % 3
    for (index, ring) in districtRings.enumerated() {
      let active = attract ? index == attractIndex : index == engine.score.nextDistrict
      ring.strokeColor = active ? Ink.cyan : Ink.brass.withAlphaComponent(0.8)
      ring.glowWidth = active ? 3.5 : 0
    }
    if attract {
      cityGlow.alpha = session.reducedMotion ? 0.5 : 0.45 + 0.25 * sin(attractClock * 1.3)
    } else if engine.score.circuits == 0, !cityGlow.hasActions() {
      cityGlow.alpha = 0
    }
    if lastCircuit != engine.score.circuits {
      lastCircuit = engine.score.circuits
      cityGlow.removeAllActions()
      cityGlow.alpha = lastCircuit > 0 ? 1 : 0
      if lastCircuit > 0, !session.reducedMotion {
        cityGlow.run(
          .sequence([.fadeAlpha(to: 0.2, duration: 0.4), .fadeAlpha(to: 1, duration: 0.8)]))
      }
    }
  }

  private func burst(at position: Vector, celebration: Bool) {
    guard session?.reducedMotion != true else { return }
    let count = celebration ? 44 : 9
    for index in 0..<count {
      let angle = Double(index) / Double(count) * .pi * 2
      let spark = SKShapeNode(
        rectOf: CGSize(width: celebration ? 2 : 1.5, height: celebration ? 7 : 3), cornerRadius: 1)
      spark.position = CGPoint(x: position.x, y: position.y)
      spark.fillColor = index % 2 == 0 ? Ink.cyan : Ink.cream
      spark.strokeColor = .clear
      spark.glowWidth = 2
      spark.zRotation = angle
      spark.zPosition = 11
      addChild(spark)
      let distance = celebration ? 160.0 : 50.0
      spark.run(
        .sequence([
          .group([
            .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.6),
            .fadeOut(withDuration: 0.6),
          ]), .removeFromParent(),
        ]))
    }
  }
}
