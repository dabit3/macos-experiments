import Combine
import Foundation

enum ConnectionStatus: String { case offline, connecting, online, reconnecting }

@MainActor
final class GameClient: ObservableObject {
  @Published private(set) var status: ConnectionStatus = .offline
  @Published private(set) var room: RoomState?
  @Published private(set) var game: GameState?
  @Published private(set) var chats: [ChatMessage] = []
  @Published private(set) var playerID: String?
  @Published private(set) var lastEvent: GameEvent?
  @Published private(set) var eventSerial = 0
  @Published private(set) var selectionSerial = 0
  @Published private(set) var pingMs = 0
  @Published var error: String?
  @Published var notice: String?
  @Published var theme: String
  var server: String
  var name: String
  let testID: String?
  private(set) var serverTestMode = false
  private let store: ResumeStore
  private let session = URLSession(configuration: .ephemeral)
  private var socket: URLSessionWebSocketTask?
  private var receiver: Task<Void, Never>?
  private var heartbeat: Task<Void, Never>?
  private var handshake: Task<Void, Never>?
  private var reconnect: Task<Void, Never>?
  private var sender: Task<Void, Never>?
  private var generation = UUID()
  private var attempt = 0
  private var wantsConnection = false
  private var resumeToken: String?
  private var pendingEntry: ClientCommand?
  private var offset: Int64 = 0
  private var lastPong: Int64 = 0

  init(
    configuration: AppConfiguration = AppConfiguration(), store: ResumeStore = KeychainResumeStore()
  ) {
    server = configuration.server
    name = configuration.name
    testID = configuration.testID
    theme = configuration.theme
    self.store = store
  }
  var me: PlayerInfo? { room?.player(playerID) }
  var mySeat: Seat? { me?.seat }
  var isHost: Bool { playerID != nil && room?.host == playerID }
  var online: Bool { status == .online }
  static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
  var serverNow: Int64 { Self.now + offset }

  static func validatedURL(_ value: String) -> URL? {
    guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
      ["ws", "wss"].contains(url.scheme?.lowercased() ?? ""),
      let host = url.host, !host.isEmpty, url.user == nil, url.password == nil
    else { return nil }
    return url
  }

  func connect(url: String? = nil, name: String? = nil, entry: ClientCommand? = nil) {
    let address = url ?? server
    guard let parsed = Self.validatedURL(address) else {
      error = "Enter a valid ws:// or wss:// server address, without embedded credentials."
      return
    }
    if online && parsed.absoluteString == server && (name == nil || name == self.name) {
      if let entry { send(entry) }
      return
    }
    let changedServer = parsed.absoluteString != server
    stopTransport()
    if changedServer {
      room = nil
      game = nil
      chats = []
      resumeToken = nil
    }
    server = parsed.absoluteString
    self.name = String(
      (name ?? self.name).trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
    if self.name.isEmpty { self.name = "Player" }
    UserDefaults.standard.set(server, forKey: "server")
    UserDefaults.standard.set(self.name, forKey: "name")
    if resumeToken == nil {
      do { resumeToken = try store.load(server: server) } catch {
        notice = error.localizedDescription
      }
    }
    pendingEntry = entry
    attempt = 0
    wantsConnection = true
    error = nil
    open(parsed)
  }

  func disconnect(forget: Bool = false) {
    wantsConnection = false
    pendingEntry = nil
    stopTransport()
    status = .offline
    if forget {
      resumeToken = nil
      room = nil
      game = nil
      chats = []
      playerID = nil
      do { try store.save(nil, server: server) } catch { notice = error.localizedDescription }
    }
  }

  func retry() { connect() }

  func cancelPremove() {
    selectionSerial += 1
    if online, mySeat != nil, game?.result == nil { send(.premove(nil)) }
  }

  private func stopTransport() {
    generation = UUID()
    reconnect?.cancel()
    reconnect = nil
    receiver?.cancel()
    receiver = nil
    heartbeat?.cancel()
    heartbeat = nil
    handshake?.cancel()
    handshake = nil
    sender?.cancel()
    sender = nil
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
  }

  private func open(_ url: URL) {
    stopTransport()
    let current = generation
    status = attempt == 0 && room == nil ? .connecting : .reconnecting
    let task = session.webSocketTask(with: URLRequest(url: url, timeoutInterval: 8))
    socket = task
    task.resume()
    #if os(macOS)
      let platform = "macos"
    #else
      let platform = "ios"
    #endif
    transmit(
      ClientCommand.hello(name: name, platform: platform, resumeToken: resumeToken, testId: testID))
    receiver = Task { [weak self] in
      do {
        while !Task.isCancelled {
          let frame = try await task.receive()
          guard let self, self.generation == current else { return }
          let data: Data
          switch frame {
          case .string(let text): data = Data(text.utf8)
          case .data(let bytes): data = bytes
          @unknown default: continue
          }
          do { self.receive(try JSONDecoder().decode(ServerMessage.self, from: data)) } catch {
            self.error = "The server sent an incompatible message: \(error.localizedDescription)"
          }
        }
      } catch {
        self?.failed(current, message: "Connection lost: \(error.localizedDescription)")
      }
    }
    handshake = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(8)) } catch { return }
      self?.failed(
        current,
        message:
          "The server did not complete the handshake. Check the address and protocol version.")
    }
  }

  private func failed(_ current: UUID, message: String) {
    guard generation == current, wantsConnection else { return }
    stopTransport()
    error = message
    guard attempt < 6, let url = Self.validatedURL(server) else {
      status = .offline
      pendingEntry = nil
      error = "\(message) Automatic retry stopped. Choose Reconnect to try again."
      return
    }
    attempt += 1
    status = .reconnecting
    let delay = min(8.0, 0.4 * pow(2.0, Double(attempt)))
    reconnect = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      guard let self, self.wantsConnection else { return }
      self.open(url)
    }
  }

  func send(_ command: ClientCommand) {
    guard online else {
      error = "You are offline. Reconnect before sending an action."
      return
    }
    error = nil
    transmit(command)
  }

  private func transmit<T: Encodable>(_ payload: T) {
    guard let socket else { return }
    let current = generation
    do {
      let data = try JSONEncoder().encode(payload)
      let text = String(decoding: data, as: UTF8.self)
      let previous = sender
      sender = Task { [weak self] in
        await previous?.value
        guard !Task.isCancelled, self?.generation == current else { return }
        do { try await socket.send(.string(text)) } catch {
          self?.failed(
            current, message: "Could not send to the server: \(error.localizedDescription)")
        }
      }
    } catch { self.error = "Could not encode command: \(error.localizedDescription)" }
  }

  private func receive(_ message: ServerMessage) {
    switch message {
    case .welcome(let welcome):
      guard welcome.v == 1 else {
        disconnect()
        error = "Unsupported server protocol \(welcome.v)."
        return
      }
      handshake?.cancel()
      handshake = nil
      if welcome.room == nil {
        room = nil
        game = nil
        chats = []
      }
      playerID = welcome.playerId
      resumeToken = welcome.resumeToken
      do { try store.save(welcome.resumeToken, server: server) } catch {
        notice = error.localizedDescription
      }
      offset = welcome.serverTime - Self.now
      serverTestMode = welcome.testMode
      status = .online
      attempt = 0
      error = nil
      lastPong = Self.now
      if let entry = pendingEntry { transmit(entry) }
      pendingEntry = nil
      beginHeartbeat()
    case .pong(let pong):
      pingMs = max(0, Int(Self.now - pong.t))
      offset = pong.serverTime - Self.now + Int64(pingMs / 2)
      lastPong = Self.now
    case .room(let snapshot):
      if snapshot?.code != room?.code || snapshot?.phase != room?.phase { error = nil }
      if snapshot?.code != room?.code {
        game = nil
        chats = []
      }
      room = snapshot
      if snapshot == nil || snapshot?.phase == .lobby { game = nil }
    case .game(let snapshot):
      do {
        _ = try Position(fen: snapshot.boards.a.fen)
        _ = try Position(fen: snapshot.boards.b.fen)
        game = snapshot
      } catch { self.error = "The server supplied an invalid board position." }
    case .event(let event):
      lastEvent = event
      eventSerial += 1
    case .chat(let chat):
      if !chats.contains(where: { $0.id == chat.id }) { chats.append(chat) }
      if chats.count > 200 { chats.removeFirst(chats.count - 200) }
    case .error(let failure):
      error = "\(failure.message) (\(failure.code))"
    case .test(let command):
      guard serverTestMode, testID != nil else { return }
      Task { await handleTest(command) }
    }
  }

  private func beginHeartbeat() {
    heartbeat?.cancel()
    let current = generation
    transmit(ClientCommand.ping(Self.now))
    heartbeat = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
        guard let self, self.generation == current else { return }
        if Self.now - self.lastPong > 20_000 {
          self.failed(current, message: "The server stopped responding.")
          return
        }
        self.transmit(ClientCommand.ping(Self.now))
      }
    }
  }

  func submit(_ move: Move, on board: BoardID) {
    guard let seat = mySeat, seat.board == board, let game, game.result == nil,
      let position = try? Position(fen: game.boards[board].fen)
    else {
      error = "You can only move on your own board during a match."
      return
    }
    if position.turn == seat.color {
      guard position.legalMoves().contains(move) else {
        error = "Illegal move."
        return
      }
      send(.move(move))
    } else {
      send(.premove(move))
    }
  }

  private struct TestResult: Encodable {
    let type = "test.result"
    let id: String
    let ok: Bool
    let error: String?
    let room: RoomState?
    let game: GameState?
    let mySeat: Seat?
    let chats: Int
    let theme: String
  }

  private func handleTest(_ command: TestCommand) async {
    var failure: String?
    var settled: (() -> Bool)?
    let current = generation
    let previousMoves = game?.moves.count ?? 0
    let previousChat = chats.last?.id
    let previousRoom = room?.code
    let previousGame = game?.gameId
    let previousOffers = game?.drawOffers
    error = nil
    switch command.cmd {
    case "state": break
    case "create_room":
      send(.create(command.timeControl, fillBots: command.fillBots ?? false, code: command.code))
      settled = { self.room != nil && self.room?.code != previousRoom }
    case "join_room":
      send(.join(command.code ?? "", spectate: command.spectate ?? false))
      settled = { self.room?.code == command.code?.uppercased() }
    case "seat":
      send(.seat(command.seat))
      settled = { self.mySeat == command.seat }
    case "bot":
      if let seat = command.seat {
        send(.bot(seat, add: command.add ?? true))
        settled = {
          command.add == false
            ? self.room?.seated(seat) == nil : self.room?.seated(seat)?.bot == true
        }
      } else {
        failure = "Missing seat"
      }
    case "ready":
      send(.ready(command.ready ?? true))
      settled = {
        self.me?.ready == (command.ready ?? true)
          || (command.ready != false && self.room?.phase == .playing && self.game != nil)
      }
    case "start":
      send(.start)
      settled = { self.room?.phase == .playing && self.game != nil }
    case "rematch":
      send(.rematch)
      settled = {
        self.game?.gameId != previousGame
          || self.room?.rematchVotes.contains(self.playerID ?? "") == true
      }
    case "leave":
      send(.leave)
      settled = { self.room == nil }
    case "move":
      if let move = Move(uci: command.uci ?? ""), let seat = mySeat {
        submit(move, on: seat.board)
        settled = { (self.game?.moves.count ?? 0) > previousMoves || self.game?.premove == move }
      } else {
        failure = "Invalid move or spectator"
      }
    case "premove":
      let move = command.uci.flatMap { Move(uci: $0) }
      if command.uci != nil && move == nil {
        failure = "Invalid premove"
        break
      }
      send(.premove(move))
      settled = { self.game?.premove == move || (self.game?.moves.count ?? 0) > previousMoves }
    case "quick_chat":
      if let quick = QuickChat(rawValue: command.code ?? "") {
        send(.quick(quick, .team))
        settled = { self.chats.last?.id != previousChat }
      } else {
        failure = "Invalid quick chat"
      }
    case "chat":
      send(.chat(command.text ?? "", .room))
      settled = { self.chats.last?.id != previousChat }
    case "resign":
      send(.resign)
      settled = { self.game?.result != nil }
    case "draw":
      switch command.action {
      case "offer": send(.draw(.offer))
      case "accept": send(.draw(.accept))
      case "decline": send(.draw(.decline))
      default: failure = "Invalid draw action"
      }
      settled = { self.game?.result != nil || self.game?.drawOffers != previousOffers }
    case "theme":
      theme = command.mode == "light" ? "light" : "dark"
      UserDefaults.standard.set(theme, forKey: "theme")
    case "wait":
      settled = {
        (command.phase == nil || command.phase == self.room?.phase)
          && (command.moves == nil || (self.game?.moves.count ?? 0) >= (command.moves ?? 0))
          && (command.over == nil || command.over == (self.game?.result != nil))
      }
    case "capture":
      failure =
        "Use native XCTest/simctl or macOS screen capture. Flutter raster capture is retired."
    default: failure = "Unknown test command"
    }
    await sender?.value
    if let settled, failure == nil {
      let deadline = Self.now + Int64(min(command.timeoutMs ?? 30_000, 60_000))
      while !settled() && error == nil && generation == current && Self.now < deadline {
        do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
      }
      if !settled(), error == nil { failure = "Command timed out" }
    }
    guard generation == current else { return }
    transmit(
      TestResult(
        id: command.id, ok: failure == nil && error == nil, error: failure ?? error,
        room: room, game: game, mySeat: mySeat, chats: chats.count, theme: theme))
  }
}
