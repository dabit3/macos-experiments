import SpriteKit
import UIKit

final class HighwayScene: SKScene {
  weak var store: GameStore?

  private var built = false
  private var lastTime: TimeInterval?
  private let world = SKNode()
  private var boardTiles: [SKSpriteNode] = []
  private var laneXs: [CGFloat] = []
  private var laneWidth: CGFloat = 0
  private var playerY: CGFloat = 0
  private var pixelsPerMeter: CGFloat = 8
  private var idleDistance: Double = 0
  private var entityNodes: [Int: SKNode] = [:]
  private var touchStart: CGPoint?
  private var lineClock: Double = 0
  private var boosting = false
  private var crashed = false

  private let player = SKNode()
  private let card = SKNode()
  private var cardShadow: SKShapeNode?
  private var fans: [SKNode] = []
  private var trail: SKEmitterNode?
  private var boostTrail: SKEmitterNode?

  private lazy var pcbTexture = Self.makePCBTexture()
  private lazy var sparkTexture = Self.makeSparkTexture()

  override func didMove(to view: SKView) {
    view.preferredFramesPerSecond = 60
    view.ignoresSiblingOrder = true
    buildIfNeeded()
  }

  override func didChangeSize(_ oldSize: CGSize) { buildIfNeeded() }

  private func buildIfNeeded() {
    guard !built, size.width > 10, size.height > 10 else { return }
    built = true
    backgroundColor = Palette.uiBoard
    addChild(world)

    laneWidth = size.width * 0.22
    laneXs = [size.width / 2 - laneWidth, size.width / 2, size.width / 2 + laneWidth]
    playerY = size.height * 0.22
    pixelsPerMeter = size.height * 0.55 / 60

    for index in 0..<2 {
      let tile = SKSpriteNode(
        texture: pcbTexture, size: CGSize(width: size.width, height: size.height + 4))
      tile.position = CGPoint(x: size.width / 2, y: size.height / 2 + CGFloat(index) * size.height)
      tile.zPosition = -10
      world.addChild(tile)
      boardTiles.append(tile)
    }
    buildRails()
    buildPlayer()
    buildEmitters()
  }

  private func buildRails() {
    for x in [size.width / 2 - laneWidth * 1.5, size.width / 2 + laneWidth * 1.5] {
      let rail = SKShapeNode(rect: CGRect(x: x - 1.5, y: -10, width: 3, height: size.height + 20))
      rail.fillColor = Palette.uiGreen.withAlphaComponent(0.8)
      rail.strokeColor = .clear
      rail.glowWidth = 8
      rail.zPosition = -5
      world.addChild(rail)
    }
    for x in [size.width / 2 - laneWidth / 2, size.width / 2 + laneWidth / 2] {
      let path = CGMutablePath()
      path.move(to: CGPoint(x: x, y: -10))
      path.addLine(to: CGPoint(x: x, y: size.height + 10))
      let dashed = path.copy(dashingWithPhase: 0, lengths: [14, 22])
      let divider = SKShapeNode(path: dashed)
      divider.strokeColor = Palette.uiGreen.withAlphaComponent(0.35)
      divider.lineWidth = 2
      divider.zPosition = -5
      world.addChild(divider)
    }
  }

  private func buildPlayer() {
    let width = laneWidth * 0.74
    let height = width * 1.35

    let shadow = SKShapeNode(ellipseOf: CGSize(width: width * 1.05, height: height * 0.32))
    shadow.fillColor = .black.withAlphaComponent(0.55)
    shadow.strokeColor = .clear
    shadow.position = CGPoint(x: 0, y: -height * 0.42)
    shadow.zPosition = -1
    cardShadow = shadow
    player.addChild(shadow)

    let body = SKShapeNode(
      rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
      cornerRadius: width * 0.12)
    body.fillColor = Palette.uiCharcoal
    body.strokeColor = Palette.uiGreen.withAlphaComponent(0.9)
    body.lineWidth = 2
    body.glowWidth = 6
    card.addChild(body)

    let stripe = SKShapeNode(
      rect: CGRect(x: -width / 2, y: height / 2 - 8, width: width, height: 5))
    stripe.fillColor = Palette.uiGreen
    stripe.strokeColor = .clear
    card.addChild(stripe)

    for fanX in [-width * 0.24, width * 0.24] {
      let fan = SKNode()
      fan.position = CGPoint(x: fanX, y: height * 0.12)
      let ring = SKShapeNode(circleOfRadius: width * 0.17)
      ring.fillColor = Palette.uiBoard
      ring.strokeColor = Palette.uiGreen.withAlphaComponent(0.7)
      ring.lineWidth = 1.5
      fan.addChild(ring)
      for blade in 0..<5 {
        let spoke = SKShapeNode(
          rect: CGRect(x: -1.5, y: 0, width: 3, height: width * 0.15))
        spoke.fillColor = Palette.uiGreen.withAlphaComponent(0.6)
        spoke.strokeColor = .clear
        spoke.zRotation = CGFloat(blade) * .pi * 2 / 5
        fan.addChild(spoke)
      }
      fan.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 0.7)))
      fans.append(fan)
      card.addChild(fan)
    }

    for index in 0..<6 {
      let finger = SKShapeNode(
        rect: CGRect(
          x: -width * 0.36 + CGFloat(index) * width * 0.13, y: -height / 2 - 6,
          width: width * 0.08, height: 7))
      finger.fillColor = Palette.uiGold
      finger.strokeColor = .clear
      card.addChild(finger)
    }

    player.addChild(card)
    player.position = CGPoint(x: laneXs[1], y: playerY)
    player.zPosition = 10
    player.alpha = 0
    world.addChild(player)
  }

  private func setPlayerHidden(_ hidden: Bool) {
    let target: CGFloat = hidden ? 0 : 1
    guard player.action(forKey: "fade") == nil, player.alpha != target else { return }
    player.run(.fadeAlpha(to: target, duration: 0.2), withKey: "fade")
  }

  private func buildEmitters() {
    let trail = Self.makeEmitter(
      texture: sparkTexture, color: Palette.uiGreen, birthRate: 90, lifetime: 0.5,
      speed: 60, scale: 0.35)
    trail.position = CGPoint(x: 0, y: -20)
    trail.zPosition = -1
    player.addChild(trail)
    self.trail = trail

    let boost = Self.makeEmitter(
      texture: sparkTexture, color: Palette.uiGreenBright, birthRate: 240, lifetime: 0.9,
      speed: 320, scale: 0.3)
    boost.position = CGPoint(x: 0, y: -16)
    boost.yScale = 4
    boost.zPosition = -1
    boost.particleBirthRate = 0
    player.addChild(boost)
    boostTrail = boost
  }

  private static func makeEmitter(
    texture: SKTexture, color: UIColor, birthRate: CGFloat, lifetime: CGFloat,
    speed: CGFloat, scale: CGFloat
  ) -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.particleTexture = texture
    emitter.particleBirthRate = birthRate
    emitter.particleLifetime = lifetime
    emitter.particleSpeed = speed
    emitter.particleSpeedRange = speed * 0.4
    emitter.emissionAngle = -.pi / 2
    emitter.emissionAngleRange = 0.4
    emitter.particleScale = scale
    emitter.particleScaleSpeed = -scale / lifetime
    emitter.particleAlpha = 0.8
    emitter.particleAlphaSpeed = -1.4
    emitter.particleColor = color
    emitter.particleColorBlendFactor = 1
    emitter.particleBlendMode = .add
    return emitter
  }

  func resetForRun() {
    for node in entityNodes.values { node.removeFromParent() }
    entityNodes = [:]
    crashed = false
    boosting = false
    boostTrail?.particleBirthRate = 0
    trail?.particleBirthRate = 90
    card.removeAllActions()
    player.removeAllActions()
    card.setScale(1)
    card.yScale = 1
    card.zRotation = 0
    card.alpha = 1
    player.alpha = 0
    player.position = CGPoint(x: laneXs[1], y: playerY)
    world.position = .zero
    setPlayerHidden(false)
  }

  // MARK: - Frame loop

  override func update(_ currentTime: TimeInterval) {
    let dt: Double
    if let lastTime {
      dt = min(0.05, max(0, currentTime - lastTime))
    } else {
      dt = 0
    }
    lastTime = currentTime
    guard built else { return }

    var scrollSpeed = 8.0
    if let store, store.screen == .playing {
      let events = store.tick(dt)
      handle(events: events)
      syncEntities(runDistance: store.sim.state.runDistance)
      scrollSpeed = store.sim.state.phase == .running ? store.sim.state.speed : 0
      syncPlayer(state: store.sim.state)
      setPlayerHidden(false)
    } else {
      idleDistance += dt * scrollSpeed
      syncEntities(runDistance: store?.sim.state.runDistance ?? 0)
      if let store { syncPlayer(state: store.sim.state) }
      setPlayerHidden(true)
    }
    scrollBoard(by: scrollSpeed, dt: dt)
    updateSpeedLines(dt: dt)
  }

  private func scrollBoard(by speed: Double, dt: Double) {
    let dy = CGFloat(speed) * pixelsPerMeter * CGFloat(dt)
    for tile in boardTiles {
      tile.position.y -= dy
      if tile.position.y < -size.height / 2 {
        tile.position.y += size.height * CGFloat(boardTiles.count)
      }
    }
  }

  private func syncPlayer(state: RunState) {
    guard !crashed else { return }
    if player.action(forKey: "lane") == nil {
      player.position.x = laneXs[state.lane.rawValue]
    }
  }

  private func syncEntities(runDistance: Double) {
    guard let store else { return }
    var seen: Set<Int> = []
    for entity in store.sim.state.entities {
      seen.insert(entity.id)
      let node = entityNodes[entity.id] ?? makeEntityNode(entity)
      entityNodes[entity.id] = node
      let y = playerY + CGFloat(entity.distance - runDistance) * pixelsPerMeter
      node.position = CGPoint(x: laneXs[entity.lane.rawValue], y: y)
      let scale = 0.55 + 0.6 * min(1, max(0, y / size.height))
      node.setScale(scale)
      node.alpha = y > -40 ? 1 : 0
    }
    for (id, node) in entityNodes where !seen.contains(id) {
      node.removeFromParent()
      entityNodes.removeValue(forKey: id)
    }
  }

  private func makeEntityNode(_ entity: Entity) -> SKNode {
    let node = SKNode()
    switch entity.kind {
    case .obstacle(.heatWave):
      let width = laneWidth * 0.92
      for index in 0..<3 {
        let band = SKShapeNode(
          rect: CGRect(
            x: -width / 2, y: -14 + CGFloat(index) * 12, width: width, height: 7),
          cornerRadius: 3)
        band.fillColor = Palette.uiHeat.withAlphaComponent(0.55)
        band.strokeColor = Palette.uiHeat
        band.glowWidth = 6
        band.lineWidth = 1
        node.addChild(band)
      }
      node.run(
        .repeatForever(
          .sequence([
            .fadeAlpha(to: 0.45, duration: 0.28),
            .fadeAlpha(to: 1, duration: 0.28),
          ])))
    case .obstacle(.capacitorBar):
      let width = laneWidth * 0.92
      for postX in [-width / 2 + 6, width / 2 - 6] {
        let post = SKShapeNode(rect: CGRect(x: postX - 4, y: -18, width: 8, height: 36))
        post.fillColor = Palette.uiCyan.withAlphaComponent(0.8)
        post.strokeColor = .clear
        post.glowWidth = 4
        node.addChild(post)
      }
      let bar = SKShapeNode(
        rect: CGRect(x: -width / 2, y: 10, width: width, height: 12), cornerRadius: 4)
      bar.fillColor = Palette.uiCyan.withAlphaComponent(0.75)
      bar.strokeColor = Palette.uiCyan
      bar.glowWidth = 8
      node.addChild(bar)
    case .pickup(.cudaCoin):
      let spinner = SKNode()
      let coin = SKShapeNode(path: Self.hexagon(radius: 15))
      coin.fillColor = Palette.uiGreen.withAlphaComponent(0.85)
      coin.strokeColor = Palette.uiGreenBright
      coin.glowWidth = 6
      spinner.addChild(coin)
      let label = SKLabelNode(text: "C")
      label.fontName = "Menlo-Bold"
      label.fontSize = 15
      label.fontColor = Palette.uiBoard
      label.verticalAlignmentMode = .center
      spinner.addChild(label)
      spinner.run(
        .repeatForever(
          .sequence([
            .scaleX(to: 0.25, duration: 0.5),
            .scaleX(to: 1, duration: 0.5),
          ])))
      node.addChild(spinner)
    case .pickup(.dlssOrb):
      let pulsing = SKNode()
      let orb = SKShapeNode(circleOfRadius: 16)
      orb.fillColor = Palette.uiGreenBright.withAlphaComponent(0.9)
      orb.glowWidth = 14
      orb.strokeColor = .white
      pulsing.addChild(orb)
      let ring = SKShapeNode(circleOfRadius: 24)
      ring.strokeColor = Palette.uiGreen.withAlphaComponent(0.7)
      ring.lineWidth = 2
      ring.glowWidth = 5
      pulsing.addChild(ring)
      pulsing.run(
        .repeatForever(
          .sequence([
            .scale(to: 1.2, duration: 0.45),
            .scale(to: 0.95, duration: 0.45),
          ])))
      node.addChild(pulsing)
    }
    world.addChild(node)
    return node
  }

  private static func hexagon(radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for index in 0..<6 {
      let angle = CGFloat(index) * .pi / 3 + .pi / 6
      let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
      if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
  }

  // MARK: - Event FX

  private func handle(events: [RunEvent]) {
    for event in events {
      switch event {
      case .laneChanged(let lane):
        let move = SKAction.moveTo(x: laneXs[lane.rawValue], duration: 0.14)
        move.timingMode = .easeOut
        player.run(move, withKey: "lane")
        let tilt = SKAction.sequence([
          .rotate(byAngle: lane == .left ? 0.1 : -0.1, duration: 0.08),
          .rotate(toAngle: 0, duration: 0.12),
        ])
        card.run(tilt)
      case .jumped:
        let up = SKAction.scale(to: 1.25, duration: 0.2)
        up.timingMode = .easeOut
        let down = SKAction.scale(to: 1, duration: 0.3)
        down.timingMode = .easeIn
        card.run(.sequence([up, down]), withKey: "stance")
        cardShadow?.run(
          .sequence([
            .fadeAlpha(to: 0.2, duration: 0.2), .fadeAlpha(to: 1, duration: 0.3),
          ]))
      case .slid:
        let flat = SKAction.scaleY(to: 0.55, duration: 0.1)
        let restore = SKAction.sequence([
          .wait(forDuration: 0.45), .scaleY(to: 1, duration: 0.15),
        ])
        card.run(.sequence([flat, restore]), withKey: "stance")
      case .coin:
        burst(at: player.position, color: Palette.uiGreenBright, count: 10)
      case .dlssActivated:
        boosting = true
        boostTrail?.particleBirthRate = 240
      case .dlssEnded:
        boosting = false
        boostTrail?.particleBirthRate = 0
      case .crashed:
        crashFX()
      case .milestone:
        break
      }
    }
  }

  private func burst(at position: CGPoint, color: UIColor, count: Int) {
    let emitter = Self.makeEmitter(
      texture: sparkTexture, color: color, birthRate: 0, lifetime: 0.45,
      speed: 160, scale: 0.4)
    emitter.numParticlesToEmit = count
    emitter.emissionAngleRange = .pi * 2
    emitter.position = position
    emitter.zPosition = 20
    world.addChild(emitter)
    emitter.run(.sequence([.wait(forDuration: 1), .removeFromParent()]))
  }

  private func crashFX() {
    crashed = true
    trail?.particleBirthRate = 0
    boostTrail?.particleBirthRate = 0
    burst(at: player.position, color: Palette.uiHeat, count: 40)
    burst(at: player.position, color: .white, count: 16)
    let flash = SKAction.sequence([
      .fadeAlpha(to: 0.25, duration: 0.07), .fadeAlpha(to: 1, duration: 0.07),
    ])
    card.run(.repeat(flash, count: 5))
    if store?.reduceMotion != true { shake() }
  }

  private func shake() {
    var actions: [SKAction] = []
    for _ in 0..<8 {
      actions.append(
        .moveBy(
          x: CGFloat.random(in: -14...14), y: CGFloat.random(in: -14...14),
          duration: 0.045))
    }
    actions.append(.move(to: .zero, duration: 0.05))
    world.run(.sequence(actions))
  }

  private func updateSpeedLines(dt: Double) {
    guard boosting else { return }
    lineClock -= dt
    if lineClock <= 0 {
      lineClock = 0.05
      let x = CGFloat.random(in: size.width * 0.08...size.width * 0.92)
      let line = SKShapeNode(rect: CGRect(x: x, y: size.height + 60, width: 2, height: 70))
      line.fillColor = Palette.uiGreenBright.withAlphaComponent(0.5)
      line.strokeColor = .clear
      line.zPosition = -4
      world.addChild(line)
      line.run(
        .sequence([
          .moveBy(x: 0, y: -size.height - 200, duration: 0.4), .removeFromParent(),
        ]))
    }
  }

  // MARK: - Touch input

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchStart = touches.first?.location(in: self)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let start = touchStart, let current = touches.first?.location(in: self)
    else { return }
    let dx = current.x - start.x
    let dy = current.y - start.y
    if abs(dx) > 34, abs(dx) > abs(dy) {
      store?.input(dx > 0 ? .right : .left)
      touchStart = nil
    } else if abs(dy) > 34, abs(dy) >= abs(dx) {
      store?.input(dy > 0 ? .jump : .slide)
      touchStart = nil
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let start = touchStart, let end = touches.first?.location(in: self) else {
      touchStart = nil
      return
    }
    touchStart = nil
    let dx = end.x - start.x
    let dy = end.y - start.y
    if abs(dx) < 16, abs(dy) < 16 {
      store?.input(.jump)
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchStart = nil
  }

  // MARK: - Procedural textures

  private static func makeTexture(_ side: CGFloat, _ draw: (CGContext, CGSize) -> Void)
    -> SKTexture
  {
    let size = CGSize(width: side, height: side)
    let image = UIGraphicsImageRenderer(size: size).image { context in
      draw(context.cgContext, size)
    }
    return SKTexture(image: image)
  }

  private static func makePCBTexture() -> SKTexture {
    makeTexture(512) { context, size in
      context.setFillColor(Palette.uiBoard.cgColor)
      context.fill(CGRect(origin: .zero, size: size))
      context.setStrokeColor(Palette.uiGreen.withAlphaComponent(0.08).cgColor)
      context.setLineWidth(2)
      var random = SeededRandom(state: 7)
      for _ in 0..<22 {
        let y = CGFloat(random.next()) * size.height
        let mid = CGFloat(random.next()) * size.width
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: mid, y: y))
        context.addLine(to: CGPoint(x: mid + 40, y: y + (random.next() > 0.5 ? 40 : -40)))
        context.addLine(to: CGPoint(x: size.width, y: y + (random.next() > 0.5 ? 40 : -40)))
        context.strokePath()
      }
      context.setFillColor(Palette.uiGreen.withAlphaComponent(0.12).cgColor)
      for _ in 0..<30 {
        context.fillEllipse(
          in: CGRect(
            x: CGFloat(random.next()) * size.width, y: CGFloat(random.next()) * size.height,
            width: 7, height: 7))
      }
      context.setStrokeColor(Palette.uiGreen.withAlphaComponent(0.1).cgColor)
      for _ in 0..<6 {
        context.stroke(
          CGRect(
            x: CGFloat(random.next()) * size.width * 0.8,
            y: CGFloat(random.next()) * size.height * 0.8,
            width: 60 + CGFloat(random.next()) * 80,
            height: 30 + CGFloat(random.next()) * 60))
      }
    }
  }

  private static func makeSparkTexture() -> SKTexture {
    makeTexture(32) { context, size in
      let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
      context.drawRadialGradient(
        gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
        endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
    }
  }
}
