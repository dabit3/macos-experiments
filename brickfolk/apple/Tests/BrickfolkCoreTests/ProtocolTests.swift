import Foundation
import XCTest

@testable import BrickfolkCore

final class ProtocolTests: XCTestCase {
  func testLegacyPreferencesPreserveNewSettingsAndDoNotCopyToken() throws {
    let suite = "dev.brickfolk.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("light", forKey: "flutter.theme")
    defaults.set("dark", forKey: "theme")
    defaults.set(false, forKey: "flutter.sound")
    defaults.set(true, forKey: "flutter.haptics")
    defaults.set("Builder", forKey: "flutter.session.name")
    defaults.set("test-resume-placeholder", forKey: "flutter.session.token")
    NativePreferences.migrateLegacy(in: defaults)
    XCTAssertEqual(defaults.string(forKey: "theme"), "dark")
    XCTAssertFalse(defaults.bool(forKey: "sound"))
    XCTAssertTrue(defaults.bool(forKey: "haptics"))
    XCTAssertEqual(defaults.string(forKey: "session.name"), "Builder")
    XCTAssertNil(defaults.string(forKey: "session.token"))
    XCTAssertNotNil(defaults.string(forKey: "flutter.session.token"))
    defaults.set(true, forKey: "sound")
    NativePreferences.migrateLegacy(in: defaults)
    XCTAssertTrue(defaults.bool(forKey: "sound"))
  }
  private func decode(_ text: String) throws -> ServerMessage {
    try JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8))
  }
  private func command(_ value: Command) throws -> [String: JSONValue] {
    try JSONDecoder().decode([String: JSONValue].self, from: value.data())
  }
  func testCommandsUseExistingPayloadKeys() throws {
    let hello = try command(.hello(name: "Builder", token: nil, platform: "macos"))
    XCTAssertEqual(hello["protocolVersion"], .number(1))
    XCTAssertNil(hello["token"])
    let avatar = try command(.avatar(Avatar()))
    XCTAssertEqual(avatar["type"], .string("avatar.update"))
    let rate = try command(.rate(.obby, nil))
    XCTAssertEqual(rate["up"], .null)
    XCTAssertEqual(rate["place"], .string("obby"))
    let friend = try command(.friend(.accept, "p1"))
    XCTAssertEqual(friend["player"], .string("p1"))
    XCTAssertEqual(friend["type"], .string("friends.accept"))
    XCTAssertEqual(try command(.roomCreate(.tag, bots: 3))["bots"], .number(3))
    XCTAssertEqual(try command(.partyJoin("crew"))["code"], .string("CREW"))
    XCTAssertEqual(try command(.chat(.room, "Hi"))["channel"], .string("room"))
  }
  func testInputsAreNestedAndPreserveHeldKeysPlansAndActions() throws {
    let obby = try command(.input(.obby(left: true, right: false, jump: true, tick: 890)))
    XCTAssertEqual(
      obby["data"],
      .object(["l": .bool(true), "r": .bool(false), "j": .bool(true), "t": .number(890)]))
    let plan = try command(.input(.plan(tick: 880, entries: [[890, 2], [893, 6], [950, 0]])))
    XCTAssertEqual(
      plan["data"],
      .object([
        "t": .number(880),
        "plan": .array([
          .array([.number(890), .number(2)]), .array([.number(893), .number(6)]),
          .array([.number(950), .number(0)]),
        ]),
      ]))
    XCTAssertEqual(
      try command(.input(.tag(dx: 0.707, dy: -0.707)))["data"],
      .object(["dx": .number(0.71), "dy": .number(-0.71)]))
    XCTAssertEqual(
      try command(.input(.place(cell: 3, item: "dropper")))["data"],
      .object(["a": .string("place"), "cell": .number(3), "item": .string("dropper")]))
    XCTAssertEqual(
      try command(.input(.remove(cell: 3)))["data"],
      .object(["a": .string("remove"), "cell": .number(3)]))
    XCTAssertEqual(
      try command(.input(.upgrade("boost1")))["data"],
      .object(["a": .string("upgrade"), "item": .string("boost1")]))
  }
  func testObbyPackedSnapshotHandlesNullFinishAndLegacyLag() throws {
    let message = try decode(
      #"{"type":"game.state","tick":42,"ticksLeft":99,"players":{"p1":[1.5,2,6,-3,3,4,2,null,18,2],"p2":[5,6,0,0,1,0,0,40]}}"#
    )
    guard case .game(.obby(let frame)) = message else { return XCTFail("Expected Obby") }
    XCTAssertEqual(frame.players["p1"]?.checkpoint, 4)
    XCTAssertEqual(frame.players["p1"]?.inputLag, 2)
    XCTAssertEqual(frame.players["p1"]?.grounded, true)
    XCTAssertEqual(frame.players["p1"]?.facingRight, true)
    XCTAssertNil(frame.players["p1"]?.finishTick)
    XCTAssertEqual(frame.players["p2"]?.finishTick, 40)
    XCTAssertEqual(frame.players["p2"]?.inputLag, -1)
    XCTAssertThrowsError(
      try decode(#"{"type":"game.state","tick":1,"ticksLeft":2,"players":{"p":[1,2]}}"#))
  }
  func testTagPackedSnapshotDoesNotUseObbyInterpretation() throws {
    let message = try decode(
      #"{"type":"game.state","tick":42,"ticksLeft":99,"round":2,"roundTicksLeft":60,"intermission":0,"players":{"p":[1,2,3,12,4,5,6,7,8,1.57]}}"#
    )
    guard case .game(.tag(let frame)) = message else { return XCTFail("Expected Tag") }
    XCTAssertEqual(frame.round, 2)
    XCTAssertEqual(frame.players["p"]?.frozen, true)
    XCTAssertEqual(frame.players["p"]?.isTagger, true)
    XCTAssertEqual(frame.players["p"]?.thawProgress, 12)
    XCTAssertEqual(frame.players["p"]?.totalScore, 8)
  }
  func testRoomLeaveAndErrorFrames() throws {
    guard case .room(let room, let bots, _) = try decode(#"{"type":"room.state","room":null}"#)
    else { return XCTFail() }
    XCTAssertNil(room)
    XCTAssertEqual(bots, 0)
    guard
      case .error(let error) = try decode(
        #"{"type":"error","code":"unauthenticated","message":"Session expired","inReplyTo":"hello"}"#
      )
    else { return XCTFail() }
    XCTAssertEqual(error.inReplyTo, "hello")
    guard case .unknown("future.frame") = try decode(#"{"type":"future.frame"}"#) else {
      return XCTFail()
    }
  }
  func testFlattenedPlayerProfileAndUnsignedColors() throws {
    let profile = try JSONDecoder().decode(PlayerProfile.self, from: Data(Self.profile.utf8))
    XCTAssertEqual(profile.id, "p1")
    XCTAssertEqual(profile.avatar.headColor, 0xFFF5_C04A)
    XCTAssertEqual(profile.owned, ["face_grin"])
    XCTAssertEqual(profile.stats["wins"], 2)
  }
  func testOtherPlayerProfileOmitsPrivateInventory() throws {
    let publicProfile = Self.profile.replacingOccurrences(of: #""owned":["face_grin"],"#, with: "")
    guard
      case .profile(let profile) = try decode(#"{"type":"profile","profile":\#(publicProfile)}"#)
    else { return XCTFail() }
    XCTAssertTrue(profile.owned.isEmpty)
    XCTAssertEqual(profile.name, "Builder")
  }
  func testCanonicalResultsChecksumUsesUTF16() throws {
    let text =
      #"{"roomCode":"TEST","experience":"obby","durationMs":42000,"checksum":"","entries":[{"rank":1,"player":\#(Self.player),"score":42,"detail":"Finished 42.0s","pipsEarned":40,"badgesEarned":["summit"]}]}"#
    let results = try JSONDecoder().decode(MatchResults.self, from: Data(text.utf8))
    var hash = 7
    for unit in "1|Builder|42|Finished 42.0s".utf16 {
      hash = (hash * 31 + Int(unit)) % 1_000_000_007
    }
    XCTAssertEqual(results.computedChecksum, String(format: "%08x", hash))
  }
  func testContentContainsCompleteServerGeometryAndCatalog() throws {
    let content = try GameContent.load()
    XCTAssertEqual(content.catalog.count, 19)
    XCTAssertEqual(content.bodyColors.count, 14)
    XCTAssertEqual(content.obby.checkpoints.count, 12)
    XCTAssertEqual(content.obby.platforms.filter { $0.kind == "checkpoint" }.count, 12)
    XCTAssertEqual(content.tag.width, 24)
    XCTAssertEqual(content.tag.height, 16)
    XCTAssertEqual(content.tag.walls.count, 9)
    XCTAssertEqual(content.bricks.map(\.id), ["dropper", "conveyor", "vault", "fountain"])
    XCTAssertEqual(content.dailyRewards, [25, 35, 50, 65, 80, 100, 150])
  }
  func testTycoonAdjacencyMultipliersAndNullCells() throws {
    let cells: [String?] = ["dropper", "conveyor"] + Array(repeating: nil, count: 34)
    let payload = PlotFixture(
      cells: cells, upgrades: ["boost1"], cash: 100, earned: 30, bricksPlaced: 2)
    let plot = try JSONDecoder().decode(TycoonPlot.self, from: JSONEncoder().encode(payload))
    XCTAssertEqual(plot.income(content: try GameContent.load()), 10)
    XCTAssertNil(plot.cells[2])
  }
  func testConfigEnvironmentAndArgumentsPrecedence() throws {
    let config = LaunchConfig(
      environment: ["BRICKFOLK_BOTS": "7", "BRICKFOLK_TEST": "true", "BRICKFOLK_NAME": "EnvName"],
      arguments: [
        "app", "--brickfolk-name=ArgName", "--brickfolk-bots", "99", "--brickfolk-auto-ready=false",
        "--brickfolk-experience=tag",
      ])
    XCTAssertEqual(config.name, "ArgName")
    XCTAssertEqual(config.bots, 7)
    XCTAssertTrue(config.test)
    XCTAssertFalse(config.autoReady)
    XCTAssertEqual(config.experience, .tag)
    XCTAssertThrowsError(try Endpoint.validated("https://localhost/ws"))
    XCTAssertThrowsError(try Endpoint.validated("ws://user:password@localhost/ws"))
    XCTAssertThrowsError(try Endpoint.validated("not a url"))
    XCTAssertEqual(try Endpoint.validated("ws://127.0.0.1:8080/ws").port, 8080)
  }
  func testRemotePilotWaitsForLagAndStopsPlans() throws {
    let pilot = AutomationPilot(name: "Builder")
    let content = try GameContent.load()
    guard
      case .game(let frame) = try decode(
        #"{"type":"game.state","tick":20,"ticksLeft":100,"players":{"p":[2,0,0,0,3,0,0,null,0,-1]}}"#
      ),
      let input = pilot.decide(frame: frame, id: "p", content: content)
    else { return XCTFail() }
    XCTAssertEqual(
      try command(.input(input))["data"],
      .object(["t": .number(20), "plan": .array([.array([.number(20), .number(0)])])]))
  }
  func testPhoneTagCameraKeepsCornerAvatarsAndLabelsClearOfHUD() throws {
    let arena = try GameContent.load().tag
    for (width, height) in [(320.0, 580.0), (390.0, 640.0), (820.0, 800.0)] {
      for x in [0.4, arena.width - 0.4] {
        for y in [0.4, arena.height - 0.4] {
          let camera = ArenaViewport(
            width: width, height: height, playerX: x, playerY: y, arena: arena)
          let screenX = camera.originX + x * camera.scale
          let screenY = camera.originY + y * camera.scale
          XCTAssertGreaterThanOrEqual(screenX, 48)
          XCTAssertLessThanOrEqual(screenX, width - 48)
          XCTAssertGreaterThanOrEqual(screenY - camera.scale * 1.85, 40)
          XCTAssertLessThanOrEqual(screenY, height - 30)
        }
      }
    }
  }
  private static let avatar =
    #"{"headColor":4294295626,"torsoColor":4282285050,"armColor":4294295626,"legColor":4281310811,"face":"face_smile","hat":"hat_none","accessory":"acc_none"}"#
  private static let player =
    #"{"id":"p1","name":"Builder","avatar":\#(avatar),"platform":"macos","isBot":false,"online":true}"#
  private static let profile =
    #"{"id":"p1","name":"Builder","avatar":\#(avatar),"platform":"macos","isBot":false,"online":true,"pips":150,"owned":["face_grin"],"badges":["welcome"],"createdAt":123,"dailyStreak":1,"lastDailyClaim":null,"stats":{"wins":2}}"#
}

private struct PlotFixture: Encodable {
  let cells: [String?]
  let upgrades: [String]
  let cash, earned, bricksPlaced: Int
}

private enum JSONValue: Decodable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
  case object([String: JSONValue])
  case array([JSONValue])
  init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer()
    if value.decodeNil() {
      self = .null
    } else if let boolean = try? value.decode(Bool.self) {
      self = .bool(boolean)
    } else if let number = try? value.decode(Double.self) {
      self = .number(number)
    } else if let string = try? value.decode(String.self) {
      self = .string(string)
    } else if let object = try? value.decode([String: JSONValue].self) {
      self = .object(object)
    } else {
      self = .array(try value.decode([JSONValue].self))
    }
  }
}
