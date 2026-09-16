import SpriteKit
import UIKit

final class SliceableNode: SKSpriteNode {
  let kind: SliceableKind
  let baseImage: UIImage
  let silhouette: [V2]

  init(kind: SliceableKind) {
    self.kind = kind
    baseImage = ProceduralArt.image(for: kind)
    silhouette = ProceduralArt.silhouette(for: kind)
    let texture = SKTexture(image: baseImage)
    super.init(texture: texture, color: .clear, size: baseImage.size)
    let body = SKPhysicsBody(circleOfRadius: CGFloat(kind.radius))
    body.categoryBitMask = 1
    body.collisionBitMask = 0
    body.contactTestBitMask = 0
    body.allowsRotation = true
    body.linearDamping = 0
    body.angularDamping = 0
    physicsBody = body
    zPosition = kind == .flagship ? 12 : 10
  }

  required init?(coder aDecoder: NSCoder) { fatalError("Not supported") }
}

/// SpriteKit playfield. Owns physics, slicing, particles, shake and the blade
/// trail. All rules decisions are delegated to `GameStore` / `GameSession`.
final class GameScene: SKScene {
  weak var store: GameStore?

  private let world = SKNode()
  private let launcher = SKNode()
  private let effects = SKNode()
  private var background: SKSpriteNode?
  private var slowMoVignette: SKShapeNode?
  private var slowMoTint: SKSpriteNode?
  private var targets: [SliceableNode] = []
  private let blade = BladeTrail()
  private var lastUpdate: TimeInterval = 0
  private var sceneTime: TimeInterval = 0
  private var isAttract = true
  private var attractNextLaunch: TimeInterval = 0.6
  private var attractRandom = SeededRandom(seed: UInt64(Date().timeIntervalSince1970))
  private var swipeActive = false
  private var lastTouchPoint: CGPoint?
  private var backgroundSize: CGSize = .zero
  private var runPaused = false

  private let labelFont = "Futura-CondensedExtraBold"

  override func didMove(to view: SKView) {
    backgroundColor = UIColor(red: 0.03, green: 0.035, blue: 0.04, alpha: 1)
    physicsWorld.gravity = CGVector(dx: 0, dy: -GameRules.gravity / 150)
    if launcher.parent == nil { world.addChild(launcher) }
    if world.parent == nil {
      addChild(world)
      addChild(effects)
      addChild(blade.node)
      effects.zPosition = 60
    }
    view.isMultipleTouchEnabled = true
    view.ignoresSiblingOrder = true
    view.preferredFramesPerSecond = 60
    rebuildBackground()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    rebuildBackground()
  }

  private func rebuildBackground() {
    guard size.width > 10, size.height > 10 else { return }
    if abs(backgroundSize.width - size.width) < 1, abs(backgroundSize.height - size.height) < 1 {
      return
    }
    backgroundSize = size
    background?.removeFromParent()
    let image = ProceduralArt.pcbBackground(size: size, seed: 0xC0DE)
    let sprite = SKSpriteNode(texture: SKTexture(image: image))
    sprite.size = size
    sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
    sprite.zPosition = -20
    addChild(sprite)
    background = sprite

    slowMoVignette?.removeFromParent()
    slowMoTint?.removeFromParent()
    let vignette = SKShapeNode(
      rect: CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12), cornerRadius: 28)
    vignette.strokeColor = UIColor(red: 0.62, green: 0.9, blue: 0.2, alpha: 0.9)
    vignette.lineWidth = 6
    vignette.glowWidth = 26
    vignette.fillColor = .clear
    vignette.blendMode = .add
    vignette.alpha = 0
    vignette.zPosition = 40
    addChild(vignette)
    slowMoVignette = vignette
    let tint = SKSpriteNode(color: UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 1), size: size)
    tint.position = sprite.position
    tint.alpha = 0
    tint.zPosition = 39
    tint.blendMode = .add
    addChild(tint)
    slowMoTint = tint
  }

  // MARK: - Run lifecycle

  func beginAttract() {
    isAttract = true
    clearPlayfield()
    world.speed = 1
    physicsWorld.speed = 1
    slowMoVignette?.alpha = 0
    slowMoTint?.alpha = 0
    attractNextLaunch = sceneTime + 0.5
  }

  func beginRun() {
    isAttract = false
    clearPlayfield()
    world.speed = 1
    physicsWorld.speed = 1
    slowMoVignette?.alpha = 0
    slowMoTint?.alpha = 0
    flashText("FAB LINE ONLINE", color: ProceduralArt.nvGreenBright, size: 34, duration: 1.1)
  }

  func runEnded() {
    swipeActive = false
    blade.end()
    world.speed = 1
    physicsWorld.speed = 1
    slowMoVignette?.run(.fadeOut(withDuration: 0.3))
    slowMoTint?.run(.fadeOut(withDuration: 0.3))
    launcher.removeAllActions()
  }

  func setPaused(_ paused: Bool) {
    runPaused = paused
    world.isPaused = paused
    physicsWorld.speed = paused ? 0 : (store?.timeScale ?? 1)
    if paused {
      swipeActive = false
      blade.end()
    }
  }

  private func clearPlayfield() {
    for target in targets { target.removeFromParent() }
    targets = []
    for child in world.children where child !== launcher { child.removeFromParent() }
    world.removeAllActions()
    launcher.removeAllActions()
    effects.removeAllChildren()
    world.position = .zero
    runPaused = false
    world.isPaused = false
  }

  // MARK: - Frame loop

  override func update(_ currentTime: TimeInterval) {
    let dt = lastUpdate > 0 ? min(currentTime - lastUpdate, 1.0 / 20) : 0
    lastUpdate = currentTime
    sceneTime = currentTime
    blade.update(time: currentTime)

    if isAttract {
      if currentTime >= attractNextLaunch {
        attractNextLaunch = currentTime + attractRandom.next(in: 1.1...2.0)
        let kind = attractRandom.pick([
          SliceableKind.wafer, .chiplet, .heatsink, .wafer, .flagship,
        ])
        let xFraction = attractRandom.next(in: 0.2...0.8)
        let apex = Double(size.height) * attractRandom.next(in: 0.5...0.68)
        launch(
          LaunchSpec(
            kind: kind, xFraction: xFraction, velocityX: (0.5 - xFraction) * 200,
            velocityY: (2 * GameRules.gravity * apex).squareRoot(),
            spin: attractRandom.next(in: -2...2), delay: 0))
      }
    } else if let store, !runPaused {
      store.advance(dt)
      let scale = store.timeScale
      if abs(world.speed - scale) > 0.001 {
        world.speed = scale
        physicsWorld.speed = scale
      }
      if let wave = store.nextWave(playfieldHeight: Double(size.height)) {
        store.launched()
        for spec in wave { launch(spec) }
      }
    }
    cullFallen()
  }

  private func launch(_ spec: LaunchSpec) {
    let node = SliceableNode(kind: spec.kind)
    let x = CGFloat(spec.xFraction) * size.width
    node.position = CGPoint(x: x, y: -CGFloat(spec.kind.radius) - 30)
    node.zRotation = CGFloat(attractRandom.next(in: 0...(2 * .pi)))
    node.alpha = 1
    let fire = SKAction.run { [weak self] in
      guard let self else { return }
      node.physicsBody?.velocity = CGVector(dx: spec.velocityX, dy: spec.velocityY)
      node.physicsBody?.angularVelocity = CGFloat(spec.spin)
      self.targets.append(node)
      self.world.addChild(node)
      if spec.kind == .flagship {
        self.addSparkle(to: node)
      }
    }
    launcher.run(.sequence([.wait(forDuration: spec.delay), fire]))
  }

  private func addSparkle(to node: SKNode) {
    let emitter = makeEmitter(
      color: ProceduralArt.gold, count: 0, speed: 20, lifetime: 0.7, scale: 0.35,
      texture: ProceduralArt.glowDotTexture)
    emitter.particleBirthRate = 26
    emitter.particlePositionRange = CGVector(dx: 60, dy: 60)
    emitter.yAcceleration = 0
    emitter.targetNode = world
    node.addChild(emitter)
  }

  private func cullFallen() {
    var remaining: [SliceableNode] = []
    for node in targets {
      if node.position.y < -CGFloat(node.kind.radius) - 140 {
        node.removeFromParent()
        if !isAttract { store?.miss(node.kind) }
      } else {
        remaining.append(node)
      }
    }
    targets = remaining
  }

  // MARK: - Touch and slicing

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard !runPaused, let touch = touches.first else { return }
    if let store, !isAttract, !store.session.isRunning { return }
    let point = touch.location(in: self)
    blade.begin(at: point, time: sceneTime)
    lastTouchPoint = point
    swipeActive = true
    if !isAttract { store?.beginSwipe() }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard swipeActive, !runPaused, let touch = touches.first else { return }
    let point = touch.location(in: self)
    blade.add(point, time: sceneTime)
    if let previous = lastTouchPoint {
      checkSlices(from: previous, to: point)
    }
    lastTouchPoint = point
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    finishSwipe()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    finishSwipe()
  }

  private func finishSwipe() {
    guard swipeActive else { return }
    swipeActive = false
    blade.end()
    guard !isAttract, let store else { return }
    let summary = store.endSwipe()
    if summary.isBinningBonus {
      let anchor = lastTouchPoint ?? CGPoint(x: size.width / 2, y: size.height / 2)
      showBinningBonus(summary, at: anchor)
    }
  }

  private func checkSlices(from a: CGPoint, to b: CGPoint) {
    let start = V2(x: a.x - world.position.x, y: a.y - world.position.y)
    let end = V2(x: b.x - world.position.x, y: b.y - world.position.y)
    for node in targets where node.parent != nil {
      let center = V2(x: node.position.x, y: node.position.y)
      if Geometry.segment(start, end, hitsCircleAt: center, radius: Double(node.kind.radius)) {
        slice(node, from: start, to: end)
      }
    }
  }

  private func slice(_ node: SliceableNode, from a: V2, to b: V2) {
    targets.removeAll { $0 === node }
    let center = V2(x: node.position.x, y: node.position.y)
    let rotation = Double(node.zRotation)
    func toLocal(_ p: V2) -> V2 {
      let d = p - center
      let c = cos(-rotation)
      let s = sin(-rotation)
      return V2(x: d.x * c - d.y * s, y: d.x * s + d.y * c)
    }
    var localA = toLocal(a)
    var localB = toLocal(b)
    var pieces = Geometry.split(polygon: node.silhouette, along: localA, localB)
    if pieces.left.isEmpty || pieces.right.isEmpty {
      // Grazing hit: cut through the middle along the swipe direction instead.
      let direction = (localB - localA).normalized
      localA = direction * -200
      localB = direction * 200
      pieces = Geometry.split(polygon: node.silhouette, along: localA, localB)
    }

    let result: HitResult?
    if isAttract {
      result = nil
    } else {
      result = store?.hit(node.kind)
      if result == nil { return }
    }

    let velocity = node.physicsBody?.velocity ?? .zero
    let angular = node.physicsBody?.angularVelocity ?? 0
    let direction = (localB - localA).normalized
    for polygon in [pieces.left, pieces.right] where !polygon.isEmpty {
      spawnPiece(
        from: node, polygon: polygon, direction: direction, velocity: velocity, angular: angular)
    }
    node.removeFromParent()

    let hitPoint = CGPoint(x: center.x, y: center.y)
    let swipeDirection = (b - a).normalized
    slashFlash(at: hitPoint, direction: swipeDirection, kind: node.kind)
    burst(at: hitPoint, kind: node.kind)

    guard let result else { return }
    switch node.kind {
    case .defective:
      redAlert(at: hitPoint, result: result)
    case .flagship:
      flagshipHit(at: hitPoint, result: result)
    default:
      let text = "+\(result.points)"
      popup(
        text, at: hitPoint,
        color: result.multiplier > 1 ? ProceduralArt.gold : ProceduralArt.nvGreenBright,
        size: 26 + CGFloat(min(result.swipeCount, 5)) * 3)
      if result.swipeCount >= 2 {
        popup(
          "×\(result.swipeCount)", at: CGPoint(x: hitPoint.x, y: hitPoint.y + 34),
          color: .white, size: 18)
      }
      shake(intensity: 2 + CGFloat(min(result.swipeCount, 4)), duration: 0.12)
    }
  }

  private func spawnPiece(
    from node: SliceableNode, polygon: [V2], direction: V2, velocity: CGVector, angular: CGFloat
  ) {
    guard let image = ProceduralArt.piece(of: node.baseImage, polygon: polygon) else { return }
    let centroid = Geometry.centroid(of: polygon)
    let piece = SKSpriteNode(texture: SKTexture(image: image))
    piece.size = node.size
    piece.anchorPoint = CGPoint(
      x: 0.5 + CGFloat(centroid.x) / node.size.width,
      y: 0.5 + CGFloat(centroid.y) / node.size.height)
    let c = cos(node.zRotation)
    let s = sin(node.zRotation)
    let offset = CGPoint(
      x: CGFloat(centroid.x) * c - CGFloat(centroid.y) * s,
      y: CGFloat(centroid.x) * s + CGFloat(centroid.y) * c)
    piece.position = CGPoint(x: node.position.x + offset.x, y: node.position.y + offset.y)
    piece.zRotation = node.zRotation
    piece.zPosition = 9
    let area = Geometry.area(of: polygon)
    let body = SKPhysicsBody(circleOfRadius: max(6, CGFloat((area / .pi).squareRoot()) * 0.7))
    body.collisionBitMask = 0
    body.contactTestBitMask = 0
    body.categoryBitMask = 0
    body.linearDamping = 0.1
    piece.physicsBody = body
    // Push the halves apart, perpendicular to the cut, in world space.
    let side: Double = direction.cross(centroid) >= 0 ? 1 : -1
    var normal = direction.perpendicular * side
    normal = V2(
      x: normal.x * Double(c) - normal.y * Double(s), y: normal.x * Double(s) + normal.y * Double(c)
    )
    let push = 150.0 + Double(attractRandom.next(in: 0...80))
    body.velocity = CGVector(
      dx: velocity.dx * 0.8 + normal.x * push, dy: velocity.dy * 0.6 + normal.y * push + 60)
    body.angularVelocity = angular + CGFloat(attractRandom.next(in: -4...4)) * CGFloat(side)
    world.addChild(piece)
    piece.run(
      .sequence([
        .wait(forDuration: 0.9), .fadeOut(withDuration: 0.5), .removeFromParent(),
      ]))
  }

  // MARK: - Effects

  private func makeEmitter(
    color: UIColor, count: Int, speed: CGFloat, lifetime: CGFloat, scale: CGFloat,
    texture: SKTexture
  ) -> SKEmitterNode {
    let emitter = SKEmitterNode()
    emitter.particleTexture = texture
    emitter.particleBirthRate = CGFloat(count) * 20
    emitter.numParticlesToEmit = count
    emitter.particleLifetime = lifetime
    emitter.particleLifetimeRange = lifetime * 0.5
    emitter.particleSpeed = speed
    emitter.particleSpeedRange = speed * 0.7
    emitter.emissionAngleRange = .pi * 2
    emitter.particleAlpha = 1
    emitter.particleAlphaSpeed = -1 / lifetime
    emitter.particleScale = scale
    emitter.particleScaleRange = scale * 0.5
    emitter.particleScaleSpeed = -scale / lifetime
    emitter.particleColor = color
    emitter.particleColorBlendFactor = 1
    emitter.particleBlendMode = .add
    emitter.yAcceleration = -500
    emitter.particleRotationRange = .pi
    emitter.particleRotationSpeed = 4
    return emitter
  }

  private func burst(at point: CGPoint, kind: SliceableKind) {
    let reduce = store?.reduceEffects ?? false
    let (color, secondary, count): (UIColor, UIColor, Int) = {
      switch kind {
      case .defective: return (ProceduralArt.defectiveRed, UIColor(white: 0.3, alpha: 1), 34)
      case .flagship: return (ProceduralArt.gold, .white, 60)
      case .heatsink: return (ProceduralArt.aluminum, ProceduralArt.copper, 26)
      case .chiplet: return (ProceduralArt.gold, ProceduralArt.nvGreenBright, 24)
      case .wafer: return (ProceduralArt.nvGreenBright, ProceduralArt.siliconLight, 28)
      }
    }()
    let scaled = reduce ? count / 3 : count
    let shards = makeEmitter(
      color: color, count: scaled, speed: 320, lifetime: 0.7, scale: 0.9,
      texture: ProceduralArt.sparkTexture)
    shards.position = point
    shards.zPosition = 30
    let dust = makeEmitter(
      color: secondary, count: scaled / 2, speed: 140, lifetime: 0.9, scale: 1.4,
      texture: ProceduralArt.glowDotTexture)
    dust.position = point
    dust.zPosition = 29
    dust.yAcceleration = -120
    for emitter in [shards, dust] {
      world.addChild(emitter)
      emitter.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))
    }
  }

  private func slashFlash(at point: CGPoint, direction: V2, kind: SliceableKind) {
    let length = CGFloat(kind.radius) * 2.6
    let path = CGMutablePath()
    path.move(
      to: CGPoint(
        x: point.x - CGFloat(direction.x) * length / 2,
        y: point.y - CGFloat(direction.y) * length / 2))
    path.addLine(
      to: CGPoint(
        x: point.x + CGFloat(direction.x) * length / 2,
        y: point.y + CGFloat(direction.y) * length / 2))
    let flash = SKShapeNode(path: path)
    flash.strokeColor = kind == .defective ? ProceduralArt.defectiveRed : .white
    flash.lineWidth = 3
    flash.glowWidth = 10
    flash.blendMode = .add
    flash.zPosition = 35
    flash.lineCap = .round
    world.addChild(flash)
    flash.run(
      .sequence([
        .group([.fadeOut(withDuration: 0.18), .scaleX(to: 1.3, duration: 0.18)]),
        .removeFromParent(),
      ]))
  }

  private func popup(_ text: String, at point: CGPoint, color: UIColor, size: CGFloat) {
    let label = SKLabelNode(fontNamed: labelFont)
    label.text = text
    label.fontSize = size
    label.fontColor = color
    label.position = point
    label.zPosition = 70
    label.setScale(0.4)
    let shadow = SKLabelNode(fontNamed: labelFont)
    shadow.text = text
    shadow.fontSize = size
    shadow.fontColor = UIColor.black.withAlphaComponent(0.7)
    shadow.position = CGPoint(x: 2, y: -2)
    shadow.zPosition = -1
    label.addChild(shadow)
    effects.addChild(label)
    label.run(
      .sequence([
        .group([
          .scale(to: 1.15, duration: 0.12),
          .moveBy(x: 0, y: 30, duration: 0.5),
        ]),
        .group([
          .scale(to: 0.9, duration: 0.4),
          .moveBy(x: 0, y: 40, duration: 0.4),
          .fadeOut(withDuration: 0.4),
        ]),
        .removeFromParent(),
      ]))
  }

  private func flashText(_ text: String, color: UIColor, size: CGFloat, duration: Double) {
    let label = SKLabelNode(fontNamed: labelFont)
    label.text = text
    label.fontSize = size
    label.fontColor = color
    label.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.56)
    label.zPosition = 75
    label.alpha = 0
    label.setScale(0.7)
    effects.addChild(label)
    label.run(
      .sequence([
        .group([.fadeIn(withDuration: 0.15), .scale(to: 1.05, duration: 0.2)]),
        .wait(forDuration: duration - 0.5),
        .group([.fadeOut(withDuration: 0.35), .scale(to: 1.4, duration: 0.35)]),
        .removeFromParent(),
      ]))
  }

  private func showBinningBonus(_ summary: SwipeSummary, at point: CGPoint) {
    let clamped = CGPoint(
      x: min(size.width - 110, max(110, point.x)), y: min(size.height - 160, max(120, point.y)))
    popup("BINNING BONUS", at: CGPoint(x: clamped.x, y: clamped.y + 26), color: .white, size: 24)
    popup("+\(summary.binningBonus)", at: clamped, color: ProceduralArt.nvGreenBright, size: 40)
    let line = SKShapeNode(
      rectOf: CGSize(width: 170, height: 3), cornerRadius: 1.5)
    line.fillColor = ProceduralArt.nvGreen
    line.strokeColor = .clear
    line.glowWidth = 6
    line.position = CGPoint(x: clamped.x, y: clamped.y + 12)
    line.zPosition = 69
    effects.addChild(line)
    line.run(
      .sequence([.scaleX(to: 1.6, duration: 0.3), .fadeOut(withDuration: 0.3), .removeFromParent()])
    )
    shake(intensity: 7, duration: 0.2)
  }

  private func redAlert(at point: CGPoint, result: HitResult) {
    popup(
      result.lostLife ? "DEFECTIVE DIE  -1 LIFE" : "DEFECTIVE DIE", at: point,
      color: ProceduralArt.defectiveRed, size: 24)
    shake(intensity: 16, duration: 0.45)
    let flash = SKSpriteNode(color: ProceduralArt.defectiveRed, size: size)
    flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
    flash.alpha = 0
    flash.zPosition = 45
    flash.blendMode = .add
    addChild(flash)
    flash.run(
      .sequence([
        .fadeAlpha(to: 0.45, duration: 0.05), .fadeOut(withDuration: 0.45), .removeFromParent(),
      ]))
    if result.lostLife && !(store?.session.isOver ?? true) {
      flashText("YIELD LOSS", color: ProceduralArt.defectiveRed, size: 30, duration: 0.9)
    }
  }

  private func flagshipHit(at point: CGPoint, result: HitResult) {
    popup("+\(result.points)", at: point, color: ProceduralArt.gold, size: 40)
    flashText("FLAGSHIP DIE  ·  DLSS 2×", color: ProceduralArt.gold, size: 30, duration: 1.4)
    if result.refundedLife {
      popup(
        "+1 LIFE", at: CGPoint(x: point.x, y: point.y - 36), color: ProceduralArt.nvGreenBright,
        size: 22)
    }
    shake(intensity: 10, duration: 0.3)
    slowMoVignette?.removeAllActions()
    slowMoTint?.removeAllActions()
    slowMoVignette?.run(.fadeAlpha(to: 1, duration: 0.2))
    slowMoTint?.run(.fadeAlpha(to: 0.09, duration: 0.2))
    let ring = SKShapeNode(circleOfRadius: 20)
    ring.strokeColor = ProceduralArt.gold
    ring.lineWidth = 5
    ring.glowWidth = 12
    ring.fillColor = .clear
    ring.position = point
    ring.zPosition = 36
    ring.blendMode = .add
    addChild(ring)
    ring.run(
      .sequence([
        .group([.scale(to: 14, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent(),
      ]))
  }

  func slowMoEnded() {
    slowMoVignette?.run(.fadeOut(withDuration: 0.35))
    slowMoTint?.run(.fadeOut(withDuration: 0.35))
  }

  private func shake(intensity: CGFloat, duration: Double) {
    if store?.reduceEffects == true { return }
    world.removeAction(forKey: "shake")
    world.position = .zero
    var actions: [SKAction] = []
    let steps = max(3, Int(duration / 0.03))
    for step in 0..<steps {
      let falloff = 1 - CGFloat(step) / CGFloat(steps)
      let dx = CGFloat(attractRandom.next(in: -1...1)) * intensity * falloff
      let dy = CGFloat(attractRandom.next(in: -1...1)) * intensity * falloff
      actions.append(.move(to: CGPoint(x: dx, y: dy), duration: 0.03))
    }
    actions.append(.move(to: .zero, duration: 0.03))
    world.run(.sequence(actions), withKey: "shake")
  }
}
