import Foundation
import Observation

enum ConnectionState: String { case idle, connecting, connected, reconnecting, failed }

struct VisualEvent: Identifiable {
  let id = UUID()
  let event: GameEvent
  let date: Date
}

@MainActor @Observable
final class GameClient {
  var connection = ConnectionState.idle
  var error: String?
  var notice: String?
  var room: Room?
  var snapshot: Snapshot?
  var previousSnapshot: Snapshot?
  var snapshotDate = Date()
  var results: Results?
  var resultsMatch: Int?
  var playerID: String?
  var rtt = 0
  var levels: [Level] = []
  var bestStars: [String: Int]
  var effects: [VisualEvent] = []
  var server: String
  var name: String
  var showHelp = false
  var showMenu = false
  var showEmotes = false
  var theme: String { didSet { defaults.set(theme, forKey: "theme") } }
  var showTouch: Bool { didSet { defaults.set(showTouch, forKey: "showTouch") } }

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let resumeStore: ResumeStore
  @ObservationIgnored private let session: URLSession
  @ObservationIgnored private var socket: URLSessionWebSocketTask?
  @ObservationIgnored private var socketURL: URL?
  @ObservationIgnored private var receiver: Task<Void, Never>?
  @ObservationIgnored private var sender: Task<Void, Never>?
  @ObservationIgnored private var ticker: Task<Void, Never>?
  @ObservationIgnored private var watchdog: Task<Void, Never>?
  @ObservationIgnored private var reconnect: Task<Void, Never>?
  @ObservationIgnored private var generation = UUID()
  @ObservationIgnored private var token: String?
  @ObservationIgnored private var tokenServer: String?
  @ObservationIgnored private var helloName: String?
  @ObservationIgnored private var attempt = 0
  @ObservationIgnored private var stopped = true
  @ObservationIgnored private var lastReceived = Date()
  @ObservationIgnored private var pending: ClientMessage?
  @ObservationIgnored private var held = ChefInput()
  @ObservationIgnored private var script: [ScriptStep] = []
  @ObservationIgnored private var ticksLeft = 0

  init(
    configuration: LaunchConfiguration = LaunchConfiguration(),
    defaults: UserDefaults = .standard, resumeStore: ResumeStore = KeychainResumeStore()
  ) {
    server = configuration.server
    name = configuration.name
    self.defaults = defaults
    self.resumeStore = resumeStore
    bestStars = defaults.dictionary(forKey: "bestStars") as? [String: Int] ?? [:]
    theme = defaults.string(forKey: "theme") ?? "system"
    showTouch =
      defaults.object(forKey: "showTouch") as? Bool ?? (LaunchConfiguration.platform == "ios")
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 12
    session = URLSession(configuration: config)
    do { levels = try LevelCatalogue.load() } catch {
      self.error = "Unable to load kitchen layouts: \(error.localizedDescription)"
    }
  }

  var level: Level? { levels.first { $0.id == room?.level } }
  var me: Chef? { snapshot?.chefs.first { $0.id == playerID } }
  var isHost: Bool { playerID != nil && room?.hostId == playerID }
  var ready: Bool { room?.players.first { $0.id == playerID }?.ready ?? false }
  var canStart: Bool {
    guard let room else { return false }
    let humans = room.players.filter { !$0.bot && $0.connected }
    return !humans.isEmpty && humans.allSatisfy(\.ready)
  }
  var screen: String {
    guard room != nil else { return "home" }
    if results != nil && (snapshot == nil || snapshot?.phase == .finished) { return "results" }
    return snapshot == nil || snapshot?.phase == .lobby ? "lobby" : "game"
  }

  func connect(intent: ClientMessage? = nil) {
    guard let url = LaunchConfiguration.serverURL(server) else {
      error = "Enter a valid ws:// or wss:// server URL, for example ws://192.168.1.10:8787/ws."
      return
    }
    let canonical = url.absoluteString
    name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(18))
    if name.isEmpty { name = "Chef" }
    if socketURL == url && name == helloName
      && [.connected, .connecting, .reconnecting].contains(connection)
    {
      if let intent {
        if connection == .connected { send(intent) } else { pending = intent }
      }
      return
    }
    cancelTasks()
    server = canonical
    defaults.set(server, forKey: "server")
    defaults.set(name, forKey: "chefName")
    token = resumeStore.read(server: server) ?? (tokenServer == server ? token : nil)
    tokenServer = server
    pending = intent
    attempt = 0
    stopped = false
    open(url)
  }

  private func open(_ url: URL) {
    cancelTasks()
    let id = generation
    connection = attempt == 0 ? .connecting : .reconnecting
    lastReceived = Date()
    let task = session.webSocketTask(with: url)
    socket = task
    socketURL = url
    task.resume()
    helloName = name
    send(.hello(name: name, platform: LaunchConfiguration.platform, token: token))
    receiver = Task { [weak self] in
      do {
        while !Task.isCancelled {
          let frame = try await task.receive()
          guard let self, self.generation == id else { return }
          let data: Data
          switch frame {
          case .data(let value): data = value
          case .string(let value): data = Data(value.utf8)
          @unknown default: continue
          }
          let message = try JSONDecoder().decode(ServerMessage.self, from: data)
          self.lastReceived = Date()
          self.apply(message)
        }
      } catch {
        self?.failed(error.localizedDescription, generation: id)
      }
    }
    watchdog = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(2)) } catch { return }
        guard let self, self.generation == id else { return }
        if Date().timeIntervalSince(self.lastReceived) > 12 {
          self.failed("The server stopped responding.", generation: id)
          return
        }
        if self.connection == .connected { self.send(.ping(Self.milliseconds)) }
      }
    }
  }

  func send(_ message: ClientMessage) {
    guard let socket else { return }
    let id = generation
    let previous = sender
    sender = Task { [weak self] in
      await previous?.value
      guard let self, !Task.isCancelled, self.generation == id else { return }
      do {
        let data = try JSONEncoder().encode(message)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
      } catch {
        self.failed(error.localizedDescription, generation: id)
      }
    }
  }

  private func failed(_ message: String, generation id: UUID) {
    guard generation == id, !stopped else { return }
    cancelTasks()
    error = message
    held = ChefInput()
    script.removeAll()
    ticksLeft = 0
    attempt += 1
    guard attempt <= 8, let url = LaunchConfiguration.serverURL(server) else {
      connection = .failed
      return
    }
    connection = .reconnecting
    let delay = min(8.0, 0.4 * pow(2, Double(attempt - 1)))
    reconnect = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      guard let self, !self.stopped else { return }
      self.open(url)
    }
  }

  private func cancelTasks() {
    generation = UUID()
    receiver?.cancel()
    sender?.cancel()
    ticker?.cancel()
    watchdog?.cancel()
    reconnect?.cancel()
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
  }

  func disconnect() {
    stopped = true
    cancelTasks()
    socketURL = nil
    connection = .idle
    held = ChefInput()
    script.removeAll()
    ticksLeft = 0
    pending = nil
  }

  func leave() {
    clearInput()
    if connection == .connected {
      send(.room(.leave))
    } else {
      disconnect()
      room = nil
      snapshot = nil
      previousSnapshot = nil
      results = nil
      try? resumeStore.write(nil, server: server)
      token = nil
    }
    showMenu = false
  }

  private func apply(_ message: ServerMessage) {
    switch message {
    case .welcome(let welcome):
      guard welcome.protocol == 1 else {
        disconnect()
        connection = .failed
        error = "This server uses an unsupported protocol."
        return
      }
      let hadRoom = room != nil
      playerID = welcome.playerId
      token = welcome.token
      connection = .connected
      error = nil
      attempt = 0
      do { try resumeStore.write(welcome.token, server: server) } catch {
        notice = error.localizedDescription
      }
      if !welcome.resumed {
        room = nil
        snapshot = nil
        previousSnapshot = nil
        results = nil
        if hadRoom { error = "Your kitchen is no longer available. Host or join another kitchen." }
      }
      if let pending, !welcome.resumed { send(pending) }
      self.pending = nil
      startTicker(seconds: max(0.02, min(0.1, welcome.tickSeconds)))
    case .room(let next):
      if room?.code != next?.code || next?.phase == .lobby {
        snapshot = nil
        previousSnapshot = nil
        results = nil
        resultsMatch = nil
        effects.removeAll()
        clearInput()
      }
      room = next
      if let token { try? resumeStore.write(token, server: server) }
      if next == nil { showMenu = false }
    case .snapshot(let code, let next):
      guard room?.code == code else { return }
      previousSnapshot = snapshot
      snapshot = next
      snapshotDate = Date()
      effects.removeAll { Date().timeIntervalSince($0.date) > 2 }
      effects.append(contentsOf: (next.events ?? []).map { VisualEvent(event: $0, date: Date()) })
    case .results(let code, let match, let result):
      guard room?.code == code else { return }
      results = result
      resultsMatch = match
      bestStars[result.levelId] = max(bestStars[result.levelId] ?? 0, result.stars)
      defaults.set(bestStars, forKey: "bestStars")
      clearInput()
    case .pong(let timestamp): rtt = max(0, Int(Self.milliseconds - timestamp))
    case .error(_, let message): error = message
    case .testInput(let steps): script.append(contentsOf: steps)
    case .testCommand(let command): handle(command)
    case .unknown: break
    }
  }

  private func startTicker(seconds: Double) {
    ticker?.cancel()
    let id = generation
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
        guard let self, self.generation == id else { return }
        if self.room == nil { continue }
        if self.ticksLeft == 0 && !self.script.isEmpty {
          let step = self.script.removeFirst()
          self.held = step.input.held
          self.ticksLeft = step.ticks
          self.send(.input(step.input))
        } else {
          self.send(.input(self.held))
        }
        if self.ticksLeft > 0 {
          self.ticksLeft -= 1
          if self.ticksLeft == 0 && self.script.isEmpty { self.held = ChefInput() }
        }
      }
    }
  }

  func movement(x: Double, y: Double) {
    let length = max(1, hypot(x, y))
    held.dx = x / length
    held.dy = y / length
    if room != nil { send(.input(held)) }
  }
  func action(_ pressed: Bool) {
    held.action = pressed
    if room != nil { send(.input(held)) }
  }
  func press(
    interact: Bool = false, dash: Bool = false, emote: Int? = nil, target: (Int, Int)? = nil
  ) {
    guard room != nil, connection == .connected else { return }
    var input = held
    input.interact = interact
    input.dash = dash
    input.emote = emote
    if interact, let me {
      input.targetX = target?.0 ?? Int(floor(me.x)) + me.facing.dx
      input.targetY = target?.1 ?? Int(floor(me.y)) + me.facing.dy
    }
    send(.input(input))
  }
  func clearInput() {
    held = ChefInput()
    script.removeAll()
    ticksLeft = 0
    if room != nil { send(.input(held)) }
  }
  func report() {
    let stars = level.map { level in
      level.thresholds(players: room?.players.count ?? 1).filter { (snapshot?.score ?? 0) >= $0 }
        .count
    }
    send(
      .report(
        ClientReport(
          platform: LaunchConfiguration.platform, screen: screen,
          phase: snapshot?.phase.rawValue ?? room?.phase.rawValue ?? "none",
          code: room?.code, tick: snapshot?.tick, score: snapshot?.score,
          stars: stars, results: results, resultsMatch: resultsMatch,
          lastError: error, rtt: rtt)))
  }
  private func handle(_ command: TestCommand) {
    switch command.cmd {
    case "report": report()
    case "ready": send(.ready(command.ready ?? true))
    case "start": send(.room(.start))
    case "rematch": send(.room(.rematch))
    case "addBot": send(.room(.addBot))
    case "removeBot": send(.room(.removeBot))
    case "setLevel": if let level = command.level { send(.setLevel(level)) }
    case "emote": if let index = command.index { press(emote: index) }
    case "clearInput": clearInput()
    case "leave": leave()
    case "join": if let code = command.code { send(.join(code: code)) }
    case "host": send(.create(level: command.level))
    case "theme": theme = command.mode ?? "system"
    case "howto": showHelp = true
    case "dismiss":
      showHelp = false
      showMenu = false
      showEmotes = false
    default: break
    }
  }
  private static var milliseconds: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
