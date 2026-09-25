import Foundation
import XCTest

@testable import HearthCore

final class DiagnosticsTests: XCTestCase {
  func testStateFingerprintsMatchDartIncludingUnicodeAndNegativeChunks() throws {
    struct Fixture: Decodable {
      let seed: Int
      let edits: [[Int]]
      let world: String
      let chat: [[String]]
      let chatHash: String
      let region: [Int]
      let regionHash: String
    }
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Sources/HearthCore/Resources/state-fixture.json")
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: path))
    let world = World(seed: fixture.seed)
    for edit in fixture.edits.reversed() { world.set(edit[0], edit[1], edit[2], edit[3]) }
    XCTAssertEqual(world.editsHash, fixture.world)
    XCTAssertEqual(world.regionHash(fixture.region), fixture.regionHash)
    let chat = fixture.chat.map { ChatLine(tick: 0, from: $0[0], text: $0[1], system: false) }
    XCTAssertEqual(Fingerprint.chat(chat), fixture.chatHash)
    XCTAssertNil(world.regionHash([0, 0, 0, 10000, 10000, 10000]))
    XCTAssertNil(world.regionHash([1, 1, 1, 0, 0, 0]))
  }

  func testDirectorWireDoesNotLoseCreateAndCraftParameters() throws {
    let data = Data(
      #"{"t":"drive","id":"d1","action":{"t":"create_room","name":"Hearth","seed":9,"mode":"creative","bots":2,"freezeTime":true,"durationTicks":1200}}"#
        .utf8)
    let envelope = try JSONDecoder().decode(ServerMessage.self, from: data)
    let action = try XCTUnwrap(envelope.action)
    let message = try JSONDecoder().decode(ClientMessage.self, from: JSONEncoder().encode(action))
    XCTAssertEqual(envelope.id?.player, "d1")
    XCTAssertEqual(message.t, .createRoom)
    XCTAssertEqual(message.seed, 9)
    XCTAssertEqual(message.bots, 2)
    XCTAssertEqual(message.freezeTime, true)
    XCTAssertEqual(message.durationTicks, 1200)
    let craft = try JSONDecoder().decode(
      DriveAction.self, from: Data(#"{"t":"craft","grid":[8,8,8,8],"n":2,"count":2}"#.utf8))
    let intent = try JSONDecoder().decode(ClientMessage.self, from: JSONEncoder().encode(craft))
    XCTAssertEqual(intent.grid, [8, 8, 8, 8])
    XCTAssertEqual(intent.n, 2)
    XCTAssertEqual(intent.count, 2)
  }
}
