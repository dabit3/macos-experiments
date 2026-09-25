import Foundation
import XCTest

@testable import PantryKit

final class MemoryResumeStore: ResumeStore {
  private var values: [String: String] = [:]
  func read(server: String) -> String? { values[server] }
  func write(_ token: String?, server: String) throws { values[server] = token }
}

final class BackendIntegrationTests: XCTestCase {
  @MainActor
  func testRealServerLifecycleInputsResumeResultsAndRematch() async throws {
    guard let server = ProcessInfo.processInfo.environment["PP_INTEGRATION_SERVER"] else {
      throw XCTSkip("Run test/native-integration.sh to start the real Dart backend.")
    }
    let store = MemoryResumeStore()
    let suite = "PanicPantryIntegration-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let hostConfig = LaunchConfiguration(
      environment: ["PP_SERVER": server, "PP_NAME": "Native Ada"], arguments: [], defaults: defaults
    )
    let host = GameClient(configuration: hostConfig, defaults: defaults, resumeStore: store)
    let guestConfig = LaunchConfiguration(
      environment: ["PP_SERVER": server, "PP_NAME": "Native Bo"], arguments: [], defaults: defaults)
    let guestStore = MemoryResumeStore()
    let guest = GameClient(configuration: guestConfig, defaults: defaults, resumeStore: guestStore)
    defer {
      host.disconnect()
      guest.disconnect()
    }
    host.connect(intent: .create(level: "training"))
    try await eventually { host.room != nil }
    XCTAssertTrue(host.isHost)
    host.send(.setLevel("drift-deck"))
    try await eventually { host.level?.id == "drift-deck" }
    host.send(.room(.addBot))
    try await eventually { host.room?.players.count == 2 }
    host.send(.room(.removeBot))
    try await eventually { host.room?.players.count == 1 }
    guest.connect(intent: .join(code: "!!!!"))
    try await eventually { guest.error != nil }
    XCTAssertNil(guest.room)
    let firstCode = try XCTUnwrap(host.room?.code)
    guest.send(.join(code: firstCode.lowercased()))
    try await eventually { guest.room?.code == firstCode }
    guest.send(.room(.addBot))
    try await eventually { guest.error?.contains("host") == true }
    guest.leave()
    host.leave()
    try await eventually { guest.room == nil && host.room == nil }

    let roomData = try await request(
      server, path: "/test/rooms", body: #"{"level":"training","seed":99,"speed":10}"#)
    let room = try JSONDecoder().decode(Room.self, from: roomData)
    host.connect(intent: .join(code: room.code))
    try await eventually { host.room?.code == room.code }
    guest.connect(intent: .join(code: room.code))
    try await eventually { host.room?.players.count == 2 && guest.room?.players.count == 2 }
    host.send(.room(.addBot))
    host.send(.room(.addBot))
    try await eventually { host.room?.players.count == 4 }
    host.send(.room(.start))
    try await eventually { host.error != nil }
    host.error = nil
    guest.error = nil
    host.send(.ready(true))
    guest.send(.ready(true))
    try await eventually { host.canStart }
    host.send(.room(.start))
    try await eventually { host.snapshot?.phase == .playing }
    XCTAssertEqual(host.screen, "game")
    let startX = try XCTUnwrap(host.me?.x)
    host.movement(x: 1, y: 0)
    try await eventually { (host.me?.x ?? 0) > startX + 0.2 }
    host.clearInput()
    host.press(emote: 3)
    try await eventually { host.me?.emote == 3 }
    let hostID = try XCTUnwrap(host.playerID)
    _ = try await request(
      server, path: "/test/rooms/\(room.code)/players/\(hostID)/input",
      body: #"{"via":"client","steps":[{"dx":-1,"ticks":2},{}]}"#)
    let guestID = try XCTUnwrap(guest.playerID)
    guest.disconnect()
    try await eventually { host.room?.players.first { $0.id == guestID }?.connected == false }
    let resumed = GameClient(
      configuration: guestConfig, defaults: defaults, resumeStore: guestStore)
    defer { resumed.disconnect() }
    resumed.connect()
    try await eventually { resumed.snapshot != nil }
    XCTAssertEqual(resumed.playerID, guestID)
    XCTAssertEqual(resumed.room?.players.count, 4)
    XCTAssertEqual(resumed.room?.code, room.code)
    resumed.connect()
    resumed.connect()
    let clientsData = try await request(server, path: "/test/clients")
    struct Connections: Decodable {
      struct Client: Decodable { let id: String }
      let clients: [Client]
    }
    XCTAssertEqual(
      try JSONDecoder().decode(Connections.self, from: clientsData).clients.filter {
        $0.id == guestID
      }.count, 1)
    try await eventually(seconds: 40) { host.results != nil && resumed.results != nil }
    XCTAssertEqual(host.screen, "results")
    let results = try XCTUnwrap(host.results)
    XCTAssertEqual(results, resumed.results)
    XCTAssertGreaterThan(results.served, 0)
    let serverRoom = try JSONDecoder().decode(
      Room.self, from: await request(server, path: "/test/rooms/\(room.code)"))
    XCTAssertEqual(results, serverRoom.results)
    XCTAssertEqual(host.bestStars[results.levelId], results.stars)
    _ = try await request(
      server, path: "/test/rooms/\(room.code)/players/\(hostID)/command", body: #"{"cmd":"report"}"#
    )
    struct Reports: Decodable {
      struct Report: Decodable {
        let screen: String
        let results: Results?
      }
      let reports: [String: Report?]
    }
    var reported: Reports.Report?
    for _ in 0..<30 {
      let data = try await request(server, path: "/test/rooms/\(room.code)")
      reported = try JSONDecoder().decode(Reports.self, from: data).reports[hostID] ?? nil
      if reported != nil { break }
      try await Task.sleep(for: .milliseconds(50))
    }
    XCTAssertEqual(reported?.screen, "results")
    XCTAssertEqual(reported?.results, results)
    host.send(.room(.rematch))
    try await eventually {
      host.room?.phase == .lobby && host.results == nil && resumed.results == nil
    }
    XCTAssertEqual(host.screen, "lobby")
    XCTAssertFalse(host.ready)
    host.leave()
    resumed.leave()
    try await eventually { host.room == nil && resumed.room == nil }
    XCTAssertEqual(host.screen, "home")
  }

  @MainActor
  func testInvalidURLAndCancellingReconnectCannotCreateLaterSession() async throws {
    guard let server = ProcessInfo.processInfo.environment["PP_INTEGRATION_SERVER"] else {
      throw XCTSkip("Run test/native-integration.sh.")
    }
    let suite = "PanicPantryConnection-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let client = GameClient(
      configuration: LaunchConfiguration(
        environment: ["PP_SERVER": "invalid"], arguments: [], defaults: defaults),
      defaults: defaults, resumeStore: MemoryResumeStore())
    defer { client.disconnect() }
    client.connect()
    XCTAssertNotNil(client.error)
    XCTAssertEqual(client.connection, .idle)
    client.server = server.replacingOccurrences(of: "/ws", with: "/health")
    client.connect()
    try await eventually { client.connection == .reconnecting }
    client.disconnect()
    try await Task.sleep(for: .seconds(1))
    XCTAssertEqual(client.connection, .idle)
    XCTAssertNil(client.room)
  }

  @MainActor
  private func eventually(seconds: Double = 8, _ predicate: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !predicate() {
      if Date() > deadline { throw IntegrationError.timedOut }
      try await Task.sleep(for: .milliseconds(20))
    }
  }
  private func request(_ websocket: String, path: String, body: String? = nil) async throws -> Data
  {
    var parts = try XCTUnwrap(URLComponents(string: websocket))
    parts.scheme = parts.scheme == "wss" ? "https" : "http"
    parts.path = path
    var request = URLRequest(url: try XCTUnwrap(parts.url))
    request.httpMethod = body == nil ? "GET" : "POST"
    request.httpBody = body.map { Data($0.utf8) }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
    else {
      throw IntegrationError.http
    }
    return data
  }
  enum IntegrationError: Error { case timedOut, http }
}
