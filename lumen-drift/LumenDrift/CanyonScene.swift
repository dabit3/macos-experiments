import SpriteKit
import UIKit

@MainActor
final class CanyonScene: SKScene {
  weak var flight: FlightController?
  private let sky = SKNode()
  private let landscape = SKNode()
  private let track = SKNode()
  private let traffic = SKNode()
  private let craft = SKNode()
  private let effects = SKNode()
  private var laneLines: [SKShapeNode] = []
  private var rungs: [SKShapeNode] = []
  private var towers: [SKNode] = []
  private var waveNodes: [Int: SKNode] = [:]
  private var road = SKShapeNode()
  private var lastTime = 0.0
  private var clock = 0.0
  private var visualLane = 1.0
  private var cyan: UIColor { UIColor(red: 0.28, green: 0.96, blue: 0.96, alpha: 1) }
  private var coral: UIColor { UIColor(red: 1, green: 0.34, blue: 0.43, alpha: 1) }
  private var home: Bool { flight?.engine.phase == .ready }
  private var horizon: CGFloat { size.height * (home ? 0.57 : 0.68) }
  private var landing: CGFloat { size.height * (home ? 0.34 : 0.235) }

  override func didMove(to view: SKView) {
    backgroundColor = UIColor(red: 0.018, green: 0.026, blue: 0.066, alpha: 1)
    scaleMode = .resizeFill
    for node in [sky, landscape, track, traffic, craft, effects] { addChild(node) }
    sky.zPosition = -10
    landscape.zPosition = -5
    track.zPosition = 0
    traffic.zPosition = 5
    craft.zPosition = 20
    effects.zPosition = 30
    build()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    if sky.parent != nil { build() }
  }

  func resetFlight() {
    lastTime = 0
    visualLane = 1
    traffic.removeAllChildren()
    waveNodes.removeAll()
    effects.removeAllChildren()
    buildSky()
  }

  private func build() {
    buildSky()
    track.removeAllChildren()
    landscape.removeAllChildren()
    craft.removeAllChildren()
    laneLines = []
    rungs = []
    towers = []
    road = shape([], fill: UIColor(red: 0.035, green: 0.042, blue: 0.12, alpha: 1))
    track.addChild(road)
    for index in 0..<4 {
      let line = shape([], stroke: index == 0 || index == 3 ? cyan : cyan.withAlphaComponent(0.22))
      line.lineWidth = index == 0 || index == 3 ? 1.7 : 0.8
      line.glowWidth = index == 0 || index == 3 ? 2 : 0
      track.addChild(line)
      laneLines.append(line)
    }
    for _ in 0..<22 {
      let line = shape([], stroke: cyan.withAlphaComponent(0.15))
      track.addChild(line)
      rungs.append(line)
    }
    for index in 0..<28 {
      let tower = SKNode()
      let front = shape([], fill: UIColor(red: 0.045, green: 0.055, blue: 0.17, alpha: 1))
      let side = shape([], fill: UIColor(red: 0.075, green: 0.075, blue: 0.24, alpha: 1))
      let edge = shape(
        [], stroke: index % 4 == 0 ? coral.withAlphaComponent(0.6) : cyan.withAlphaComponent(0.4))
      edge.lineWidth = 1
      tower.addChild(front)
      tower.addChild(side)
      tower.addChild(edge)
      landscape.addChild(tower)
      towers.append(tower)
    }
    buildCraft()
  }

  private func buildSky() {
    sky.removeAllChildren()
    let w = size.width
    let h = size.height
    guard w > 0, h > 0 else { return }
    for index in 0..<85 {
      let x = CGFloat((index * 173 + 47) % 997) / 997 * w
      let y = h * (0.42 + CGFloat((index * 257 + 83) % 991) / 991 * 0.58)
      let star = SKShapeNode(circleOfRadius: index % 7 == 0 ? 1.1 : 0.55)
      star.fillColor = cyan.withAlphaComponent(index % 7 == 0 ? 0.65 : 0.23)
      star.strokeColor = .clear
      star.position = CGPoint(x: x, y: y)
      sky.addChild(star)
    }
    let center = CGPoint(x: w * 0.5, y: horizon + h * 0.092)
    for index in (1...12).reversed() {
      let aura = SKShapeNode(circleOfRadius: w * (0.1 + CGFloat(index) * 0.012))
      aura.fillColor = UIColor(red: 0.15, green: 0.22, blue: 0.7, alpha: 0.013)
      aura.strokeColor = .clear
      aura.position = center
      sky.addChild(aura)
    }
    let moon = SKShapeNode(circleOfRadius: w * 0.105)
    moon.fillColor = UIColor(red: 0.033, green: 0.053, blue: 0.12, alpha: 1)
    moon.strokeColor = cyan.withAlphaComponent(0.65)
    moon.lineWidth = 1
    moon.glowWidth = 2
    moon.position = center
    sky.addChild(moon)
    let orbit = SKShapeNode(ellipseOf: CGSize(width: w * 0.4, height: w * 0.055))
    orbit.strokeColor = cyan.withAlphaComponent(0.3)
    orbit.lineWidth = 0.7
    orbit.position = center
    orbit.zRotation = -0.35
    sky.addChild(orbit)
    for index in 0..<9 {
      let y = center.y - w * 0.095 + CGFloat(index) * w * 0.018
      let radius = w * 0.105
      let half = sqrt(max(0, radius * radius - pow(y - center.y, 2)))
      let scan = shape(
        [CGPoint(x: center.x - half, y: y), CGPoint(x: center.x + half, y: y)],
        stroke: cyan.withAlphaComponent(0.10))
      sky.addChild(scan)
    }
    for side in [-1.0, 1.0] {
      var points = [CGPoint(x: w / 2, y: horizon - 8)]
      for index in 0...12 {
        let x = w / 2 + side * CGFloat(index) * w / 20
        let height = CGFloat((index * 31 + 7) % 49)
        points.append(CGPoint(x: x, y: horizon + height - CGFloat(index) * 3))
      }
      points.append(CGPoint(x: side < 0 ? 0 : w, y: horizon - h * 0.2))
      sky.addChild(
        shape(points, fill: UIColor(red: 0.06, green: 0.055, blue: 0.17, alpha: 1), closed: true))
    }
    let horizonLine = shape(
      [CGPoint(x: 0, y: horizon), CGPoint(x: w, y: horizon)],
      stroke: cyan.withAlphaComponent(0.18))
    sky.addChild(horizonLine)
  }

  private func buildCraft() {
    let shadow = SKShapeNode(ellipseOf: CGSize(width: 76, height: 20))
    shadow.fillColor = cyan.withAlphaComponent(0.08)
    shadow.strokeColor = .clear
    shadow.glowWidth = 12
    shadow.position.y = -10
    craft.addChild(shadow)
    for side: CGFloat in [-1, 1] {
      let trail = shape(
        [
          CGPoint(x: side * 19 - 4, y: -8), CGPoint(x: side * 19 + 4, y: -8),
          CGPoint(x: side * 27, y: -102),
        ],
        fill: cyan.withAlphaComponent(0.22), closed: true)
      trail.glowWidth = 4
      trail.strokeColor = cyan.withAlphaComponent(0.25)
      trail.run(
        .repeatForever(
          .sequence([.fadeAlpha(to: 0.45, duration: 0.14), .fadeAlpha(to: 1, duration: 0.16)])))
      craft.addChild(trail)
    }
    let hull = shape(
      [
        CGPoint(x: 0, y: 37), CGPoint(x: 31, y: -17), CGPoint(x: 15, y: -11),
        CGPoint(x: 0, y: -20), CGPoint(x: -15, y: -11), CGPoint(x: -31, y: -17),
      ],
      fill: UIColor(red: 0.08, green: 0.23, blue: 0.29, alpha: 1), stroke: cyan, closed: true)
    hull.lineWidth = 1.8
    hull.glowWidth = 2
    craft.addChild(hull)
    let cockpit = shape(
      [CGPoint(x: 0, y: 25), CGPoint(x: 9, y: -6), CGPoint(x: 0, y: 0), CGPoint(x: -9, y: -6)],
      fill: UIColor(red: 0.76, green: 1, blue: 1, alpha: 1), closed: true)
    craft.addChild(cockpit)
    for side: CGFloat in [-1, 1] {
      let wing = shape(
        [
          CGPoint(x: side * 12, y: 12), CGPoint(x: side * 23, y: -10), CGPoint(x: side * 16, y: -5),
        ],
        fill: cyan.withAlphaComponent(0.7), closed: true)
      craft.addChild(wing)
      let jet = shape(
        [
          CGPoint(x: side * 19 - 3, y: -16), CGPoint(x: side * 19 + 3, y: -16),
          CGPoint(x: side * 19, y: -44),
        ],
        fill: .white, stroke: cyan, closed: true)
      jet.glowWidth = 4
      craft.addChild(jet)
    }
  }

  private func point(lane: CGFloat, depth: CGFloat) -> CGPoint {
    let scale = 0.08 + pow(max(0, depth), 1.6) * 0.92
    let bend = sin(clock * 0.15) * size.width * 0.045 * (1 - depth)
    return CGPoint(
      x: size.width / 2 + bend + (lane - 1) * size.width * 0.26 * scale,
      y: horizon - (horizon - landing) * pow(max(0, depth), 1.65))
  }

  override func update(_ currentTime: TimeInterval) {
    let delta = lastTime == 0 ? 0 : min(1.0 / 20, currentTime - lastTime)
    lastTime = currentTime
    let moving = home || flight?.engine.phase == .running
    if moving { clock += delta }
    flight?.tick(delta)
    renderRoad()
    renderWaves()
    let lane = home ? 1 : Double(flight?.engine.lane ?? 1)
    visualLane += (lane - visualLane) * min(1, delta * 14)
    let destination = point(lane: visualLane, depth: 1)
    craft.position = CGPoint(x: destination.x, y: destination.y + CGFloat(sin(clock * 3)) * 2)
    craft.zRotation = CGFloat(visualLane - lane) * 0.22
    craft.alpha = flight?.engine.phase == .ended ? 0.3 : 1
  }

  private func renderRoad() {
    var border: [CGPoint] = []
    for index in 0...30 { border.append(point(lane: -0.65, depth: CGFloat(index) / 20)) }
    for index in (0...30).reversed() {
      border.append(point(lane: 2.65, depth: CGFloat(index) / 20))
    }
    road.path = path(border, closed: true)
    for (index, line) in laneLines.enumerated() {
      line.path = path((0...35).map { point(lane: CGFloat(index) - 0.5, depth: CGFloat($0) / 24) })
    }
    for (index, line) in rungs.enumerated() {
      let depth = (CGFloat(index) / 17 + CGFloat(clock * 0.09)).truncatingRemainder(dividingBy: 1.3)
      line.path = path([point(lane: -0.5, depth: depth), point(lane: 2.5, depth: depth)])
      line.alpha = depth * 0.7
    }
    for (index, tower) in towers.enumerated() {
      let side: CGFloat = index % 2 == 0 ? -1 : 1
      let depth = (CGFloat(index / 2) / 12 + CGFloat(clock * 0.028)).truncatingRemainder(
        dividingBy: 1.16)
      let base = point(lane: 1 + side * (2.05 + CGFloat(index % 3) * 0.13), depth: depth)
      let scale = 0.12 + depth * depth
      let width = size.width * 0.14 * scale
      let height = size.height * (0.17 + CGFloat(index % 5) * 0.027) * scale
      let peak = CGPoint(x: base.x - side * width * 0.3, y: base.y + height)
      let front = tower.children[0] as! SKShapeNode
      let facet = tower.children[1] as! SKShapeNode
      let edge = tower.children[2] as! SKShapeNode
      front.path = path(
        [
          CGPoint(x: base.x - width / 2, y: base.y), CGPoint(x: base.x + width / 2, y: base.y),
          CGPoint(x: peak.x + width / 2, y: peak.y - 15 * scale), peak,
        ], closed: true)
      facet.path = path(
        [
          base, CGPoint(x: base.x + width / 2, y: base.y),
          CGPoint(x: peak.x + width / 2, y: peak.y - 15 * scale), peak,
        ], closed: true)
      edge.path = path([base, peak, CGPoint(x: peak.x + width / 2, y: peak.y - 15 * scale)])
      tower.alpha = min(1, 0.15 + depth * 1.1)
      tower.zPosition = depth
    }
  }

  private func renderWaves() {
    let waves = flight?.engine.waves ?? []
    let ids = Set(waves.map(\.id))
    for id in Array(waveNodes.keys) where !ids.contains(id) {
      waveNodes.removeValue(forKey: id)?.removeFromParent()
    }
    for wave in waves {
      if waveNodes[wave.id] == nil {
        let group = SKNode()
        group.addChild(hazardNode())
        group.addChild(energyNode())
        traffic.addChild(group)
        waveNodes[wave.id] = group
      }
      guard let group = waveNodes[wave.id] else { continue }
      let depth = CGFloat(wave.progress)
      for (index, lane) in [wave.hazard, wave.energy].enumerated() {
        let node = group.children[index]
        node.position = point(lane: CGFloat(lane), depth: depth)
        node.setScale(0.08 + pow(depth, 1.45) * 0.92)
        node.alpha = min(1, depth * 4)
      }
      group.zPosition = depth * 10
      group.children[1].zRotation = CGFloat(sin(clock * 2)) * 0.12
    }
  }

  private func hazardNode() -> SKNode {
    let group = SKNode()
    let shadow = SKShapeNode(ellipseOf: CGSize(width: 65, height: 20))
    shadow.fillColor = coral.withAlphaComponent(0.18)
    shadow.strokeColor = .clear
    group.addChild(shadow)
    let body = shape(
      [
        CGPoint(x: -28, y: 3), CGPoint(x: -19, y: 36), CGPoint(x: 14, y: 44),
        CGPoint(x: 29, y: 19), CGPoint(x: 24, y: -8), CGPoint(x: -17, y: -12),
      ],
      fill: UIColor(red: 0.24, green: 0.055, blue: 0.12, alpha: 1), stroke: coral, closed: true)
    body.lineWidth = 2
    body.glowWidth = 2
    group.addChild(body)
    group.addChild(
      shape(
        [
          CGPoint(x: -19, y: 36), CGPoint(x: -7, y: 13), CGPoint(x: 24, y: -8),
          CGPoint(x: 14, y: 44), CGPoint(x: -7, y: 13), CGPoint(x: -17, y: -12),
        ],
        stroke: coral.withAlphaComponent(0.7)))
    let warning = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
    warning.text = "!"
    warning.fontSize = 23
    warning.fontColor = UIColor(red: 1, green: 0.7, blue: 0.7, alpha: 1)
    warning.position = CGPoint(x: 3, y: 5)
    group.addChild(warning)
    return group
  }

  private func energyNode() -> SKNode {
    let group = SKNode()
    let ring = shape(
      (0..<6).map {
        let angle = CGFloat($0) * .pi / 3
        return CGPoint(x: cos(angle) * 23, y: sin(angle) * 23 + 15)
      }, stroke: cyan, closed: true)
    ring.lineWidth = 2
    ring.glowWidth = 3
    group.addChild(ring)
    let core = shape(
      [
        CGPoint(x: 3, y: 31), CGPoint(x: -9, y: 12), CGPoint(x: 0, y: 12),
        CGPoint(x: -3, y: -1), CGPoint(x: 10, y: 19), CGPoint(x: 2, y: 19),
      ],
      fill: .white, stroke: cyan, closed: true)
    core.glowWidth = 3
    group.addChild(core)
    return group
  }

  func burst(collision: Bool) {
    for index in 0..<18 {
      let spark = SKShapeNode(circleOfRadius: CGFloat(index % 3 + 1))
      spark.fillColor = collision ? coral : cyan
      spark.strokeColor = .clear
      spark.glowWidth = 2
      spark.position = craft.position
      effects.addChild(spark)
      let angle = Double(index) / 18 * .pi * 2
      let radius = CGFloat(45 + index * 3)
      spark.run(
        .sequence([
          .group([
            .moveBy(x: cos(angle) * radius, y: sin(angle) * radius, duration: 0.65),
            .fadeOut(withDuration: 0.65),
          ]),
          .removeFromParent(),
        ]))
    }
  }

  private func shape(
    _ points: [CGPoint], fill: UIColor = .clear, stroke: UIColor = .clear, closed: Bool = false
  ) -> SKShapeNode {
    let node = SKShapeNode(path: path(points, closed: closed))
    node.fillColor = fill
    node.strokeColor = stroke
    return node
  }

  private func path(_ points: [CGPoint], closed: Bool = false) -> CGPath {
    let result = CGMutablePath()
    guard let first = points.first else { return result }
    result.move(to: first)
    for point in points.dropFirst() { result.addLine(to: point) }
    if closed { result.closeSubpath() }
    return result
  }
}
