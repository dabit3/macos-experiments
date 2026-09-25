import Foundation
import XCTest

@testable import SwapmateKit

private final class MemoryResumeStore: ResumeStore {
  private var tokens: [String: String] = [:]
  func load(server: String) throws -> String? { tokens[server] }
  func save(_ token: String?, server: String) throws { tokens[server] = token }
}

@MainActor
final class BackendTests: XCTestCase {
  private struct Deadline: Error {}

  private func until(
    _ condition: @escaping () -> Bool, timeout: Double = 8,
    file: StaticString = #filePath, line: UInt = #line
  ) async throws {
    let end = Date().addingTimeInterval(timeout)
    while Date() < end {
      if condition() { return }
      try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("Server condition timed out", file: file, line: line)
    throw Deadline()
  }

  func testNativeClientsPlayAuthoritativeMatchAndResume() async throws {
    guard let url = ProcessInfo.processInfo.environment["SWAPMATE_INTEGRATION_URL"] else {
      throw XCTSkip("Set SWAPMATE_INTEGRATION_URL to a running test server.")
    }
    var clients: [GameClient] = []
    var stores: [MemoryResumeStore] = []
    func make(_ name: String, store: MemoryResumeStore) -> GameClient {
      let configuration = AppConfiguration(
        arguments: [], environment: ["SWAPMATE_NAME": name, "SWAPMATE_SERVER": url])
      return GameClient(configuration: configuration, store: store)
    }
    for index in 0..<5 {
      let store = MemoryResumeStore()
      stores.append(store)
      let client = make("Native \(index)", store: store)
      clients.append(client)
      client.connect()
      try await until { client.online }
    }
    defer { for client in clients { client.disconnect(forget: true) } }
    let host = clients[0]
    host.send(.create(TimeControl(initialMs: 300_000, incrementMs: 0), fillBots: false, code: nil))
    try await until { host.room != nil }
    let code = try XCTUnwrap(host.room?.code)
    for (index, client) in clients.enumerated() where index > 0 {
      client.send(.join(code, spectate: index == 4))
      try await until { client.room?.code == code }
    }
    try await until { host.room?.players.count == 4 && host.room?.spectators.count == 1 }
    XCTAssertEqual(Array(clients.prefix(4)).compactMap(\.mySeat), Seat.allCases)
    XCTAssertNil(clients[4].mySeat)

    host.send(.chat("Room hello", .room))
    try await until { clients.allSatisfy { $0.chats.contains { $0.text == "Room hello" } } }
    host.send(.quick(.needKnight, .team))
    try await until { clients[3].chats.contains { $0.quick == .needKnight } }
    XCTAssertFalse(clients[1].chats.contains { $0.quick == .needKnight })
    XCTAssertFalse(clients[4].chats.contains { $0.quick == .needKnight })
    for client in clients.prefix(4) { client.send(.ready(true)) }
    try await until { clients.allSatisfy { $0.room?.phase == .playing && $0.game != nil } }

    // A valid shape with an illegal chess move must be rejected by the real server.
    host.send(.move(try XCTUnwrap(Move(uci: "e2e5"))))
    try await until { host.error != nil }
    XCTAssertTrue(host.error?.contains("illegal_move") == true)
    host.error = nil

    let oldID = clients[3].playerID
    clients[3].disconnect()
    try await until { host.room?.seated(.bb)?.connected == false }
    let resumed = make("Native resumed", store: stores[3])
    clients[3] = resumed
    resumed.connect()
    try await until { resumed.online && resumed.game != nil }
    XCTAssertEqual(resumed.playerID, oldID)
    XCTAssertEqual(resumed.mySeat, .bb)
    XCTAssertEqual(resumed.room?.players.count, 4)

    func play(_ index: Int, _ uci: String) async throws {
      let client = clients[index]
      let before = try XCTUnwrap(client.game?.moves.count)
      let move = try XCTUnwrap(Move(uci: uci))
      client.submit(move, on: try XCTUnwrap(client.mySeat?.board))
      try await until { client.game?.moves.count ?? 0 > before || client.error != nil }
      XCTAssertNil(client.error, uci)
      try await until { clients.allSatisfy { ($0.game?.moves.count ?? 0) > before } }
    }
    try await play(0, "e2e4")
    try await play(1, "d7d5")
    try await play(0, "e4d5")
    let reserve = try Position(fen: XCTUnwrap(resumed.game?.boards.b.fen)).reserve(.black, .pawn)
    XCTAssertEqual(reserve, 1)
    try await play(2, "e2e4")
    try await play(3, "e7e5")

    resumed.send(.premove(try XCTUnwrap(Move(uci: "P@d6"))))
    try await until { resumed.game?.premove?.uci == "P@d6" }
    try await play(2, "d1h5")
    try await until { clients.allSatisfy { $0.game?.moves.count == 7 } }
    XCTAssertEqual(resumed.game?.moves.last?.san, "P@d6")
    XCTAssertNil(resumed.game?.premove)
    try await play(2, "f1c4")
    try await play(3, "b8c6")
    try await play(2, "h5f7")
    try await until { clients.allSatisfy { $0.game?.result != nil && $0.room?.phase == .finished } }
    for client in clients {
      XCTAssertEqual(client.game?.result?.reason, .checkmate)
      XCTAssertEqual(client.game?.result?.winner, .ember)
      XCTAssertEqual(client.game?.result?.loser, .bb)
      XCTAssertEqual(client.game?.moves.count, 10)
      XCTAssertTrue(client.game?.bpgn?.contains("2b. P@d6") == true)
    }
    XCTAssertEqual(Set(clients.compactMap { $0.game?.boards.a.fen }).count, 1)
    XCTAssertEqual(Set(clients.compactMap { $0.game?.boards.b.fen }).count, 1)
    let firstGameID = host.game?.gameId
    for client in clients.prefix(4) { client.send(.rematch) }
    try await until {
      clients.allSatisfy { $0.game?.gameId != firstGameID && $0.room?.phase == .playing }
    }
    XCTAssertEqual(host.mySeat, .ab)
    XCTAssertEqual(resumed.mySeat, .bw)
    host.send(.draw(.offer))
    try await until { clients[1].game?.drawOffers.contains(.ab) == true }
    clients[1].send(.draw(.accept))
    try await until { host.game?.drawOffers.contains(.aw) == true }
    XCTAssertNil(host.game?.result)
    clients[2].send(.draw(.accept))
    try await until { host.game?.result?.reason == .agreement }
    XCTAssertNil(host.game?.result?.winner)
    for client in clients { client.send(.leave) }
    try await until { clients.allSatisfy { $0.room == nil && $0.game == nil } }
  }

  func testNativeBotLobbyAndVisibleRoomErrors() async throws {
    guard let url = ProcessInfo.processInfo.environment["SWAPMATE_INTEGRATION_URL"] else {
      throw XCTSkip("Set SWAPMATE_INTEGRATION_URL to a running test server.")
    }
    let config = AppConfiguration(
      arguments: [], environment: ["SWAPMATE_SERVER": url, "SWAPMATE_NAME": "Bot host"])
    let client = GameClient(configuration: config, store: MemoryResumeStore())
    defer { client.disconnect(forget: true) }
    client.connect(entry: .join("ZZZZ-NO-ROOM", spectate: false))
    try await until { client.error?.contains("room_not_found") == true }
    client.send(.create(nil, fillBots: true, code: nil))
    try await until { client.room?.players.count == 4 }
    XCTAssertNil(client.error)
    XCTAssertEqual(client.room?.players.filter(\.bot).count, 3)
    let originalID = client.playerID
    client.connect(entry: .join("ZZZZ-NO-ROOM", spectate: false))
    try await until { client.online && client.error?.contains("room_not_found") == true }
    XCTAssertEqual(client.playerID, originalID)
    client.send(.bot(.bb, add: false))
    try await until { client.room?.seated(.bb) == nil }
    client.send(.bot(.bb, add: true))
    try await until { client.room?.seated(.bb)?.bot == true }
    client.send(.timeControl(TimeControl(initialMs: 60_000, incrementMs: 1000)))
    try await until { client.room?.timeControl.incrementMs == 1000 }
    client.send(.ready(true))
    try await until { client.game != nil }
    client.submit(try XCTUnwrap(Move(uci: "e2e4")), on: .a)
    try await until { client.game?.moves.contains { $0.board == .a && $0.color == .black } == true }
    client.send(.resign)
    try await until { client.game?.result?.reason == .resignation }
    client.send(.leave)
    try await until { client.room == nil }
  }

  func testHTTPCommandsAwaitNativeSnapshots() async throws {
    guard let url = ProcessInfo.processInfo.environment["SWAPMATE_INTEGRATION_URL"] else {
      throw XCTSkip("Set SWAPMATE_INTEGRATION_URL to a running test server.")
    }
    struct Command: Encodable {
      let cmd: String
      var fillBots: Bool?
      var moves: Int?
      var timeoutMs: Int?
    }
    struct Request: Encodable {
      let testId: String
      let command: Command
      let timeoutMs = 5000
    }
    struct Result: Decodable {
      let ok: Bool
      let error: String?
      let room: RoomState?
      let game: GameState?
    }
    struct Response: Decodable {
      let ok: Bool
      let result: Result
    }
    let testID = UUID().uuidString
    let config = AppConfiguration(
      arguments: [],
      environment: [
        "SWAPMATE_SERVER": url, "SWAPMATE_NAME": "HTTP native", "SWAPMATE_TEST_ID": testID,
      ])
    let client = GameClient(configuration: config, store: MemoryResumeStore())
    defer { client.disconnect(forget: true) }
    client.connect()
    try await until { client.online }
    var endpoint = try XCTUnwrap(URLComponents(string: url))
    endpoint.scheme = endpoint.scheme == "wss" ? "https" : "http"
    endpoint.path = "/test/command"
    func command(_ value: Command) async throws -> Result {
      var request = URLRequest(url: try XCTUnwrap(endpoint.url))
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(Request(testId: testID, command: value))
      let (data, responseInfo) = try await URLSession.shared.data(for: request)
      XCTAssertEqual(
        (responseInfo as? HTTPURLResponse)?.statusCode, 200,
        "\(value.cmd): \(String(decoding: data, as: UTF8.self))")
      let response = try JSONDecoder().decode(Response.self, from: data)
      XCTAssertTrue(response.ok)
      return response.result
    }
    let created = try await command(Command(cmd: "create_room", fillBots: true))
    XCTAssertTrue(created.ok)
    XCTAssertEqual(created.room?.players.count, 4)
    let ready = try await command(Command(cmd: "ready"))
    XCTAssertTrue(ready.ok)
    let started = try await command(Command(cmd: "wait", moves: 1))
    XCTAssertNotNil(started.game)
    let timeout = try await command(Command(cmd: "wait", moves: 1_000_000, timeoutMs: 30))
    XCTAssertFalse(timeout.ok)
    XCTAssertEqual(timeout.error, "Command timed out")
    let result = try await command(Command(cmd: "resign"))
    XCTAssertTrue(result.ok)
    XCTAssertEqual(result.game?.result?.reason, .resignation)
    let left = try await command(Command(cmd: "leave"))
    XCTAssertTrue(left.ok)
    XCTAssertNil(left.room)
  }
}
