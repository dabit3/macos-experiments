import SceneKit
import XCTest

@testable import LucidLanes

final class StageTests: XCTestCase {
    @MainActor
    func testBallAndRackRemainInsideCompactAndTallPlayfields() throws {
        let suite = "stage-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = GameModel(defaults: defaults)
        let stage = LaneStage()
        for size in [CGSize(width: 375, height: 330), CGSize(width: 440, height: 600)] {
            let view = SCNView(frame: CGRect(origin: .zero, size: size))
            view.scene = stage.scene
            view.pointOfView = stage.camera
            stage.update(model: model, hero: false, reduceMotion: true, size: size)
            for name in ["ball", "pin-0", "pin-6", "pin-9"] {
                let node = try XCTUnwrap(stage.scene.rootNode.childNode(withName: name, recursively: true))
                let point = view.projectPoint(node.position)
                XCTAssertGreaterThan(point.x, 0, "\(name), \(size)")
                XCTAssertLessThan(point.x, Float(size.width), "\(name), \(size)")
                XCTAssertGreaterThan(point.y, 0, "\(name), \(size)")
                XCTAssertLessThan(point.y, Float(size.height), "\(name), \(size)")
                XCTAssertTrue((0...1).contains(point.z))
            }
        }
    }

    @MainActor
    func testStageFollowsSimulatedBallAndRemovesClearedPins() throws {
        let suite = "stage-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = GameModel(defaults: defaults)
        model.physics.launch(aim: 0.2, power: 0.65, curve: 0.4)
        for step in 0..<90 {
            model.physics.step(dt: 1.0 / 120, lane: model.lane, time: Double(step) / 120)
        }
        model.physics.pins.removeAll { $0.id == 0 }
        let stage = LaneStage()
        stage.update(model: model, hero: false, reduceMotion: true, size: CGSize(width: 440, height: 600))
        let ball = try XCTUnwrap(stage.scene.rootNode.childNode(withName: "ball", recursively: true))
        XCTAssertEqual(ball.position.x, Float(model.physics.ball.x * 1.6), accuracy: 0.0001)
        XCTAssertEqual(ball.position.z, Float(4.5 - model.physics.ball.y * 1.3), accuracy: 0.0001)
        let clearedPin = try XCTUnwrap(stage.scene.rootNode.childNode(withName: "pin-0", recursively: true))
        XCTAssertTrue(clearedPin.isHidden)
        stage.update(model: model, hero: true, reduceMotion: true, size: CGSize(width: 440, height: 400))
        XCTAssertFalse(clearedPin.isHidden)
    }
}
