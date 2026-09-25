import AVFoundation
import SpriteKit
import UIKit

@MainActor
final class HighwayScene: SKScene {
  weak var session: Session?
  private let moving = SKNode()
  private let effects = SKNode()
  private var fingers: [String: CGPoint] = [:]
  private var autoStarted: Set<Int> = []
  private var autoEnded: Set<Int> = []
  private var lastJudgment = ""
  private var lastSize = CGSize.zero
  private var beatGlow: SKShapeNode?
  private var feedback: AVAudioPlayer?
  private var lastFeedbackTime = 0.0
  private var judgmentLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
  private var comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
  private var comboTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
  private var lastCombo = -1
  private var countdown = SKLabelNode(fontNamed: "AvenirNext-Heavy")
  private let gold = UIColor(red: 1, green: 0.79, blue: 0.22, alpha: 1)
  private let cyan = UIColor(red: 0.22, green: 0.94, blue: 1, alpha: 1)

  override func didMove(to view: SKView) {
    view.isMultipleTouchEnabled = true
    backgroundColor = UIColor(red: 0.035, green: 0.035, blue: 0.075, alpha: 1)
    scaleMode = .resizeFill
    if let url = Bundle.main.url(forResource: "hit", withExtension: "wav") {
      feedback = try? AVAudioPlayer(contentsOf: url)
      feedback?.volume = 0.2
      feedback?.prepareToPlay()
    }
    buildStage()
  }

  private var hitY: CGFloat { size.height * 0.14 }
  private var horizon: CGFloat { size.height * 0.82 }
  private var center: CGFloat { size.width * 0.625 }
  private var bottomWidth: CGFloat { size.width * 0.70 }
  private var topWidth: CGFloat { size.width * 0.19 }
  private func point(_ lane: Double, _ progress: Double) -> CGPoint {
    let p = CGFloat(progress)
    let depth = p * p
    let width = topWidth + (bottomWidth - topWidth) * depth
    return CGPoint(
      x: center + (CGFloat(lane) / 16 - 0.5) * width,
      y: horizon - (horizon - hitY) * depth)
  }

  private func polygon(
    _ points: [CGPoint], fill: UIColor, stroke: UIColor = .clear, width: CGFloat = 1
  ) -> SKShapeNode {
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    let node = SKShapeNode(path: path)
    node.fillColor = fill
    node.strokeColor = stroke
    node.lineWidth = width
    return node
  }

  private func line(_ a: CGPoint, _ b: CGPoint, color: UIColor, width: CGFloat = 1) -> SKShapeNode {
    let path = CGMutablePath()
    path.move(to: a)
    path.addLine(to: b)
    let node = SKShapeNode(path: path)
    node.strokeColor = color
    node.lineWidth = width
    return node
  }

  private func buildStage() {
    removeAllChildren()
    lastSize = size
    lastCombo = -1
    let w = size.width
    let h = size.height
    for i in 0..<100 {
      let dot = SKShapeNode(circleOfRadius: i % 7 == 0 ? 1.5 : 0.6)
      dot.fillColor = i % 3 == 0 ? gold : cyan
      dot.strokeColor = .clear
      dot.alpha = 0.3 + CGFloat(i % 5) / 10
      dot.position = CGPoint(
        x: CGFloat((i * 97) % 1280) / 1280 * w,
        y: CGFloat((i * 173) % 800) / 800 * h)
      addChild(dot)
    }
    let art = SKSpriteNode(imageNamed: "aria")
    art.size = CGSize(width: h * 0.667, height: h)
    art.position = CGPoint(x: w * 0.12, y: h * 0.46)
    art.alpha = 0.82
    addChild(art)
    let edge = polygon(
      [
        CGPoint(x: w * 0.28, y: 0), CGPoint(x: w * 0.28, y: h),
        CGPoint(x: w * 0.38, y: h), CGPoint(x: w * 0.31, y: 0),
      ],
      fill: UIColor.black.withAlphaComponent(0.5))
    addChild(edge)
    for i in 0..<18 {
      let x = w * 0.3 + CGFloat(i) * w * 0.043
      let buildingHeight = h * (0.1 + CGFloat((i * 13) % 9) / 35)
      let rect = SKShapeNode(
        rect: CGRect(x: x, y: h * 0.5, width: w * 0.035, height: buildingHeight))
      rect.fillColor = UIColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 1)
      rect.strokeColor = gold.withAlphaComponent(0.25)
      addChild(rect)
      for floor in 0..<8 {
        let light = line(
          CGPoint(x: x + 3, y: h * 0.52 + CGFloat(floor) * buildingHeight / 9),
          CGPoint(x: x + w * 0.029, y: h * 0.52 + CGFloat(floor) * buildingHeight / 9),
          color: (i % 2 == 0 ? cyan : gold).withAlphaComponent(0.25))
        addChild(light)
      }
    }
    let field = polygon(
      [point(0, 0), point(16, 0), point(16, 1.07), point(0, 1.07)],
      fill: UIColor(red: 0.025, green: 0.028, blue: 0.052, alpha: 0.98),
      stroke: gold.withAlphaComponent(0.6), width: 2)
    addChild(field)
    for lane in 0...16 {
      addChild(
        line(
          point(Double(lane), 0), point(Double(lane), 1.055),
          color: cyan.withAlphaComponent(lane % 4 == 0 ? 0.35 : 0.10)))
    }
    for side in [0.0, 16.0] {
      let rail = line(point(side, 0), point(side, 1.05), color: cyan, width: 2.5)
      rail.glowWidth = 4
      addChild(rail)
      for i in 0..<36 {
        let p = Double(i) / 35
        let loc = point(side == 0 ? -0.2 : 16.2, p)
        let dot = SKShapeNode(circleOfRadius: 1 + p * 1.3)
        dot.position = loc
        dot.fillColor = i % 2 == 0 ? .white : cyan
        dot.strokeColor = .clear
        addChild(dot)
      }
    }
    let strike = line(point(0, 1), point(16, 1), color: gold, width: 6)
    strike.glowWidth = 12
    addChild(strike)
    beatGlow = strike
    for lane in 0..<16 {
      let x = point(Double(lane), 1).x
      let key = SKShapeNode(
        rect: CGRect(
          x: x + 1, y: hitY - h * 0.081,
          width: bottomWidth / 16 - 2, height: h * 0.073), cornerRadius: 2)
      key.fillColor =
        lane % 2 == 0 ? UIColor(white: 0.94, alpha: 1) : UIColor(white: 0.72, alpha: 1)
      key.strokeColor = gold
      key.lineWidth = 1
      addChild(key)
      if lane % 2 == 0 {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = String(format: "%02d", lane + 1)
        label.fontSize = h * 0.012
        label.fontColor = .darkGray
        label.position = CGPoint(x: x + bottomWidth / 16, y: hitY - h * 0.068)
        addChild(label)
      }
    }
    moving.zPosition = 10
    effects.zPosition = 20
    addChild(moving)
    addChild(effects)
    comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    comboLabel.fontSize = h * 0.11
    comboLabel.fontColor = .white
    comboLabel.alpha = 0.9
    comboLabel.position = CGPoint(x: center, y: h * 0.45)
    comboLabel.zPosition = 30
    addChild(comboLabel)
    comboTitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    comboTitle.text = "C O M B O"
    comboTitle.fontSize = h * 0.018
    comboTitle.fontColor = gold
    comboTitle.position = CGPoint(x: center, y: h * 0.56)
    comboTitle.zPosition = 30
    addChild(comboTitle)
    judgmentLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    judgmentLabel.fontSize = h * 0.034
    judgmentLabel.position = CGPoint(x: center, y: h * 0.34)
    judgmentLabel.zPosition = 31
    addChild(judgmentLabel)
    countdown = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    countdown.fontSize = h * 0.09
    countdown.fontColor = gold
    countdown.position = CGPoint(x: center, y: h * 0.62)
    countdown.zPosition = 35
    addChild(countdown)
  }

  func resetRound() {
    autoStarted.removeAll()
    autoEnded.removeAll()
    lastJudgment = ""
    lastCombo = -1
    fingers.removeAll()
    effects.removeAllChildren()
  }

  func pulse(lane: Double) {
    let p = point(lane, 1)
    let flash = SKShapeNode(rectOf: CGSize(width: bottomWidth / 12, height: 14), cornerRadius: 4)
    flash.position = p
    flash.fillColor = .white
    flash.strokeColor = cyan
    flash.glowWidth = 10
    effects.addChild(flash)
    flash.run(
      .sequence([
        .group([.fadeOut(withDuration: 0.25), .scale(to: 1.7, duration: 0.25)]),
        .removeFromParent(),
      ]))
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastFeedbackTime > 0.06 {
      feedback?.currentTime = 0
      feedback?.play()
      lastFeedbackTime = now
    }
  }

  override func update(_ currentTime: TimeInterval) {
    guard let session, let chart = session.chart else { return }
    if size != lastSize { buildStage() }
    let time = session.songTime
    beatGlow?.alpha =
      0.7 + 0.3
      * CGFloat(pow(max(0, 1 - (time * chart.bpm / 60).truncatingRemainder(dividingBy: 1)), 3))
    moving.removeAllChildren()
    for beat in 0..<10 {
      let beatTime = (floor(time * chart.bpm / 60) + Double(beat)) * 60 / chart.bpm
      let progress = 1 - (beatTime - time) / 2.8
      if progress >= 0 && progress <= 1 {
        moving.addChild(
          line(point(0, progress), point(16, progress), color: .white.withAlphaComponent(0.13)))
      }
    }
    for note in chart.notes {
      let headProgress = 1 - (note.time - time) / 2.8
      let tailProgress = 1 - (note.time + note.duration - time) / 2.8
      guard headProgress >= 0, tailProgress <= 1.05 else { continue }
      let color: UIColor
      switch note.kind {
      case "hold": color = gold
      case "slide": color = cyan
      case "air": color = .green
      default: color = UIColor(red: 1, green: 0.16, blue: 0.33, alpha: 1)
      }
      if note.duration > 0 {
        let start = max(time, note.time)
        let end = min(time + 2.8, note.time + note.duration)
        if start < end {
          var left: [CGPoint] = []
          var right: [CGPoint] = []
          for i in 0...20 {
            let t = start + (end - start) * Double(i) / 20
            let progress = 1 - (t - time) / 2.8
            let fraction = (t - note.time) / note.duration
            let lane = note.lane + (note.endLane - note.lane) * fraction
            left.append(point(lane, progress))
            right.append(point(lane + note.width, progress))
          }
          let trail = polygon(
            left + right.reversed(), fill: color.withAlphaComponent(0.38), stroke: color, width: 1.8
          )
          trail.glowWidth = 3
          moving.addChild(trail)
        }
      }
      guard headProgress <= 1.035 else { continue }
      let left = point(note.lane, headProgress)
      let right = point(note.lane + note.width, headProgress)
      let height = 4 + 12 * CGFloat(headProgress * headProgress)
      let cap = SKShapeNode(
        rect: CGRect(x: left.x, y: left.y - height / 2, width: right.x - left.x, height: height),
        cornerRadius: 3)
      cap.fillColor = color
      cap.strokeColor = .white
      cap.lineWidth = 1.5
      cap.glowWidth = 3
      moving.addChild(cap)
      moving.addChild(
        line(
          CGPoint(x: left.x + 3, y: left.y + height / 4),
          CGPoint(x: right.x - 3, y: right.y + height / 4), color: .white.withAlphaComponent(0.8),
          width: 2))
      if note.kind == "air" {
        let middle = (left.x + right.x) / 2
        let arrowHeight = max(14, (right.x - left.x) * 0.35)
        let arrow = polygon(
          [
            CGPoint(x: left.x, y: left.y + height),
            CGPoint(x: middle, y: left.y + arrowHeight + height),
            CGPoint(x: right.x, y: left.y + height), CGPoint(x: right.x, y: left.y + height - 10),
            CGPoint(x: middle, y: left.y + arrowHeight + height - 10),
            CGPoint(x: left.x, y: left.y + height - 10),
          ], fill: .green, stroke: .white, width: 1.5)
        arrow.glowWidth = 4
        moving.addChild(arrow)
      }
    }
    let combo = session.me?.combo ?? 0
    if combo != lastCombo {
      lastCombo = combo
      comboLabel.text = combo > 0 ? "\(combo)" : ""
      comboTitle.isHidden = combo == 0
      comboLabel.fontColor = combo >= 50 ? gold : .white
      if combo > 0 {
        comboLabel.removeAllActions()
        comboLabel.setScale(1.18)
        comboLabel.run(.scale(to: 1, duration: 0.12))
      }
    }
    if time < 0 {
      countdown.text = time < -0.7 ? "\(Int(ceil(-time)))" : "READY"
    } else {
      countdown.text = time < 0.65 ? "FLY!" : ""
    }
    if let last = session.me?.last, last.id != lastJudgment {
      lastJudgment = last.id
      judgmentLabel.text =
        last.judgment == "critical" ? "JUSTICE CRITICAL" : last.judgment.uppercased()
      switch last.judgment {
      case "critical": judgmentLabel.fontColor = gold
      case "justice": judgmentLabel.fontColor = .yellow
      case "attack": judgmentLabel.fontColor = cyan
      default: judgmentLabel.fontColor = UIColor(red: 1, green: 0.30, blue: 0.42, alpha: 1)
      }
      judgmentLabel.removeAllActions()
      judgmentLabel.alpha = 1
      judgmentLabel.run(.sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.35)]))
      if last.judgment != "miss" {
        for index in 0..<7 {
          let spark = SKShapeNode(circleOfRadius: CGFloat(2 + index % 3))
          spark.position = point(last.lane + last.width / 2, 1)
          spark.fillColor = index % 2 == 0 ? gold : .white
          spark.strokeColor = .clear
          spark.glowWidth = 2
          effects.addChild(spark)
          spark.run(
            .sequence([
              .group([
                .moveBy(x: CGFloat(index - 3) * 13, y: CGFloat(40 + index * 7), duration: 0.35),
                .fadeOut(withDuration: 0.35),
              ]), .removeFromParent(),
            ]))
        }
      }
    }
    if session.demo { driveAutomation(time: time, chart: chart, session: session) }
    for (id, position) in fingers {
      session.touch(pointer: id, action: "move", x: Double(position.x), y: Double(position.y))
    }
  }

  private func driveAutomation(time: Double, chart: Chart, session: Session) {
    guard session.state?.phase == "playing", time >= 0 else { return }
    let delay = Launch.value("driver-delay").flatMap(Double.init) ?? 0
    for note in chart.notes {
      let elapsed = time - note.time - delay
      let id = "auto-\(note.id)"
      if elapsed >= (note.kind == "air" ? -0.055 : 0) && !autoStarted.contains(note.id) {
        autoStarted.insert(note.id)
        session.touch(pointer: id, action: "down", x: note.lane + note.width / 2, y: 0.9)
      }
      guard autoStarted.contains(note.id), !autoEnded.contains(note.id) else { continue }
      if note.kind == "air" {
        if elapsed >= 0 {
          session.touch(pointer: id, action: "move", x: note.lane + note.width / 2, y: 0.65)
          session.touch(pointer: id, action: "up", x: note.lane + note.width / 2, y: 0.65)
          autoEnded.insert(note.id)
        }
      } else if note.duration > 0 && elapsed <= note.duration + 0.03 {
        let fraction = min(1, max(0, elapsed / note.duration))
        let x = note.lane + (note.endLane - note.lane) * fraction + note.width / 2
        session.touch(pointer: id, action: "move", x: x, y: 0.9)
      } else {
        session.touch(pointer: id, action: "up", x: note.endLane + note.width / 2, y: 0.9)
        autoEnded.insert(note.id)
      }
    }
  }

  private func coordinate(_ touch: UITouch) -> CGPoint {
    let location = touch.location(in: self)
    let lane = (location.x - (center - bottomWidth / 2)) / bottomWidth * 16
    return CGPoint(x: min(16, max(0, lane)), y: 1 - location.y / size.height)
  }
  private func identifier(_ touch: UITouch) -> String {
    "touch-\(ObjectIdentifier(touch).hashValue)"
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      let point = coordinate(touch)
      guard point.y > 0.72 else { continue }
      let id = identifier(touch)
      fingers[id] = point
      session?.touch(pointer: id, action: "down", x: Double(point.x), y: Double(point.y))
      print("EVIDENCE manual down lane=\(point.x)")
    }
  }
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      let id = identifier(touch)
      guard fingers[id] != nil else { continue }
      let point = coordinate(touch)
      fingers[id] = point
      session?.touch(pointer: id, action: "move", x: Double(point.x), y: Double(point.y))
    }
  }
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    release(touches)
  }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    release(touches)
  }
  private func release(_ touches: Set<UITouch>) {
    for touch in touches {
      let id = identifier(touch)
      guard let point = fingers.removeValue(forKey: id) else { continue }
      session?.touch(pointer: id, action: "up", x: Double(point.x), y: Double(point.y))
    }
  }
}
