import Foundation
import HearthCore
import XCTest

@MainActor final class ClientTests: XCTestCase {
  private func preferences() -> Preferences {
    let defaults = UserDefaults(suiteName: "VoxelHearthTests.\(UUID().uuidString)")!
    return Preferences(defaults: defaults)
  }
  func testJoystickKeyboardInventoryAndReleaseState() {
    let session = Session(preferences: preferences())
    let world = World(seed: 1)
    world.apply(0, 0, edits: [])
    session.world = world
    session.phase = "playing"
    session.connection = .online
    session.mode = "creative"
    let game = Game(session)
    game.body.x = 8
    game.body.y = 70
    game.body.z = 8
    game.body.flying = true
    game.yaw = .pi / 2
    game.stick = SIMD2(0, 1)
    game.update(0.05)
    XCTAssertGreaterThan(game.body.x, 8)
    XCTAssertEqual(game.body.z, 8, accuracy: 0.0001)
    game.jump = true
    game.sneak = true
    game.sprint = true
    game.breaking = true
    game.key("w", down: true)
    game.resetInput()
    XCTAssertEqual(game.stick, .zero)
    XCTAssertTrue(game.keys.isEmpty)
    XCTAssertFalse(game.breaking || game.jump || game.sneak || game.sprint)
    game.key("e", down: true)
    XCTAssertEqual(session.containerKind, "inventory")
    XCTAssertTrue(game.blocked)
    game.key("escape", down: true)
    XCTAssertNil(session.containerKind)
    game.key("t", down: true)
    XCTAssertTrue(game.chatting)
    XCTAssertTrue(game.blocked)
    game.key("escape", down: true)
    XCTAssertFalse(game.chatting)
    game.key("9", down: true)
    XCTAssertEqual(session.selected, 8)
  }
  func testInvalidConnectionsStopAndSettingsPersist() {
    let defaults = UserDefaults(suiteName: "VoxelHearthTests.\(UUID().uuidString)")!
    let preferences = Preferences(defaults: defaults)
    preferences.sensitivity = 1.8
    preferences.fov = 90
    preferences.invertY = true
    let restored = Preferences(defaults: defaults)
    XCTAssertEqual(restored.sensitivity, 1.8)
    XCTAssertEqual(restored.fov, 90)
    XCTAssertTrue(restored.invertY)
    let session = Session(preferences: preferences)
    preferences.server = "not a URL"
    session.connect()
    XCTAssertEqual(session.connection, .failed)
    XCTAssertNotNil(session.error)
    session.disconnect()
    XCTAssertEqual(session.connection, .idle)
  }
  func testSneakDoesNotWalkOffLedge() {
    let session = Session(preferences: preferences())
    let world = World(seed: 1)
    world.apply(0, 0, edits: [])
    for y in 39...46 {
      for x in 0...5 { for z in 0...5 { world.set(x, y, z, y == 40 && z == 2 ? 1 : 0) } }
    }
    session.world = world
    session.phase = "playing"
    session.connection = .online
    let game = Game(session)
    game.body.x = 2.5
    game.body.y = 41
    game.body.z = 2.5
    game.body.onGround = true
    game.sneak = true
    game.stick = SIMD2(0, 1)
    for _ in 0..<100 { game.update(1 / 60) }
    XCTAssertLessThan(game.body.z, 3.3)
    XCTAssertGreaterThan(game.body.y, 40.5)
  }
}
