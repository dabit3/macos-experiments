import Foundation
import XCTest

@testable import LastfortKit

actor WirePeer {
  private let socket: URLSessionWebSocketTask
  init(url: URL) {
    socket = URLSession.shared.webSocketTask(with: url)
    socket.maximumMessageSize = 8 * 1024 * 1024
    socket.resume()
  }
  func close() { socket.cancel(with: .goingAway, reason: nil) }
  func send(_ message: ClientMessage) async throws {
    let text = String(decoding: try JSONEncoder().encode(message), as: UTF8.self)
    try await socket.send(.string(text))
  }
  func next(where predicate: @escaping @Sendable (ServerMessage) -> Bool) async throws
    -> ServerMessage
  {
    try await withThrowingTaskGroup(of: ServerMessage.self) { group in
      group.addTask { [socket] in
        while !Task.isCancelled {
          let packet = try await socket.receive()
          let data: Data
          switch packet {
          case .string(let text): data = Data(text.utf8)
          case .data(let bytes): data = bytes
          @unknown default: throw URLError(.cannotParseResponse)
          }
          let message = try JSONDecoder().decode(ServerMessage.self, from: data)
          if case .error(let error) = message { throw NSError(domain: error.code, code: 1) }
          if predicate(message) { return message }
        }
        throw CancellationError()
      }
      group.addTask { [socket] in
        try await Task.sleep(for: .seconds(25))
        socket.cancel(with: .goingAway, reason: nil)
        throw URLError(.timedOut)
      }
      defer { group.cancelAll() }
      let message = try await group.next()
      return try XCTUnwrap(message)
    }
  }
  func hello(name: String, platform: String, token: String? = nil) async throws -> Welcome {
    var message = ClientMessage(.hello)
    message.v = 1
    message.name = name
    message.platform = platform
    message.ld = Loadout()
    message.token = token
    try await send(message)
    guard
      case .welcome(let welcome) = try await next(where: {
        if case .welcome = $0 { return true }
        return false
      })
    else {
      throw URLError(.cannotParseResponse)
    }
    return welcome
  }
  func control(_ operation: String, count: Int? = nil, on: Bool? = nil) async throws -> TestAck {
    var message = ClientMessage(.testControl)
    message.op = operation
    message.n = count
    message.on = on
    message.every = 10
    try await send(message)
    guard
      case .ack(let ack) = try await next(where: {
        if case .ack(let ack) = $0 { return ack.op == operation }
        return false
      })
    else { throw URLError(.cannotParseResponse) }
    return ack
  }
}
final class LiveServerTests: XCTestCase {
  func testNativeClientsCompleteResumeAndRematchAgainstDart() async throws {
    guard let address = ProcessInfo.processInfo.environment["LASTFORT_TEST_SERVER"],
      let url = URL(string: address)
    else {
      throw XCTSkip("Run test/multiplayer-e2e.sh to exercise a real Dart server")
    }
    let host = WirePeer(url: url)
    let guest = WirePeer(url: url)
    _ = try await host.hello(name: "Native Mac", platform: "macos")
    let guestIdentity = try await guest.hello(name: "Native iPad", platform: "ios")
    var create = ClientMessage(.createRoom)
    create.code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(7))
    create.mode = .squads
    create.fast = true
    create.seed = 4242
    try await host.send(create)
    guard
      case .room(let firstRoom) = try await host.next(where: {
        if case .room = $0 { return true }
        return false
      })
    else {
      return XCTFail("Host did not create a room")
    }
    var join = ClientMessage(.joinRoom)
    join.code = firstRoom.code
    try await guest.send(join)
    guard
      case .room(let joined) = try await guest.next(where: {
        if case .room = $0 { return true }
        return false
      })
    else {
      return XCTFail("Guest did not join")
    }
    XCTAssertEqual(joined.players.count, 2)
    let guestID = try XCTUnwrap(joined.you)
    _ = try await host.control("autopilot", on: true)
    _ = try await guest.control("autopilot", on: true)
    var start = ClientMessage(.startMatch)
    start.fill = 16
    start.countdownMs = 0
    try await host.send(start)
    guard
      case .start(let matchStart) = try await host.next(where: {
        if case .start = $0 { return true }
        return false
      })
    else {
      return XCTFail("Match did not start")
    }
    XCTAssertEqual(matchStart.players.count, 16)
    _ = try await guest.next(where: {
      if case .start = $0 { return true }
      return false
    })
    _ = try await host.control("pause")
    let stepped = try await host.control("step", count: 300)
    XCTAssertGreaterThan(try XCTUnwrap(stepped.tick), 299)
    var input = ClientMessage(.input)
    input.f = InputFrame(
      seq: 15, mx: 0.707, my: -0.707, aim: 0.3, fire: true, sprint: false,
      act: [
        .init(.buildMode, value: "on"), .init(.setPiece, value: "wall"),
        .init(.setMaterial, value: "wood"), .init(.place), .init(.edit, value: "door"),
        .init(.select, slot: 1), .init(.interact), .init(.reload), .init(.emote),
      ])
    try await guest.send(input)
    await guest.close()
    let resumed = WirePeer(url: url)
    let identity = try await resumed.hello(
      name: "Native iPad", platform: "ios", token: guestIdentity.token)
    XCTAssertEqual(identity.token, guestIdentity.token)
    guard
      case .start(let restored) = try await resumed.next(where: {
        if case .start = $0 { return true }
        return false
      })
    else {
      return XCTFail("Missing resumed match")
    }
    XCTAssertEqual(restored.resume, true)
    guard
      case .you(let restoredID) = try await resumed.next(where: {
        if case .you = $0 { return true }
        return false
      })
    else {
      return XCTFail("Missing restored player")
    }
    XCTAssertEqual(restoredID, guestID)
    var finish = ClientMessage(.testControl)
    finish.op = "step"
    finish.n = 20000
    finish.every = 10
    try await host.send(finish)
    guard
      case .end(let hostSummary) = try await host.next(where: {
        if case .end = $0 { return true }
        return false
      }),
      case .end(let guestSummary) = try await resumed.next(where: {
        if case .end = $0 { return true }
        return false
      })
    else {
      return XCTFail("Match did not end")
    }
    XCTAssertEqual(try hostSummary.jsonString(), try guestSummary.jsonString())
    XCTAssertNotNil(hostSummary.winnerTeam)
    XCTAssertGreaterThan(hostSummary.stormPhase, 0)
    XCTAssertGreaterThan(hostSummary.players.reduce(0) { $0 + $1.harvested }, 0)
    XCTAssertGreaterThan(hostSummary.players.reduce(0) { $0 + $1.built }, 0)
    let canonical = try await host.control("summary")
    XCTAssertEqual(try canonical.summary?.jsonString(), try hostSummary.jsonString())
    try await host.send(ClientMessage(.returnToLobby))
    _ = try await host.next(where: {
      if case .room(let room) = $0 { return room.phase == "lobby" }
      return false
    })
    try await host.send(start)
    guard
      case .start(let second) = try await host.next(where: {
        if case .start = $0 { return true }
        return false
      })
    else {
      return XCTFail("Rematch did not launch")
    }
    XCTAssertEqual(second.tick, 0)
    XCTAssertEqual(second.players.count, 16)
    await host.close()
    await resumed.close()
  }
}
