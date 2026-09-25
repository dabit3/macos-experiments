import BrickfolkCore
import Darwin
import Foundation

struct ProbeFailure: Error, LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

@MainActor
final class Peer {
  let socket: WebSocketConnection
  var welcome: Welcome?
  var gameFrames = 0
  init(_ url: URL) { socket = WebSocketConnection(url: url) }
  func send(_ command: Command) async throws { try await socket.send(command) }
  func wait(_ label: String, timeout: Double = 30, accepting: (ServerMessage) -> Bool) async throws
    -> ServerMessage
  {
    let watchdog = Task { [socket] in
      try? await Task.sleep(for: .seconds(timeout))
      if !Task.isCancelled { await socket.close() }
    }
    defer { watchdog.cancel() }
    while true {
      let message = try await socket.receive()
      if case .welcome(let value) = message { welcome = value }
      if case .game = message { gameFrames += 1 }
      if accepting(message) { return message }
      if case .error(let error) = message {
        throw ProbeFailure(message: "\(label): \(error.message)")
      }
    }
  }
  func signIn(name: String?, token: String? = nil, platform: String) async throws -> Welcome {
    try await send(.hello(name: name, token: token, platform: platform))
    let message = try await wait("welcome") {
      if case .welcome = $0 { return true }
      return false
    }
    guard case .welcome(let welcome) = message else {
      throw ProbeFailure(message: "Missing welcome")
    }
    return welcome
  }
}

@main
struct ProtocolProbe {
  @MainActor
  static func main() async {
    do { try await run() } catch {
      FileHandle.standardError.write(Data("FAIL \(error)\n".utf8))
      exit(1)
    }
  }
  @MainActor
  static func run() async throws {
    let server = CommandLine.arguments.dropFirst().first ?? "ws://127.0.0.1:8080/ws"
    let url = try Endpoint.validated(server)
    let content = try GameContent.load()
    let suffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6))
    var host = Peer(url)
    let guest = Peer(url)
    let hostWelcome = try await host.signIn(name: "Host\(suffix)", platform: "macos")
    let guestWelcome = try await guest.signIn(name: "Guest\(suffix)", platform: "ios")
    let id = hostWelcome.player.id
    try require(hostWelcome.protocolVersion == 1, "Protocol version mismatch")
    try await host.send(.daily)
    let dailyMessage = try await host.wait("daily reward") {
      if case .daily = $0 { return true }
      return false
    }
    guard case .daily(let daily) = dailyMessage else {
      throw ProbeFailure(message: "Missing daily result")
    }
    try require(daily.claimed && daily.reward == 25, "Daily reward failed")
    try await host.send(.daily)
    _ = try await host.wait("daily cooldown") {
      if case .daily(let daily) = $0 { return !daily.claimed }
      return false
    }
    try await host.send(.buy("face_grin"))
    _ = try await host.wait("shop ownership") {
      if case .playerUpdated(let player) = $0 { return player.owned.contains("face_grin") }
      return false
    }
    var avatar = hostWelcome.player.avatar
    avatar.face = "face_grin"
    avatar.torsoColor = 0xFF8E_5CF7
    try await host.send(.avatar(avatar))
    _ = try await host.wait("avatar save") {
      if case .playerUpdated(let player) = $0 { return player.avatar == avatar }
      return false
    }
    try await host.send(.friend(.request, guestWelcome.player.name))
    _ = try await guest.wait("friend invitation") {
      if case .friends(let friends) = $0 { return friends.incoming.contains { $0.id == id } }
      return false
    }
    try await guest.send(.friend(.accept, id))
    _ = try await host.wait("friend acceptance") {
      if case .friends(let friends) = $0 {
        return friends.friends.contains { $0.id == guestWelcome.player.id }
      }
      return false
    }
    try await host.send(.partyCreate(nil))
    let partyMessage = try await host.wait("party creation") {
      if case .party(.some) = $0 { return true }
      return false
    }
    guard case .party(let party?) = partyMessage else { throw ProbeFailure(message: "No party") }
    try await guest.send(.partyJoin(party.code))
    _ = try await host.wait("party join") {
      if case .party(let party?) = $0 { return party.members.count == 2 }
      return false
    }
    try await host.send(.chat(.party, "Native party hello"))
    _ = try await guest.wait("party chat") {
      if case .chat(let chat) = $0 {
        return chat.text == "Native party hello" && chat.channel == .party
      }
      return false
    }
    try await host.send(.rate(.obby, true))
    try await host.send(.places)
    _ = try await host.wait("place vote") {
      if case .places(let listings, _) = $0 {
        return listings.contains { $0.kind == .obby && $0.myVote == true }
      }
      return false
    }
    try await host.send(.profile(guestWelcome.player.id))
    _ = try await host.wait("profile lookup") {
      if case .profile(let profile) = $0 { return profile.id == guestWelcome.player.id }
      return false
    }
    try await host.send(.roomJoin("0000"))
    _ = try await host.wait("invalid room error") {
      if case .error(let error) = $0 { return error.code == "not_found" }
      return false
    }
    print(
      "PASS hub: welcome, rewards/cooldown, shop, avatar, friends, party/chat, ratings, profiles, visible protocol errors"
    )
    for experience in Experience.allCases {
      try await host.send(.partyLaunch(experience, bots: 2))
      let roomMessage = try await host.wait("room creation") {
        if case .room(let room?, _, _) = $0 { return room.experience == experience }
        return false
      }
      guard case .room(let room?, _, _) = roomMessage else {
        throw ProbeFailure(message: "No room")
      }
      _ = try await guest.wait("party room") {
        if case .room(let value?, _, _) = $0 { return value.code == room.code }
        return false
      }
      if experience == .obby {
        await host.socket.close()
        host = Peer(url)
        let resumed = try await host.signIn(name: nil, token: hostWelcome.token, platform: "macos")
        try require(
          resumed.player.id == id && resumed.roomCode == room.code,
          "Resume changed identity or lost seat")
        _ = try await host.wait("resumed room") {
          if case .room(let value?, _, _) = $0 {
            return value.code == room.code && value.members.filter { $0.id == id }.count == 1
          }
          return false
        }
        print("PASS token reconnect: same identity, one seat, restored room")
      }
      try await host.send(.chat(.room, "Ready in \(experience.rawValue)"))
      _ = try await guest.wait("room chat") {
        if case .chat(let chat) = $0 { return chat.channel == .room }
        return false
      }
      try await host.send(.ready(true))
      try await guest.send(.ready(true))
      _ = try await host.wait("playing phase", timeout: 15) {
        if case .room(let value?, _, _) = $0 { return value.phase == .playing }
        return false
      }
      let pilot = AutomationPilot(name: hostWelcome.player.name)
      let deadline = Task { [socket = host.socket] in
        try? await Task.sleep(for: .seconds(240))
        if !Task.isCancelled { await socket.close() }
      }
      var hostResult: MatchResults?
      var observedFrame = false
      while hostResult == nil {
        let message = try await host.socket.receive()
        switch message {
        case .game(let frame):
          observedFrame = true
          if let input = pilot.decide(frame: frame, id: id, content: content) {
            try await host.send(.input(input))
          }
        case .results(let result, _): hostResult = result
        case .error(let error): throw error
        default: break
        }
      }
      deadline.cancel()
      let guestResultMessage = try await guest.wait("guest result", timeout: 30) {
        if case .results = $0 { return true }
        return false
      }
      guard let result = hostResult, case .results(let guestResult, _) = guestResultMessage else {
        throw ProbeFailure(message: "Missing results")
      }
      try require(observedFrame, "No live game snapshots")
      try require(
        result.checksum == guestResult.checksum && result.checksum == result.computedChecksum,
        "Players disagree on result")
      try require(result.entries.count == 4, "Expected two humans and two bots")
      print(
        "PASS \(experience.rawValue): live snapshots, native input, authoritative results, shared checksum \(result.checksum)"
      )
      _ = try await host.wait("rematch lobby", timeout: 35) {
        if case .room(let value?, _, _) = $0 { return value.phase == .lobby && value.round >= 1 }
        return false
      }
      try await host.send(.ready(true))
      try await guest.send(.ready(true))
      _ = try await host.wait("rematch playing", timeout: 15) {
        if case .room(let value?, _, _) = $0 { return value.phase == .playing }
        return false
      }
      print("PASS \(experience.rawValue) rematch: lobby → ready → countdown → playing")
      try await host.send(.roomLeave)
      try await guest.send(.roomLeave)
      _ = try await host.wait("room leave") {
        if case .room(nil, _, _) = $0 { return true }
        return false
      }
      _ = try await guest.wait("guest leave") {
        if case .room(nil, _, _) = $0 { return true }
        return false
      }
    }
    try await host.send(.partyLeave)
    _ = try await host.wait("party leave") {
      if case .party(nil) = $0 { return true }
      return false
    }
    await host.socket.close()
    await guest.socket.close()
    print("PASS all native URLSessionWebSocketTask protocol integration checks")
  }
  private static func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ProbeFailure(message: message) }
  }
}
