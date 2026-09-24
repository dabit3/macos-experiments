import Combine
import Foundation
import OSLog

@MainActor final class Session: ObservableObject {
  enum Connection: String { case offline, connecting, connected, reconnecting }
  @Published var connection: Connection = .offline
  @Published var error: String?
  @Published var room: RoomState?
  @Published var match: MatchReplica?
  @Published var latency = 0
  @Published var token = ""
  @Published var autopilot = false
  @Published var testPaused = false
  let profile: Profile
  let options: LaunchOptions
  var platform: String {
    #if os(macOS)
      "macos"
    #else
      "ios"
    #endif
  }
  var isHost: Bool { room?.players.first { $0.id == room?.you }?.host == true }
  private var socket: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var heartbeatTask: Task<Void, Never>?
  private var generation = UUID()
  private var activeServer = ""
  private var autoJoined = false
  private var autoStarted = false
  private var lastPacket = Date()
  private var awaitingResume = false
  private var tokenAccount: String {
    activeServer + (options["TEST"].map { "::test:\($0):\(platform):\(profile.data.name)" } ?? "")
  }
  init(profile: Profile, options: LaunchOptions = LaunchOptions()) {
    self.profile = profile
    self.options = options
    if let server = options["SERVER"] { profile.data.server = server }
    if let name = options["NAME"] { profile.data.name = name }
    if let theme = options["THEME"] { profile.data.theme = theme }
  }
  func connect() {
    disconnect()
    error = nil
    guard let url = URL(string: profile.data.server), ["ws", "wss"].contains(url.scheme ?? ""),
      url.host != nil
    else {
      error = "Enter a valid ws:// or wss:// server URL."
      return
    }
    if activeServer != profile.data.server {
      room = nil
      match = nil
      autoJoined = false
      activeServer = profile.data.server
      token = ResumeToken.read(server: tokenAccount) ?? ""
    }
    awaitingResume = room != nil
    let current = generation
    connection = .connecting
    receiveTask = Task { [weak self] in
      guard let self else { return }
      var failures = 0
      while !Task.isCancelled && current == self.generation {
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.maximumMessageSize = 8 * 1024 * 1024
        self.socket = socket
        socket.resume()
        self.lastPacket = Date()
        self.startHeartbeat(generation: current)
        do {
          var hello = ClientMessage(.hello)
          hello.v = 1
          hello.name = self.profile.data.name
          hello.platform = self.platform
          hello.ld = self.profile.data.loadout
          hello.token = self.token.isEmpty ? nil : self.token
          try await self.write(hello, to: socket)
          while !Task.isCancelled && current == self.generation {
            let packet = try await socket.receive()
            guard !Task.isCancelled, current == self.generation else { return }
            let data: Data
            switch packet {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: continue
            }
            let message = try JSONDecoder().decode(ServerMessage.self, from: data)
            self.lastPacket = Date()
            failures = 0
            self.handle(message)
          }
        } catch let error as DecodingError {
          guard current == self.generation else { return }
          self.error = "The server sent an incompatible message: \(error.localizedDescription)"
          self.disconnect()
          return
        } catch {
          guard !Task.isCancelled && current == self.generation else { return }
          self.error = "Connection interrupted: \(error.localizedDescription)"
        }
        self.heartbeatTask?.cancel()
        socket.cancel(with: .goingAway, reason: nil)
        self.socket = nil
        failures += 1
        if failures >= 8 {
          self.connection = .offline
          return
        }
        self.connection = .reconnecting
        self.awaitingResume = self.room != nil
        try? await Task.sleep(for: .seconds(min(15, pow(2, Double(failures - 1)))))
      }
    }
  }
  func disconnect() {
    generation = UUID()
    receiveTask?.cancel()
    receiveTask = nil
    heartbeatTask?.cancel()
    heartbeatTask = nil
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
    connection = .offline
  }
  private func startHeartbeat(generation: UUID) {
    heartbeatTask?.cancel()
    heartbeatTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(3))
        guard let self, !Task.isCancelled, self.generation == generation else { return }
        if Date().timeIntervalSince(self.lastPacket) > 12 {
          self.socket?.cancel(with: .goingAway, reason: nil)
          return
        }
        if self.awaitingResume && self.connection == .connected {
          self.awaitingResume = false
          self.room = nil
          self.match = nil
          self.error = "The server no longer has this room. Create or join a room to continue."
        }
        var ping = ClientMessage(.ping)
        ping.c = Int64(Date().timeIntervalSince1970 * 1000)
        await self.sendAwaited(ping)
      }
    }
  }
  private func write(_ message: ClientMessage, to socket: URLSessionWebSocketTask) async throws {
    let data = try JSONEncoder().encode(message)
    try await socket.send(.string(String(decoding: data, as: UTF8.self)))
  }
  func send(_ message: ClientMessage) {
    Task { await sendAwaited(message) }
  }
  func sendAwaited(_ message: ClientMessage) async {
    guard connection == .connected, let socket else { return }
    do { try await write(message, to: socket) } catch {
      self.error = "Could not send: \(error.localizedDescription)"
      socket.cancel(with: .goingAway, reason: nil)
    }
  }
  private func handle(_ message: ServerMessage) {
    switch message {
    case .welcome(let welcome):
      guard welcome.v == 1 else {
        error = "Server protocol \(welcome.v) is not supported."
        disconnect()
        return
      }
      error = nil
      token = welcome.token
      do { try ResumeToken.save(token, server: tokenAccount) } catch {
        Logger(subsystem: "com.lastfort", category: "session")
          .error("Resume token not persisted: \(error.localizedDescription, privacy: .public)")
      }
      connection = .connected
      if let warning = welcome.warning { error = warning }
      if !autoJoined, let code = options["ROOM"], !code.isEmpty, room == nil {
        autoJoined = true
        create(mode: SquadMode(rawValue: options["MODE"] ?? "") ?? .squads, code: code)
      }
    case .error(let failure):
      error = failure.message ?? failure.code
      if failure.code == "superseded" || failure.code == "version_mismatch" { disconnect() }
    case .pong(let pong):
      latency = max(0, Int(Int64(Date().timeIntervalSince1970 * 1000) - pong.c))
    case .room(let value):
      awaitingResume = false
      room = value
      if value.phase == "lobby" {
        match = nil
        if value.countdownMs == nil { autoStarted = false }
      }
      if options.auto && !autopilot { setAutopilot(true) }
      if isHost && options.autoStart > 0 && value.players.count >= options.autoStart
        && value.phase == "lobby" && value.countdownMs == nil && !autoStarted
      {
        autoStarted = true
        start(fill: value.maxPlayers)
      }
    case .start(let value):
      awaitingResume = false
      if value.resume != true { profile.data.matchEpoch = UUID().uuidString }
      match = MatchReplica(value)
      if let id = room?.you { match?.localID = id }
    case .you(let id): match?.localID = id
    case .snapshot(let snapshot): match?.apply(snapshot)
    case .end(let summary):
      guard let match else { return }
      match.summary = summary
      profile.data.record(
        summary, playerID: match.localID, server: activeServer, room: match.start.code, token: token
      )
      if options["TEST"] != nil { report(summary, match: match) }
    case .ack(let ack):
      if let error = ack.error { self.error = "Server control: \(error)" }
    case .unknown: break
    }
  }
  func create(mode: SquadMode, code: String? = nil, fast: Bool? = nil, seed: Int? = nil) {
    var message = ClientMessage(.createRoom)
    message.mode = mode
    message.code = code
    message.fast = fast ?? options.fast
    message.seed = seed ?? options["SEED"].flatMap(Int.init)
    send(message)
  }
  func join(_ code: String) {
    var message = ClientMessage(.joinRoom)
    message.code = code.uppercased().trimmingCharacters(in: .whitespaces)
    send(message)
  }
  func ready(_ value: Bool) {
    var message = ClientMessage(.ready)
    message.ready = value
    send(message)
  }
  func setMode(_ mode: SquadMode) {
    var message = ClientMessage(.setMode)
    message.mode = mode
    send(message)
  }
  func start(fill: Int) {
    var message = ClientMessage(.startMatch)
    message.fill = fill
    message.countdownMs = 3000
    send(message)
  }
  func returnToLobby() { send(ClientMessage(.returnToLobby)) }
  func leave() {
    send(ClientMessage(.leaveRoom))
    room = nil
    match = nil
    autopilot = false
    autoStarted = false
  }
  func updateIdentity() {
    var hello = ClientMessage(.hello)
    hello.name = profile.data.name
    send(hello)
    var loadout = ClientMessage(.setLoadout)
    loadout.ld = profile.data.loadout
    send(loadout)
  }
  func control(_ op: String, count: Int? = nil, on: Bool? = nil) {
    var message = ClientMessage(.testControl)
    message.op = op
    message.n = count
    message.on = on
    send(message)
  }
  func setAutopilot(_ enabled: Bool) {
    autopilot = enabled
    control("autopilot", on: enabled)
  }
  private func report(_ summary: MatchSummary, match: MatchReplica) {
    do {
      let json = try summary.jsonString()
      var hash: UInt32 = 0x811C_9DC5
      for unit in json.utf16 { hash = (hash ^ UInt32(unit)) &* 0x0100_0193 }
      var message = ClientMessage(.testControl)
      message.op = "report"
      message.platform = platform
      message.summary = json
      message.digest = String(hash, radix: 16)
      message.snapshots = match.snapshots
      message.test = options["TEST"]
      message.screen = "results"
      send(message)
    } catch { self.error = "Unable to report results: \(error.localizedDescription)" }
  }
}
