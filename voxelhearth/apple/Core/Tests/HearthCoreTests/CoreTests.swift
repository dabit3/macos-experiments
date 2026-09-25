import Foundation
import XCTest

@testable import HearthCore

final class CoreTests: XCTestCase {
  func testTerrainMatchesAuthoritativeDartChunks() throws {
    struct Fixture: Decodable {
      let seed: Int
      let x: Int
      let z: Int
      let hash: UInt32
    }
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent(
        "Sources/HearthCore/Resources/terrain-fixtures.json")
    let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: path))
    XCTAssertEqual(fixtures.count, 20)
    for fixture in fixtures {
      let chunk = WorldGenerator(seed: fixture.seed).generate(fixture.x, fixture.z)
      let hash = chunk.blocks.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
      XCTAssertEqual(hash, fixture.hash, "seed \(fixture.seed) chunk \(fixture.x),\(fixture.z)")
    }
  }
  func testChunkEditsAndNegativeCoordinates() {
    let world = World(seed: 424242)
    let index = (40 * 16 + 15) * 16 + 15
    world.apply(-1, -1, edits: [index, 18])
    XCTAssertEqual(world.peek(-1, 40, -1), 18)
    world.set(-1, 40, -1, 0)
    XCTAssertEqual(world.peek(-1, 40, -1), 0)
    world.apply(-1, -1, edits: [index, 17])
    XCTAssertEqual(world.peek(-1, 40, -1), 17)
    world.apply(1, 1, edits: [-4, 9, 100000, 1, 0, -1])
    XCTAssertEqual(world.peek(16, 0, 16), 14)
  }
  func testCollisionJumpAndRaycast() {
    let world = World(seed: 1)
    world.apply(0, 0, edits: [])
    for y in 40...46 { for x in 0...5 { for z in 0...5 { world.set(x, y, z, y == 40 ? 1 : 0) } } }
    var body = Body()
    body.x = 2.5
    body.y = 41
    body.z = 2.5
    body.onGround = true
    Physics.step(&body, world: world, dt: 1 / 60, wishX: 0, wishZ: 0, jump: true)
    XCTAssertGreaterThan(body.y, 41)
    for _ in 0..<150 {
      Physics.step(&body, world: world, dt: 1 / 60, wishX: 0, wishZ: 0, jump: false)
    }
    XCTAssertTrue(body.onGround)
    XCTAssertGreaterThanOrEqual(body.y, 41)
    let hit = Physics.raycast(world, origin: SIMD3(2.5, 43, 2.5), direction: SIMD3(0, -1, 0))
    XCTAssertEqual(hit?.y, 40)
    XCTAssertEqual(hit?.ny, 1)
  }
  func testCameraRelativeJoystickAndDiagonalNormalization() {
    let forward = Physics.wish(strafe: 0, forward: 1, yaw: .pi / 2)
    XCTAssertEqual(forward.x, 1, accuracy: 0.00001)
    XCTAssertEqual(forward.y, 0, accuracy: 0.00001)
    let diagonal = Physics.wish(strafe: 1, forward: 1, yaw: 0)
    XCTAssertEqual(hypot(diagonal.x, diagonal.y), 1, accuracy: 0.00001)
  }
  func testRegistryRecipesAndHarvestSpeeds() {
    let registry = Registry.shared
    XCTAssertEqual(registry.blocks.count, 34)
    XCTAssertEqual(registry.recipes.count, 28)
    XCTAssertEqual(registry.breakSeconds(1, held: 110), 7.5 * 0.3 / 2)
    XCTAssertEqual(registry.breakSeconds(14, held: 0), -1)
    let chest = registry.recipes.first { $0.name == "Chest" }!
    XCTAssertEqual(chest.gridNeeded, 3)
    XCTAssertEqual(chest.grid(3), [8, 8, 8, 8, 0, 8, 8, 8, 8])
    XCTAssertTrue(chest.affordable(in: [ItemStack(id: 8, count: 8)]))
    XCTAssertFalse(chest.affordable(in: [ItemStack(id: 8, count: 7)]))
  }
  func testWireModelsAndLaunchOverrides() throws {
    let json = #"{"t":"inventory","slots":[[18,64],[0,0]],"selected":2,"future":true}"#
    let message = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
    XCTAssertEqual(message.slots, [ItemStack(id: 18, count: 64), .empty])
    let gone = try JSONDecoder().decode(
      ServerMessage.self, from: Data(#"{"t":"player_left","id":"p_123"}"#.utf8))
    XCTAssertEqual(gone.id?.player, "p_123")
    var place = ClientMessage.block(.place, -1, 40, 2)
    place.ny = 1
    let encoded = String(decoding: try JSONEncoder().encode(place), as: UTF8.self)
    XCTAssertTrue(encoded.contains("\"t\":\"place\""))
    XCTAssertTrue(encoded.contains("\"ny\":1"))
    XCTAssertFalse(encoded.contains("token"))
    var ready = ClientMessage(.ready)
    ready.ready = false
    XCTAssertTrue(
      String(decoding: try JSONEncoder().encode(ready), as: UTF8.self).contains("\"ready\":false"))
    let config = LaunchConfiguration(
      arguments: [
        "app", "-VH_SERVER", "ws://localhost:8787/ws", "--VH_NAME=Ash", "-VH_CREATE", "1",
      ], environment: [:])
    XCTAssertEqual(config.name, "Ash")
    XCTAssertTrue(config.create)
    XCTAssertEqual(config.server, "ws://localhost:8787/ws")
    XCTAssertNil(ServerAddress.parse("https://example.com"))
    XCTAssertNil(ServerAddress.parse("ws://user:password@example.com"))
    XCTAssertNotNil(ServerAddress.parse("ws://192.168.1.2:8787/ws"))
  }
}
