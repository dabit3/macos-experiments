import SpriteKit

/// Neon blade streak that follows the finger. Rebuilt every frame from the
/// recent touch samples as a tapered polygon: bright white core over a wide
/// green glow, thickest at the fingertip and vanishing at the tail.
final class BladeTrail {
  private struct Sample {
    var point: CGPoint
    var time: TimeInterval
  }

  private var samples: [Sample] = []
  private let maxAge: TimeInterval = 0.17
  let node = SKNode()
  private let glow = SKShapeNode()
  private let core = SKShapeNode()
  private let tip = SKSpriteNode(texture: ProceduralArt.glowDotTexture)

  init() {
    glow.fillColor = UIColor(red: 0.463, green: 0.725, blue: 0, alpha: 0.55)
    glow.strokeColor = UIColor(red: 0.62, green: 0.9, blue: 0.2, alpha: 0.35)
    glow.lineWidth = 2
    glow.glowWidth = 6
    glow.blendMode = .add
    core.fillColor = UIColor(red: 0.96, green: 1, blue: 0.92, alpha: 0.95)
    core.strokeColor = .clear
    core.lineWidth = 0
    tip.color = UIColor(red: 0.8, green: 1, blue: 0.5, alpha: 1)
    tip.colorBlendFactor = 1
    tip.size = CGSize(width: 34, height: 34)
    tip.blendMode = .add
    tip.isHidden = true
    node.zPosition = 80
    node.addChild(glow)
    node.addChild(core)
    node.addChild(tip)
  }

  func begin(at point: CGPoint, time: TimeInterval) {
    samples = [Sample(point: point, time: time)]
    tip.position = point
    tip.isHidden = false
  }

  func add(_ point: CGPoint, time: TimeInterval) {
    if let last = samples.last, hypot(last.point.x - point.x, last.point.y - point.y) < 1.5 {
      samples[samples.count - 1].time = time
      return
    }
    samples.append(Sample(point: point, time: time))
    tip.position = point
  }

  func end() {
    tip.isHidden = true
  }

  func update(time: TimeInterval) {
    samples.removeAll { time - $0.time > maxAge }
    if samples.count > 28 { samples.removeFirst(samples.count - 28) }
    guard samples.count >= 2 else {
      glow.path = nil
      core.path = nil
      return
    }
    glow.path = ribbon(maxWidth: 15, time: time)
    core.path = ribbon(maxWidth: 4.5, time: time)
  }

  private func ribbon(maxWidth: CGFloat, time: TimeInterval) -> CGPath {
    var left: [CGPoint] = []
    var right: [CGPoint] = []
    let count = samples.count
    for index in 0..<count {
      let sample = samples[index]
      let previous = samples[max(0, index - 1)].point
      let next = samples[min(count - 1, index + 1)].point
      var dx = next.x - previous.x
      var dy = next.y - previous.y
      let length = max(0.001, hypot(dx, dy))
      dx /= length
      dy /= length
      let age = CGFloat(min(1, max(0, (time - sample.time) / maxAge)))
      let position = CGFloat(index) / CGFloat(count - 1)
      let width = maxWidth * (1 - age) * (0.15 + 0.85 * position)
      left.append(CGPoint(x: sample.point.x - dy * width, y: sample.point.y + dx * width))
      right.append(CGPoint(x: sample.point.x + dy * width, y: sample.point.y - dx * width))
    }
    let path = CGMutablePath()
    path.move(to: left[0])
    for point in left.dropFirst() { path.addLine(to: point) }
    for point in right.reversed() { path.addLine(to: point) }
    path.closeSubpath()
    return path
  }
}
