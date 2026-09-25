import SpriteKit
import SwiftUI
import UIKit

extension UIColor {
    static let orbitPink = UIColor(red: 1, green: 0.22, blue: 0.68, alpha: 1)
    static let orbitCyan = UIColor(red: 0.24, green: 0.96, blue: 1, alpha: 1)
    static let orbitGold = UIColor(red: 1, green: 0.88, blue: 0.30, alpha: 1)
    static let orbitInk = UIColor(red: 0.055, green: 0.045, blue: 0.16, alpha: 1)
}

@MainActor
final class OrbitScene: SKScene {
    private struct NoteVisual {
        let root: SKNode
        let head: SKShapeNode
        let route: SKShapeNode?
        let arrows: [(segment: Int, node: SKShapeNode)]
        let follower: SKShapeNode?
        let holdBody: SKShapeNode?
        let holdCore: SKShapeNode?
        var active = false
        var checkpoint = 0
    }

    weak var client: GameClient?
    private let dynamicLayer = SKNode()
    private let art = SKNode()
    private let effectLayer = SKNode()
    private var noteVisuals: [Int: NoteVisual] = [:]
    private var eachLinks: [Double: SKShapeNode] = [:]
    private var targetNodes: [SKShapeNode] = []
    private var panelNodes: [SKShapeNode] = []
    private var lastMilestone = 0
    private var milestoneMatch = -1
    private var artSprite: SKSpriteNode?
    private var lastJudgment = ""
    private var touches: [UITouch: Int] = [:]
    private var pointer = 0
    private var automatedSteps: [Int: Int] = [:]
    private var automatedMatch = -1
    private var nextDriverFrame = 0.0
    private var lastTouchMove: [Int: Double] = [:]
    private var stageReady = false
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    private var unit: CGFloat { min(size.width, size.height) / 2 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        buildStage()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        if view != nil { buildStage() }
    }

    private func circle(_ radius: CGFloat, color: UIColor, width: CGFloat, fill: UIColor = .clear) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.strokeColor = color
        node.lineWidth = width
        node.fillColor = fill
        return node
    }

    private func buildStage() {
        removeAllChildren()
        targetNodes.removeAll()
        panelNodes.removeAll()
        art.removeAllChildren()
        dynamicLayer.removeAllChildren()
        noteVisuals.removeAll()
        eachLinks.removeAll()
        effectLayer.removeAllChildren()
        let base = circle(unit * 0.98, color: .orbitPink.withAlphaComponent(0.35), width: 2, fill: .orbitInk)
        base.position = center
        base.glowWidth = 9
        addChild(base)
        art.position = center
        addChild(art)
        let crop = SKCropNode()
        crop.maskNode = circle(unit * 0.70, color: .white, width: 0, fill: .white)
        let image = SKSpriteNode(imageNamed: "cosmic-bunny")
        image.size = CGSize(width: unit * 1.48, height: unit * 1.48)
        image.alpha = 0.64
        crop.addChild(image)
        art.addChild(crop)
        artSprite = image
        let shade = circle(unit * 0.70, color: .orbitCyan.withAlphaComponent(0.25), width: 1,
                           fill: .orbitInk.withAlphaComponent(0.18))
        art.addChild(shade)
        for ring in [0.31, 0.60, 0.76, 0.825] {
            let node = circle(unit * ring, color: UIColor.orbitCyan.withAlphaComponent(ring == 0.825 ? 0.9 : 0.15),
                              width: ring == 0.825 ? 2 : 1)
            node.position = center
            addChild(node)
        }
        for i in 0..<64 {
            let angle = CGFloat(i) * .pi / 32
            let spark = circle(i % 8 == 0 ? 2 : 1, color: .clear, width: 0,
                               fill: i % 2 == 0 ? .orbitPink : .orbitCyan)
            spark.position = CGPoint(x: center.x + cos(angle) * unit * 0.745, y: center.y + sin(angle) * unit * 0.745)
            addChild(spark)
        }
        for lane in 0..<8 {
            let angle = CGFloat.pi / 2 - (CGFloat(lane) + 0.5) * .pi / 4
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: unit * 0.94, startAngle: angle - .pi / 9.5,
                        endAngle: angle + .pi / 9.5, clockwise: false)
            path.addArc(center: .zero, radius: unit * 0.85, startAngle: angle + .pi / 9.5,
                        endAngle: angle - .pi / 9.5, clockwise: true)
            path.closeSubpath()
            let panel = SKShapeNode(path: path)
            panel.position = center
            panel.lineWidth = 1.5
            panel.strokeColor = lane % 2 == 0 ? .orbitPink : .orbitCyan
            panel.fillColor = UIColor(white: 0.94, alpha: 1)
            panel.glowWidth = 3
            addChild(panel)
            panelNodes.append(panel)
            let target = circle(unit * 0.054, color: .white, width: 2, fill: .orbitInk)
            target.position = position(Point.target(lane))
            target.glowWidth = 2
            addChild(target)
            targetNodes.append(target)
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "\(lane + 1)"
            label.fontSize = unit * 0.046
            label.fontColor = .orbitInk
            label.verticalAlignmentMode = .center
            label.position = position(Point.target(lane, radius: 0.903))
            addChild(label)
        }
        addChild(dynamicLayer)
        addChild(effectLayer)
        stageReady = true
    }

    private func position(_ point: Point) -> CGPoint {
        CGPoint(x: center.x + point.x * unit, y: center.y + point.y * unit)
    }

    private func normalized(_ point: CGPoint) -> Point {
        Point(x: (point.x - center.x) / unit, y: (point.y - center.y) / unit)
    }

    private func starPath(radius: CGFloat, points: Int = 5) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<(points * 2) {
            let angle = CGFloat(index) * .pi / CGFloat(points) + .pi / 2
            let r = index % 2 == 0 ? radius : radius * 0.47
            let p = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    override func update(_ currentTime: TimeInterval) {
        guard stageReady, let client else { return }
        let time = client.songTime
        let beat = Double(client.chart?.bpm ?? 128) / 60
        let pulse = CGFloat((sin(time * beat * .pi * 2) + 1) / 2)
        artSprite?.setScale(1 + pulse * 0.025)
        artSprite?.zRotation = sin(currentTime * 0.4) * 0.04
        targetNodes.forEach { $0.strokeColor = pulse > 0.8 ? .white : .orbitCyan }
        guard client.phase == "playing", let chart = client.chart else {
            dynamicLayer.removeAllChildren()
            noteVisuals.removeAll()
            eachLinks.removeAll()
            return
        }
        if !client.automation.isEmpty { driveAutomation(time: time, chart: chart) }
        let states = client.me?.notes ?? []
        let visible = chart.notes.filter { note in
            let state = note.id < states.count ? states[note.id].state : "pending"
            return state != "done" && time >= note.time - 1.7 && time <= note.time + note.duration + 0.35
        }
        let each = visible.filter { $0.kind == "each" }
        let visibleIDs = Set(visible.map(\.id))
        for id in noteVisuals.keys where !visibleIDs.contains(id) {
            noteVisuals.removeValue(forKey: id)?.root.removeFromParent()
        }
        let eachTimes = Set(each.map(\.time))
        for time in eachLinks.keys where !eachTimes.contains(time) {
            eachLinks.removeValue(forKey: time)?.removeFromParent()
        }
        for pair in stride(from: 0, to: max(0, each.count - 1), by: 2) where each[pair].time == each[pair + 1].time {
            let pairTime = each[pair].time
            let radius = max(0.09, min(0.82, 0.09 + (time - pairTime + 1.6) / 1.6 * 0.73))
            if eachLinks[pairTime] == nil {
                let link = circle(unit, color: .orbitGold.withAlphaComponent(0.5), width: 1)
                link.position = center
                dynamicLayer.addChild(link)
                eachLinks[pairTime] = link
            }
            eachLinks[pairTime]?.setScale(radius)
        }
        for note in visible {
            let state = note.id < states.count ? states[note.id] : nil
            drawNote(note, state: state, time: time)
        }
        if let judgment = client.me?.lastJudgment {
            let key = "\(client.snapshot?.matchID ?? 0)-\(judgment.id)-\(judgment.text)"
            if key != lastJudgment {
                lastJudgment = key
                showJudgment(judgment)
            }
        }
        showMilestone(combo: client.me?.combo ?? 0, match: client.snapshot?.matchID ?? 0)
    }

    private func showMilestone(combo: Int, match: Int) {
        if milestoneMatch != match {
            milestoneMatch = match
            lastMilestone = 0
        }
        if combo < lastMilestone { lastMilestone = 0 }
        let milestone = combo / 25 * 25
        guard milestone > lastMilestone else { return }
        lastMilestone = milestone
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "\(milestone) COMBO"
        label.fontSize = unit * 0.11
        label.fontColor = .orbitGold
        label.verticalAlignmentMode = .center
        label.position = center
        label.zPosition = 12
        label.setScale(0.4)
        label.alpha = 0
        effectLayer.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.18), .fadeIn(withDuration: 0.12)]),
            .scale(to: 1, duration: 0.1), .wait(forDuration: 0.4),
            .group([.scale(to: 1.4, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let ring = circle(unit * 0.3, color: .orbitGold, width: 3)
        ring.position = center
        ring.zPosition = 11
        effectLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 3.1, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
    }

    private func drawNote(_ note: Note, state: NoteState?, time: Double) {
        let active = state?.state == "active"
        if noteVisuals[note.id] == nil { noteVisuals[note.id] = makeNote(note) }
        guard var visual = noteVisuals[note.id] else { return }
        let radius = max(0.09, min(0.86, 0.09 + (time - note.time + 1.6) / 1.6 * 0.73))
        let head = position(Point.target(note.lane, radius: active ? 0.82 : radius))
        visual.head.position = head
        visual.head.isHidden = active && note.kind != "hold"
        if note.kind == "slide" {
            visual.head.zRotation = CGFloat(time * 2)
            visual.follower?.isHidden = time < note.time
            let progress = max(0, min(1, (time - note.time - 0.15) / (note.duration - 0.15)))
            visual.follower?.position = position(interpolate(note.path, progress: progress))
            visual.follower?.zRotation = CGFloat(time * 3)
        }
        if note.kind == "hold" {
            let tailRadius = max(0.09, min(0.82, 0.09 + (time - note.time - note.duration + 1.6) / 1.6 * 0.73))
            let path = CGMutablePath()
            path.move(to: position(Point.target(note.lane, radius: tailRadius)))
            path.addLine(to: head)
            visual.holdBody?.path = path
            visual.holdCore?.path = path
        }
        if visual.active != active {
            visual.active = active
            visual.route?.alpha = active ? 0.85 : 0.36
            visual.holdBody?.glowWidth = active ? 7 : 2
            visual.holdCore?.strokeColor = active ? .white : .orbitInk
        }
        let checkpoint = state?.checkpoint ?? 0
        if visual.checkpoint != checkpoint {
            visual.checkpoint = checkpoint
            for arrow in visual.arrows {
                arrow.node.strokeColor = arrow.segment < checkpoint ? .orbitGold : .orbitCyan
            }
        }
        noteVisuals[note.id] = visual
    }

    private func makeNote(_ note: Note) -> NoteVisual {
        let color: UIColor = note.kind == "slide" ? .orbitCyan :
            (note.kind == "each" || note.kind == "break" ? .orbitGold : .orbitPink)
        let root = SKNode()
        dynamicLayer.addChild(root)
        var route: SKShapeNode?
        var arrows: [(segment: Int, node: SKShapeNode)] = []
        var follower: SKShapeNode?
        var holdBody: SKShapeNode?
        var holdCore: SKShapeNode?
        if note.kind == "slide" {
            let path = CGMutablePath()
            for (index, p) in note.path.enumerated() {
                if index == 0 { path.move(to: position(p)) } else { path.addLine(to: position(p)) }
            }
            let line = SKShapeNode(path: path)
            line.strokeColor = color
            line.alpha = 0.36
            line.lineWidth = 7
            line.glowWidth = 3
            root.addChild(line)
            route = line
            for segment in 0..<(note.path.count - 1) {
                let start = position(note.path[segment])
                let end = position(note.path[segment + 1])
                for fraction in [0.25, 0.5, 0.75] {
                    let arrowPath = CGMutablePath()
                    arrowPath.move(to: CGPoint(x: -4, y: 6))
                    arrowPath.addLine(to: CGPoint(x: 2, y: 0))
                    arrowPath.addLine(to: CGPoint(x: -4, y: -6))
                    let arrow = SKShapeNode(path: arrowPath)
                    arrow.strokeColor = color
                    arrow.lineWidth = 2
                    arrow.position = CGPoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction)
                    arrow.zRotation = atan2(end.y - start.y, end.x - start.x)
                    root.addChild(arrow)
                    arrows.append((segment, arrow))
                }
            }
            let star = SKShapeNode(path: starPath(radius: 13))
            star.fillColor = .white
            star.strokeColor = .orbitCyan
            star.lineWidth = 3
            star.glowWidth = 4
            root.addChild(star)
            follower = star
        }
        if note.kind == "hold" {
            let body = SKShapeNode()
            body.strokeColor = color
            body.lineWidth = 17
            body.lineCap = .round
            body.glowWidth = 2
            root.addChild(body)
            holdBody = body
            let core = SKShapeNode()
            core.strokeColor = .orbitInk
            core.lineWidth = 8
            root.addChild(core)
            holdCore = core
        }
        let node = note.kind == "slide" ? SKShapeNode(path: starPath(radius: 14)) :
            circle(note.kind == "break" ? 13 : 11, color: color, width: 4, fill: .orbitInk.withAlphaComponent(0.8))
        node.strokeColor = color
        node.lineWidth = 4
        node.glowWidth = note.kind == "break" ? 6 : 3
        if note.kind == "slide" { node.fillColor = .orbitInk }
        root.addChild(node)
        if note.kind == "break" {
            let star = SKShapeNode(path: starPath(radius: 6))
            star.fillColor = .orbitGold
            star.strokeColor = .white
            node.addChild(star)
        }
        return NoteVisual(root: root, head: node, route: route, arrows: arrows, follower: follower, holdBody: holdBody, holdCore: holdCore)
    }

    private func interpolate(_ points: [Point], progress: Double) -> Point {
        let part = progress * Double(points.count - 1)
        let index = min(points.count - 2, Int(part))
        let fraction = part - Double(index)
        return Point(x: points[index].x + (points[index + 1].x - points[index].x) * fraction,
                     y: points[index].y + (points[index + 1].y - points[index].y) * fraction)
    }

    private static func gradeColor(_ text: String) -> UIColor {
        switch text {
        case "PERFECT": return .orbitGold
        case "GREAT": return .orbitCyan
        case "GOOD": return UIColor(red: 0.45, green: 1, blue: 0.75, alpha: 1)
        default: return .orbitPink
        }
    }

    private func showJudgment(_ judgment: Judgment) {
        let color = Self.gradeColor(judgment.text)
        let node = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        node.text = judgment.text
        node.fontSize = unit * 0.075
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.position = position(Point.target(judgment.lane, radius: 0.56))
        node.zPosition = 10
        node.setScale(0.5)
        let width = CGFloat(judgment.text.count) * node.fontSize * 0.72 + 22
        let plate = SKShapeNode(rectOf: CGSize(width: width, height: node.fontSize + 12), cornerRadius: (node.fontSize + 12) / 2)
        plate.fillColor = UIColor.orbitInk.withAlphaComponent(0.85)
        plate.strokeColor = color.withAlphaComponent(0.6)
        plate.lineWidth = 1
        plate.zPosition = -1
        node.addChild(plate)
        effectLayer.addChild(node)
        node.run(.sequence([.scale(to: 1.1, duration: 0.09), .scale(to: 1, duration: 0.07), .wait(forDuration: 0.25),
                            .group([.moveBy(x: 0, y: 10, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let target = position(Point.target(judgment.lane))
        if judgment.text == "MISS" {
            if judgment.lane < targetNodes.count {
                let node = targetNodes[judgment.lane]
                node.run(.sequence([.run { node.fillColor = .orbitPink }, .wait(forDuration: 0.18),
                                    .run { node.fillColor = .orbitInk }]))
            }
        } else {
            burst(at: target, color: color)
            let ring = circle(unit * 0.054, color: color, width: 3)
            ring.position = target
            ring.zPosition = 9
            effectLayer.addChild(ring)
            ring.run(.sequence([.group([.scale(to: 2.6, duration: 0.32), .fadeOut(withDuration: 0.32)]), .removeFromParent()]))
        }
    }

    private func flashLane(at point: Point) {
        let radius = hypot(point.x, point.y)
        guard radius > 0.6 else { return }
        var angle = Double.pi / 2 - atan2(point.y, point.x)
        if angle < 0 { angle += .pi * 2 }
        let lane = Int(angle / (.pi / 4)) % 8
        guard lane < panelNodes.count else { return }
        let panel = panelNodes[lane]
        let base = panel.strokeColor
        panel.removeAllActions()
        panel.fillColor = base
        panel.run(.sequence([.wait(forDuration: 0.08), .run { panel.fillColor = UIColor(white: 0.94, alpha: 1) }]))
    }

    private func burst(at point: CGPoint, color: UIColor) {
        for i in 0..<10 {
            let sparkle = SKShapeNode(path: starPath(radius: CGFloat(3 + i % 3), points: 4))
            sparkle.position = point
            sparkle.fillColor = i % 2 == 0 ? color : .white
            sparkle.strokeColor = .clear
            sparkle.glowWidth = 2
            effectLayer.addChild(sparkle)
            let angle = CGFloat(i) / 10 * .pi * 2
            sparkle.run(.sequence([.group([.moveBy(x: cos(angle) * 42, y: sin(angle) * 42, duration: 0.35),
                                          .fadeOut(withDuration: 0.4), .rotate(byAngle: 2, duration: 0.4)]), .removeFromParent()]))
        }
    }

    func handleInput(phase: String, pointer: Int, point: Point, source: String) {
        client?.input(phase: phase, pointer: pointer, point: point, source: source)
        if phase == "down" {
            flashLane(at: point)
            burst(at: position(point), color: .orbitCyan)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            pointer += 1
            self.touches[touch] = pointer
            handleInput(phase: "down", pointer: pointer, point: normalized(touch.location(in: self)), source: "touch")
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = self.touches[touch], touch.timestamp - (lastTouchMove[id] ?? 0) > 0.025 else { continue }
            lastTouchMove[id] = touch.timestamp
            handleInput(phase: "move", pointer: id, point: normalized(touch.location(in: self)), source: "touch")
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let id = self.touches.removeValue(forKey: touch) else { continue }
            lastTouchMove.removeValue(forKey: id)
            handleInput(phase: "up", pointer: id, point: normalized(touch.location(in: self)), source: "touch")
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }

    private func driveAutomation(time: Double, chart: Chart) {
        guard let client, time >= 0 else { return }
        let match = client.snapshot?.matchID ?? -1
        if automatedMatch != match {
            automatedMatch = match
            automatedSteps.removeAll()
            nextDriverFrame = 0
        }
        guard time >= nextDriverFrame else { return }
        nextDriverFrame = time + 1 / 40
        let offset = client.automation == "balanced" ? 0.065 : 0.002
        for note in chart.notes {
            let step = automatedSteps[note.id] ?? 0
            let id = 1000 + note.id
            let start = note.time + offset
            let point = Point.target(note.lane)
            if step == 0 && time >= start && time < start + 0.3 {
                handleInput(phase: "down", pointer: id, point: point, source: "automated")
                automatedSteps[note.id] = 1
            } else if step == 1 {
                if note.kind == "slide" {
                    let elapsed = time - start
                    let progress = max(0, min(0.90, (elapsed - 0.16) / max(0.1, note.duration - 0.16)))
                    let position = elapsed >= note.duration ? (note.path.last ?? point) : interpolate(note.path, progress: progress)
                    handleInput(phase: "move", pointer: id, point: position, source: "automated")
                    if elapsed >= note.duration + 0.06 {
                        handleInput(phase: "up", pointer: id, point: position, source: "automated")
                        automatedSteps[note.id] = 2
                    }
                } else if time >= start + max(0.08, note.duration) {
                    handleInput(phase: "up", pointer: id, point: point, source: "automated")
                    automatedSteps[note.id] = 2
                }
            }
        }
    }
}

struct ArenaView: UIViewRepresentable {
    @ObservedObject var client: GameClient

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.preferredFramesPerSecond = 60
        let scene = OrbitScene(size: CGSize(width: 390, height: 390))
        scene.scaleMode = .resizeFill
        scene.client = client
        view.presentScene(scene)
        view.accessibilityIdentifier = "orbitArena"
        view.accessibilityLabel = "Eight-position rhythm ring. Tap rings at the edge, hold long notes, trace cyan stars."
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}
