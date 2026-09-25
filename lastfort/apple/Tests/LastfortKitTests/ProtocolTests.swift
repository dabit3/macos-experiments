import Foundation
import XCTest

@testable import LastfortKit

final class ProtocolTests: XCTestCase {
  func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
  }
  func testAuthoritativeStartAndSnapshot() throws {
    let start = try JSONDecoder().decode(MatchStart.self, from: fixture("match-start"))
    let snapshot = try JSONDecoder().decode(Snapshot.self, from: fixture("snapshot"))
    XCTAssertEqual(start.seed, 4242)
    XCTAssertEqual(start.rules.tickRate, 20)
    XCTAssertEqual(snapshot.players.first?.st?.kills, 0)
    XCTAssertEqual(snapshot.players.first?.inv?.count, 6)
    XCTAssertEqual(snapshot.match.phase, .bus)
    XCTAssertEqual(snapshot.match.bus?.rem, 5)
    for name in ["match-start", "snapshot", "match-end"] {
      _ = try JSONDecoder().decode(ServerMessage.self, from: fixture(name))
    }
  }
  func testInputUsesExactSparseDartKeys() throws {
    var input = ClientMessage(.input)
    input.f = InputFrame(seq: 42, mx: 0, my: -1, aim: 1.25, fire: false, sprint: false, act: [])
    XCTAssertEqual(try encode(input), #"{"f":{"aim":1.25,"mx":0,"my":-1,"seq":42},"t":"input"}"#)
    input.f?.fire = true
    input.f?.act = [GameAction(.select, slot: 0), GameAction(.edit, value: "door", gx: 12, gy: 13)]
    XCTAssertEqual(
      try encode(input),
      #"{"f":{"act":[{"t":"select"},{"gx":12,"gy":13,"t":"edit","v":"door"}],"aim":1.25,"fire":true,"mx":0,"my":-1,"seq":42},"t":"input"}"#
    )
    let decoded = try JSONDecoder().decode(ClientMessage.self, from: Data(encode(input).utf8))
    XCTAssertEqual(decoded.f?.act.count, 2)
    XCTAssertEqual(decoded.f?.sprint, false)
  }
  func testLobbyAndIdentityMessageKeys() throws {
    var hello = ClientMessage(.hello)
    hello.v = 1
    hello.name = "Scout"
    hello.platform = "ios"
    hello.ld = Loadout()
    hello.token = "session-only-test"
    XCTAssertEqual(
      try encode(hello),
      #"{"ld":{"b":"banner_fort","g":"glider_kite","o":"outfit_recruit","p":"pickaxe_splinter"},"name":"Scout","platform":"ios","t":"hello","token":"session-only-test","v":1}"#
    )
    var create = ClientMessage(.createRoom)
    create.mode = .duos
    create.fast = true
    create.seed = 4242
    create.code = "NATIVE"
    XCTAssertEqual(
      try encode(create),
      #"{"code":"NATIVE","fast":true,"mode":"duos","seed":4242,"t":"createRoom"}"#)
    var ready = ClientMessage(.ready)
    ready.ready = true
    XCTAssertEqual(try encode(ready), #"{"ready":true,"t":"ready"}"#)
    var control = ClientMessage(.testControl)
    control.op = "autopilot"
    control.on = true
    XCTAssertEqual(try encode(control), #"{"on":true,"op":"autopilot","t":"testControl"}"#)
  }
  @MainActor func testReplicaRemovalByStructureIDAndAcknowledgement() throws {
    let start = try JSONDecoder().decode(MatchStart.self, from: fixture("match-start"))
    let snapshot = try JSONDecoder().decode(Snapshot.self, from: fixture("snapshot"))
    let replica = MatchReplica(start)
    replica.localID = 1
    replica.apply(snapshot)
    let structure = try XCTUnwrap(
      replica.island.structures.values.first { $0.id != replica.island.key($0.gx, $0.gy) })
    let delta = Snapshot(
      tick: 1, match: snapshot.match, players: snapshot.players, structs: [],
      gone: [structure.id], nodes: [], chests: [], loot: [], ev: [])
    replica.apply(delta)
    XCTAssertNil(replica.island.structures[replica.island.key(structure.gx, structure.gy)])
    let frame = try XCTUnwrap(
      replica.input(mx: 1, my: 1, aim: 0, fire: false, sprint: false, actions: [.init(.jump)]))
    XCTAssertEqual(frame.seq, 1)
    XCTAssertEqual(frame.mx, 0.707)
    XCTAssertEqual(frame.my, 0.707)
  }
  func testRewardsAreIdempotentAcrossResumeButAllowRematches() throws {
    guard
      case .end(let summary) = try JSONDecoder().decode(
        ServerMessage.self, from: fixture("match-end"))
    else {
      return XCTFail("Expected a real server summary")
    }
    var profile = ProfileData()
    profile.record(summary, playerID: 1, server: "local", room: "NATIVE", token: "secret")
    profile.record(summary, playerID: 1, server: "local", room: "NATIVE", token: "secret")
    XCTAssertEqual(profile.career.matches, 1)
    XCTAssertEqual(profile.xp, summary.players.first?.xp)
    XCTAssertFalse(try encode(profile).contains("secret"))
    profile.matchEpoch = UUID().uuidString
    profile.record(summary, playerID: 1, server: "local", room: "NATIVE", token: "secret")
    XCTAssertEqual(profile.career.matches, 2)
    let tier = PassTier(tier: 11, xpRequired: Int.max, rewardId: "locked")
    profile.claim(tier)
    XCTAssertFalse(profile.unlocked.contains("locked"))
  }
  func testLaunchArgumentsOverrideEnvironment() {
    let options = LaunchOptions(
      environment: ["LASTFORT_SERVER": "ws://a", "LASTFORT_AUTO": "true"],
      arguments: ["Lastfort", "--server=wss://b/ws", "--autostart=2"])
    XCTAssertEqual(options["SERVER"], "wss://b/ws")
    XCTAssertTrue(options.auto)
    XCTAssertEqual(options.autoStart, 2)
  }
  private func encode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
}
