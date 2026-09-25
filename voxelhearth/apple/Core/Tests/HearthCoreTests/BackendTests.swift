import Foundation
import XCTest

@testable import HearthCore

private actor Peer {
  let socket: URLSessionWebSocketTask
  init(_ endpoint: URL) {
    socket = URLSession.shared.webSocketTask(with: endpoint)
    socket.resume()
  }
  func close() { socket.cancel(with: .normalClosure, reason: nil) }
  func send(_ message: ClientMessage) async throws {
    try await socket.send(.string(String(decoding: JSONEncoder().encode(message), as: UTF8.self)))
  }
  func wait(_ t: String, matching: @escaping @Sendable (ServerMessage) -> Bool = { _ in true })
    async throws -> ServerMessage
  {
    try await withThrowingTaskGroup(of: ServerMessage.self) { group in
      group.addTask { [socket] in
        while !Task.isCancelled {
          let message = try await socket.receive()
          let data: Data
          switch message {
          case .string(let value): data = Data(value.utf8)
          case .data(let value): data = value
          @unknown default: continue
          }
          let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
          if decoded.t == "error" && t != "error" {
            throw NSError(
              domain: "VoxelHearth", code: 1,
              userInfo: [NSLocalizedDescriptionKey: decoded.msg ?? "Server error"])
          }
          if decoded.t == t && matching(decoded) { return decoded }
        }
        throw CancellationError()
      }
      group.addTask { [socket] in
        try await Task.sleep(for: .seconds(12))
        socket.cancel(with: .goingAway, reason: nil)
        throw NSError(
          domain: "VoxelHearth", code: 2,
          userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(t)"])
      }
      defer { group.cancelAll() }
      return try await group.next()!
    }
  }
  func hello(_ name: String, token: String? = nil) async throws -> ServerMessage {
    var hello = ClientMessage(.hello)
    hello.name = name
    hello.platform = "macos"
    hello.version = 1
    hello.token = token
    try await send(hello)
    return try await wait("welcome")
  }
}

final class BackendTests: XCTestCase {
  func testRealServerMultiplayerResumeContainersAndRematch() async throws {
    guard let address = ProcessInfo.processInfo.environment["VH_INTEGRATION"],
      let endpoint = ServerAddress.parse(address)
    else {
      throw XCTSkip("Set VH_INTEGRATION=ws://127.0.0.1:8787/ws with the real Dart server running.")
    }
    let host = Peer(endpoint)
    let guest = Peer(endpoint)
    let welcome = try await host.hello("Native host")
    _ = try await guest.hello("Native guest")
    var create = ClientMessage(.createRoom)
    create.name = "Native protocol test"
    create.mode = "creative"
    create.seed = 424242
    create.bots = 1
    create.freezeTime = true
    create.spawnMobs = true
    try await host.send(create)
    let joined = try await host.wait("room_joined")
    let code = try XCTUnwrap(joined.code)
    XCTAssertEqual(joined.players?.filter { $0.bot == true }.count, 1)
    let x = Int(try XCTUnwrap(joined.x))
    let y = Int(try XCTUnwrap(joined.y))
    let z = Int(try XCTUnwrap(joined.z))
    var join = ClientMessage(.joinRoom)
    join.code = code
    try await guest.send(join)
    let guestJoined = try await guest.wait("room_joined")
    XCTAssertEqual(guestJoined.seed, 424242)
    let chunk = try await guest.wait("chunk")
    XCTAssertNotNil(chunk.cx)
    XCTAssertNotNil(chunk.edits)
    var ready = ClientMessage(.ready)
    ready.ready = true
    try await guest.send(ready)
    let readyState = try await host.wait("room_state") {
      $0.players?.contains { $0.name == "Native guest" && $0.ready == true } == true
    }
    XCTAssertEqual(readyState.players?.filter { $0.connected == true }.count, 3)
    try await host.send(ClientMessage(.startMatch))
    let phase = try await guest.wait("phase") { $0.phase == "playing" }
    XCTAssertEqual(phase.phase, "playing")
    var move = ClientMessage(.move)
    move.x = Double(x) + 0.5
    move.y = Double(y)
    move.z = Double(z) + 0.5
    move.vx = 0
    move.vy = 0
    move.vz = 0
    move.yaw = 0.2
    move.pitch = 0
    move.ground = true
    move.sneak = false
    move.sprint = false
    move.fly = false
    move.seq = 1
    try await host.send(move)
    let snapshot = try await guest.wait("snapshot") {
      $0.players?.contains { $0.id == welcome.playerId && abs(($0.yaw ?? 0) - 0.2) < 0.001 } == true
    }
    XCTAssertGreaterThanOrEqual(snapshot.players?.count ?? 0, 3)
    var chat = ClientMessage(.chat)
    chat.text = "Native wire roundtrip"
    try await host.send(chat)
    let line = try await guest.wait("chat_msg") { $0.text == "Native wire roundtrip" }
    XCTAssertEqual(line.from, "Native host")
    var give = ClientMessage(.give)
    give.id = 18
    give.count = 2
    give.slot = 0
    try await host.send(give)
    _ = try await host.wait("inventory") { $0.slots?.first?.id == 18 }
    var selected = ClientMessage(.selectSlot)
    selected.slot = 0
    try await host.send(selected)
    var place = ClientMessage.block(.place, x, y, z + 2)
    place.ny = 1
    try await host.send(place)
    let placed = try await guest.wait("block_set") { $0.id?.number == 18 }
    XCTAssertEqual(placed.z, Double(z + 2))
    try await host.send(.block(.interact, x, y, z + 2))
    _ = try await host.wait("open_ui") { $0.kind == "chest" }
    let chest = try await host.wait("container") { $0.kind == "chest" }
    XCTAssertEqual(chest.slots?.count, 27)
    var put = ClientMessage(.chestPut)
    put.toChest = true
    put.slot = 0
    put.cslot = 0
    try await host.send(put)
    _ = try await host.wait("container") { $0.slots?.first?.id == 18 }
    put.toChest = false
    put.slot = -1
    try await host.send(put)
    _ = try await host.wait("container") { $0.slots?.first?.isEmpty == true }
    try await host.send(ClientMessage(.closeUI))
    give.id = 17
    give.count = 1
    try await host.send(give)
    _ = try await host.wait("inventory") { $0.slots?.first?.id == 17 }
    try await host.send(.block(.place, x + 1, y, z + 2))
    _ = try await guest.wait("block_set") { $0.id?.number == 17 }
    try await host.send(.block(.interact, x + 1, y, z + 2))
    _ = try await host.wait("open_ui") { $0.kind == "kiln" }
    let kiln = try await host.wait("container") { $0.kind == "kiln" }
    XCTAssertNotNil(kiln.kiln)
    try await host.send(ClientMessage(.closeUI))
    var craft = ClientMessage(.craft)
    craft.n = 2
    craft.grid = [6, 0, 0, 0]
    craft.count = 1
    try await host.send(craft)
    _ = try await host.wait("effect") { $0.kind == "craft" }
    try await host.send(.block(.breakBlock, x, y, z + 2))
    _ = try await guest.wait("block_set") {
      $0.id?.number == 0 && $0.x == Double(x) && $0.z == Double(z + 2)
    }
    await host.close()
    let resumed = Peer(endpoint)
    let resumedWelcome = try await resumed.hello("Native host", token: welcome.token)
    XCTAssertEqual(resumedWelcome.playerId, welcome.playerId)
    let resumedRoom = try await resumed.wait("room_joined")
    XCTAssertEqual(resumedRoom.code, code)
    XCTAssertEqual(resumedRoom.host, welcome.playerId)
    try await resumed.send(ClientMessage(.endMatch))
    let result = try await guest.wait("phase") { $0.phase == "results" }
    XCTAssertNotNil(result.worldHash)
    XCTAssertNotNil(result.chatHash)
    XCTAssertGreaterThan(result.results?.first { $0.id == welcome.playerId }?.score ?? 0, 0)
    try await resumed.send(ClientMessage(.backToLobby))
    _ = try await guest.wait("phase") { $0.phase == "lobby" }
    try await resumed.send(ClientMessage(.startMatch))
    _ = try await guest.wait("phase") { $0.phase == "playing" }
    await resumed.close()
    await guest.close()
  }
}
