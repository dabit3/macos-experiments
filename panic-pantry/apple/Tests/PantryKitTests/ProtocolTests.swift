import Foundation
import XCTest

@testable import PantryKit

final class ProtocolTests: XCTestCase {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  func testHelloRequiresVersionAndNeverEncodesMissingToken() throws {
    let data = try encoder.encode(ClientMessage.hello(name: "Ada", platform: "macos", token: nil))
    struct Hello: Decodable {
      let type, name, platform: String
      let `protocol`: Int
      let token: String?
    }
    let hello = try decoder.decode(Hello.self, from: data)
    XCTAssertEqual(hello.type, "hello")
    XCTAssertEqual(hello.protocol, 1)
    XCTAssertEqual(hello.name, "Ada")
    XCTAssertEqual(hello.platform, "macos")
    XCTAssertNil(hello.token)
    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("token"))
  }

  func testInputUsesFlattenedCompactKeysAndHeldStateExcludesEdges() throws {
    let input = ChefInput(
      dx: 0.7, dy: -0.7, interact: true, action: true, dash: true, emote: 3, targetX: 2, targetY: 0)
    let data = try encoder.encode(ClientMessage.input(input))
    struct Envelope: Decodable {
      let type: String
      let dx, dy: Double
      let i, a, d: Bool
      let e, tx, ty: Int
    }
    let envelope = try decoder.decode(Envelope.self, from: data)
    XCTAssertEqual(envelope.type, "input")
    XCTAssertEqual(envelope.tx, 2)
    XCTAssertEqual(envelope.ty, 0)
    XCTAssertEqual(envelope.e, 3)
    XCTAssertTrue(envelope.i && envelope.a && envelope.d)
    XCTAssertEqual(try decoder.decode(ChefInput.self, from: data), input)
    XCTAssertEqual(input.held, ChefInput(dx: 0.7, dy: -0.7, action: true))
    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("input\":"))
  }

  func testEveryItemMatchesDartEncoding() throws {
    let items: [(String, Item)] = [
      (#"{"t":"ing","i":"tomato","c":true}"#, .ingredient(.tomato, chopped: true)),
      (
        #"{"t":"pot","n":["onion","onion","onion"],"k":0.7,"b":0.1,"x":false}"#,
        .pot(contents: [.onion, .onion, .onion], cook: 0.7, burn: 0.1, burnt: false)
      ),
      (
        #"{"t":"plate","n":["lettuce","tomato"],"k":false}"#,
        .plate(contents: [.lettuce, .tomato], cooked: false)
      ),
      (#"{"t":"stack","c":3,"d":true}"#, .stack(count: 3, dirty: true)),
      (#"{"t":"ext"}"#, .extinguisher),
    ]
    for (json, expected) in items {
      let item = try decoder.decode(Item.self, from: Data(json.utf8))
      XCTAssertEqual(item, expected)
      XCTAssertEqual(try decoder.decode(Item.self, from: encoder.encode(item)), expected)
    }
    XCTAssertThrowsError(try decoder.decode(Item.self, from: Data(#"{"t":"unsupported"}"#.utf8)))
  }

  func testRoomCommandsAndNormalizedJoinCode() throws {
    struct Envelope: Decodable {
      let type: String
      let code, level: String?
      let ready: Bool?
    }
    let commands: [(ClientMessage, String)] = [
      (.room(.leave), "room.leave"), (.room(.addBot), "room.addBot"),
      (.room(.removeBot), "room.removeBot"),
      (.room(.start), "room.start"), (.room(.rematch), "room.rematch"),
      (.ready(true), "room.ready"), (.create(level: "training"), "room.create"),
      (.setLevel("drift-deck"), "room.setLevel"),
    ]
    for (command, type) in commands {
      XCTAssertEqual(try decoder.decode(Envelope.self, from: encoder.encode(command)).type, type)
    }
    let joined = try decoder.decode(
      Envelope.self, from: encoder.encode(ClientMessage.join(code: " abcd\n")))
    XCTAssertEqual(joined.type, "room.join")
    XCTAssertEqual(joined.code, "ABCD")
  }

  func testWelcomeScriptErrorsAndNilRoom() throws {
    let welcome =
      #"{"type":"welcome","playerId":"p1","token":"fixture","name":"Ada","protocol":1,"resumed":true,"tickSeconds":0.05,"levels":[]}"#
    guard
      case .welcome(let result) = try decoder.decode(ServerMessage.self, from: Data(welcome.utf8))
    else {
      return XCTFail("Missing welcome")
    }
    XCTAssertTrue(result.resumed)
    XCTAssertEqual(result.tickSeconds, 0.05)
    let input = #"{"type":"test.input","steps":[{"dx":1,"a":true,"i":true,"ticks":8},{}]}"#
    guard
      case .testInput(let steps) = try decoder.decode(ServerMessage.self, from: Data(input.utf8))
    else {
      return XCTFail("Missing scripted input")
    }
    XCTAssertEqual(steps[0].ticks, 8)
    XCTAssertEqual(steps[1].ticks, 1)
    XCTAssertEqual(steps[0].input.held, ChefInput(dx: 1, action: true))
    guard
      case .room(nil) = try decoder.decode(
        ServerMessage.self, from: Data(#"{"type":"room.state","room":null}"#.utf8))
    else {
      return XCTFail("Leaving a room must clear state")
    }
    guard
      case .error(let code, let message) = try decoder.decode(
        ServerMessage.self,
        from: Data(#"{"type":"error","code":"not_host","message":"Only host"}"#.utf8))
    else {
      return XCTFail("Expected a visible server error")
    }
    XCTAssertEqual(code, "not_host")
    XCTAssertEqual(message, "Only host")
  }

  func testSnapshotsAndResultsExportedByRealDartSimulation() throws {
    struct Fixture: Decodable {
      let level: String
      let snapshots: [Snapshot]
      let results: Results
    }
    let url = try XCTUnwrap(Bundle.module.url(forResource: "rounds", withExtension: "json"))
    let fixtures = try decoder.decode([Fixture].self, from: Data(contentsOf: url))
    let levels = try LevelCatalogue.load()
    XCTAssertEqual(fixtures.count, 5)
    for fixture in fixtures {
      let level = try XCTUnwrap(levels.first { $0.id == fixture.level })
      XCTAssertEqual(fixture.snapshots.first?.phase, .countdown)
      XCTAssertEqual(fixture.snapshots.last?.phase, .finished)
      XCTAssertEqual(fixture.snapshots.last?.score, fixture.results.score)
      XCTAssertEqual(
        fixture.results.stars,
        fixture.results.thresholds.filter { fixture.results.score >= $0 }.count)
      XCTAssertGreaterThan(fixture.results.served, 0)
      for snapshot in fixture.snapshots {
        XCTAssertEqual(snapshot.chefs.count, 4)
        XCTAssertEqual(snapshot.offsets.count, level.movers.count)
        let cells = Kitchen.cells(level: level, snapshot: snapshot)
        XCTAssertEqual(
          cells.count,
          level.width * level.height + level.movers.reduce(0) { $0 + $1.width * $1.height })
        for (index, mover) in level.movers.enumerated() {
          let first = try XCTUnwrap(cells.first { $0.id == "\(index):0,0" })
          XCTAssertEqual(
            first.x, Double(mover.x) + (mover.axis == "x" ? snapshot.offsets[index] : 0))
          XCTAssertEqual(
            first.y, Double(mover.y) + (mover.axis == "y" ? snapshot.offsets[index] : 0))
          XCTAssertEqual(first.state, snapshot.movers[index][0])
        }
      }
    }
  }

  func testSparseSnapshotsClearStationItemsInsteadOfRecreatingThem() throws {
    let level = try XCTUnwrap(LevelCatalogue.load().first)
    let empty = Snapshot(
      tick: 1, time: 0.05, phase: .playing, countdown: 0, timeLeft: 100, overtime: 0,
      score: 0, combo: 1, served: 0, expired: 0, tiles: [:], movers: [], offsets: [],
      chefs: [], orders: [], events: nil)
    XCTAssertNotNil(
      Kitchen.cells(level: level, snapshot: nil).first { $0.symbol == "S" }?.state.item)
    XCTAssertNil(
      Kitchen.cells(level: level, snapshot: empty).first { $0.symbol == "S" }?.state.item)
  }

  func testLaunchArgumentsAndURLValidation() throws {
    let name = "PantryConfiguration-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set("Saved", forKey: "chefName")
    let config = LaunchConfiguration(
      environment: ["PP_NAME": "Environment", "SIMCTL_CHILD_PP_ROOM": "ABCD", "PP_AUTO": "1"],
      arguments: ["app", "--PP_NAME", "Argument", "PP_SERVER=ws://127.0.0.1:8787/ws"],
      defaults: defaults)
    XCTAssertEqual(config.name, "Argument")
    XCTAssertEqual(config.room, "ABCD")
    XCTAssertTrue(config.automatic)
    XCTAssertNotNil(LaunchConfiguration.serverURL(config.server))
    XCTAssertNotNil(LaunchConfiguration.serverURL("wss://example.com/ws"))
    for invalid in [
      "https://example.com", "not a URL", "ws://", "ws://u:p@example.com/ws",
      "ws://example.com/ws#fragment",
    ] {
      XCTAssertNil(LaunchConfiguration.serverURL(invalid))
    }
  }
}
