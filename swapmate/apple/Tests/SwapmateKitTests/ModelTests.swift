import Foundation
import XCTest

@testable import SwapmateKit

final class ModelTests: XCTestCase {
  func testLegalTargetsMatchAuthoritativeDartRules() throws {
    struct Fixture: Decodable {
      let fen: String
      let inCheck: Bool
      let legal: [String]
    }
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: "positions", withExtension: "json", subdirectory: "Fixtures"))
    let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    XCTAssertGreaterThan(fixtures.count, 100)
    for fixture in fixtures {
      let position = try Position(fen: fixture.fen)
      XCTAssertEqual(position.inCheck(position.turn), fixture.inCheck, fixture.fen)
      XCTAssertEqual(position.legalMoves().map(\.uci).sorted(), fixture.legal, fixture.fen)
    }
  }

  func testMoveWirePayloadsAndNullCancellation() throws {
    let cases: [(ClientCommand, String)] = [
      (
        .move(try XCTUnwrap(Move(uci: "e7e8n"))),
        #"{"type":"game.move","move":{"from":"e7","to":"e8","promotion":"N"}}"#
      ),
      (
        .move(try XCTUnwrap(Move(uci: "P@e2"))),
        #"{"type":"game.move","move":{"drop":"P","to":"e2"}}"#
      ),
      (.premove(nil), #"{"type":"game.premove","move":null}"#),
      (.seat(nil), #"{"type":"room.seat","seat":null}"#),
      (.create(nil, fillBots: true, code: nil), #"{"type":"room.create","fillBots":true}"#),
      (.bot(.bb, add: false), #"{"type":"room.bot","seat":"bb","add":false}"#),
      (.quick(.needKnight, .team), #"{"type":"chat.send","quick":"need_n","scope":"team"}"#),
      (
        .hello(name: "Test", platform: "ios", resumeToken: nil, testId: nil),
        #"{"type":"hello","v":1,"name":"Test","platform":"ios"}"#
      ),
    ]
    for (command, expected) in cases {
      let encoded = try JSONEncoder().encode(command)
      let actual = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
      let reference = try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary
      XCTAssertEqual(actual, reference)
    }
  }

  func testFENPromotedReservesAndMalformedInput() throws {
    let position = try Position(fen: "k7/7Q~/8/8/8/8/8/K7[PNq] b - - 0 1")
    XCTAssertEqual(position[Square("h7")!], Piece(color: .white, kind: .queen, promoted: true))
    XCTAssertEqual(position.reserve(.white, .knight), 1)
    XCTAssertEqual(position.reserve(.black, .queen), 1)
    for fen in ["", "8 w - -", "9/8/8/8/8/8/8/8 w - -", "8/8/8/8/8/8/8/8[K] w - -"] {
      XCTAssertThrowsError(try Position(fen: fen))
    }
    for uci in ["e9e4", "Q@z1", "e7e8k", "K@e4", "bad", "e2e4qq"] {
      XCTAssertNil(Move(uci: uci))
    }
  }

  func testSeatTeamsAndClockSampling() {
    for seat in Seat.allCases {
      XCTAssertEqual(seat.team, seat.partner.team)
      XCTAssertNotEqual(seat.color, seat.partner.color)
      XCTAssertEqual(seat.partner.partner, seat)
    }
    let clock = BoardClock(w: 30_000, b: 40_000, running: .white)
    XCTAssertEqual(clock.remaining(.white, sampledAt: 1000, now: 2500), 28_500)
    XCTAssertEqual(clock.remaining(.black, sampledAt: 1000, now: 2500), 40_000)
    XCTAssertEqual(clock.remaining(.white, sampledAt: 1000, now: 100_000), 0)
    XCTAssertEqual(clock.remaining(.white, sampledAt: 1000, now: 0), 30_000)
  }

  func testConfigurationHonorsExistingLaunchArguments() throws {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    defaults.set("Saved", forKey: "name")
    let config = AppConfiguration(
      arguments: ["Swapmate", "--SWAPMATE_SERVER=ws://host:8787/ws", "--name", "Arg"],
      environment: ["SWAPMATE_NAME": "Environment", "SWAPMATE_TEST_ID": "ios"], defaults: defaults)
    XCTAssertEqual(config.name, "Arg")
    XCTAssertEqual(config.server, "ws://host:8787/ws")
    XCTAssertTrue(config.autoConnect)
    let disabled = AppConfiguration(
      arguments: [
        "--autoconnect", "false", "--SWAPMATE_NAME", "Long argument", "--theme", "invalid",
      ],
      environment: [:], defaults: defaults)
    XCTAssertFalse(disabled.autoConnect)
    XCTAssertEqual(disabled.name, "Long argument")
    XCTAssertEqual(disabled.theme, "dark")
    let roomLaunch = AppConfiguration(
      arguments: ["--SWAPMATE_ROOM=swap"], environment: [:], defaults: defaults)
    XCTAssertTrue(roomLaunch.autoConnect)
    let entry = try XCTUnwrap(roomLaunch.initialCommand)
    let encoded =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? NSDictionary
    XCTAssertEqual(encoded, ["type": "room.join", "code": "SWAP", "spectate": false])
  }

  @MainActor
  func testInvalidServerIsVisibleWithoutOpeningConnection() {
    let client = GameClient()
    client.connect(url: "https://example.com")
    XCTAssertEqual(client.status, .offline)
    XCTAssertNotNil(client.error)
    XCTAssertNil(GameClient.validatedURL("ws://secret:password@host"))
  }
}
