import AudioToolbox
import BrickfolkCore
import Combine
import Foundation

#if os(iOS)
  import UIKit
#endif

@MainActor
final class Client: ObservableObject {
  enum Status: String {
    case offline = "Offline"
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
  }
  let config = LaunchConfig()
  let content: GameContent?
  let contentError: String?
  @Published var status: Status = .offline
  @Published var me: PlayerProfile?
  @Published var places: [PlaceListing] = []
  @Published var onlineCount = 0
  @Published var friends = FriendsState()
  @Published var party: PartyState?
  @Published var room: RoomState?
  @Published var botCount = 0
  @Published var frame: GameFrame?
  var previousFrame: GameFrame?
  var frameReceivedAt = Date()
  var frameInterval = 1.0 / 30.0
  @Published var results: MatchResults?
  @Published var resultsEndsAt: Int64?
  @Published var chat: [ChatMessage] = []
  @Published var daily: DailyResult?
  @Published var viewedProfile: PlayerProfile?
  @Published var error: String?
  @Published var eventText: String?
  @Published var selectedTab = "places"
  @Published var requestedSheet: String?
  @Published var placeSelection: Experience?
  @Published var theme: String { didSet { UserDefaults.standard.set(theme, forKey: "theme") } }
  @Published var sound: Bool { didSet { UserDefaults.standard.set(sound, forKey: "sound") } }
  @Published var haptics: Bool { didSet { UserDefaults.standard.set(haptics, forKey: "haptics") } }
  @Published var serverURL: String
  @Published private(set) var hasLegacySession = false
  var serverOffset: Int64 = 0
  private var connection: WebSocketConnection?
  private var lifecycle: Task<Void, Never>?
  private var heartbeat: Task<Void, Never>?
  private var sendQueue: Task<Void, Never>?
  private var eventDismissal: Task<Void, Never>?
  private var generation = UUID()
  private var resumeToken: String?
  private var restoringLegacySession = false
  private var pendingName: String?
  private var lastMessage = Date()
  private var shouldReconnect = false
  private var testServer = false
  private let driver = AutomationDriver()

  var myID: String { me?.id ?? "" }
  var isLeader: Bool { party?.leaderId == me?.id }
  var serverNow: Int64 { Int64(Date().timeIntervalSince1970 * 1000) + serverOffset }
  var platform: String {
    #if os(macOS)
      return "macos"
    #else
      return "ios"
    #endif
  }
  init() {
    do {
      content = try GameContent.load()
      contentError = nil
    } catch {
      content = nil
      contentError = error.localizedDescription
    }
    let defaults = UserDefaults.standard
    NativePreferences.migrateLegacy(in: defaults)
    theme = config.theme ?? defaults.string(forKey: "theme") ?? "system"
    sound = defaults.object(forKey: "sound") as? Bool ?? true
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    serverURL = config.server ?? defaults.string(forKey: "server") ?? "ws://localhost:8080/ws"
    hasLegacySession = SessionStore.legacyToken != nil
  }

  func start() {
    guard lifecycle == nil else { return }
    restoringLegacySession = false
    if config.test || config.name != nil {
      signIn(name: config.name ?? "Tester\(platform)")
    } else {
      do {
        let url = try Endpoint.validated(serverURL)
        resumeToken = try SessionStore.read(server: url.absoluteString)
        if resumeToken != nil { begin(name: nil, url: url) }
      } catch { self.error = error.localizedDescription }
    }
  }

  func signIn(name: String) {
    restoringLegacySession = false
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard name.range(of: "^[A-Za-z][A-Za-z0-9_]{2,15}$", options: .regularExpression) != nil else {
      error = "Use 3–16 letters, numbers or underscores, starting with a letter."
      return
    }
    do {
      let url = try Endpoint.validated(serverURL)
      resumeToken = config.test ? nil : try SessionStore.read(server: url.absoluteString)
      begin(name: name, url: url)
    } catch {
      self.error = "Invalid server or saved session: \(error.localizedDescription)"
    }
  }

  func restorePreviousSession() {
    do {
      let url = try Endpoint.validated(serverURL)
      guard let token = SessionStore.legacyToken else {
        hasLegacySession = false
        return
      }
      resumeToken = token
      restoringLegacySession = true
      begin(name: nil, url: url)
    } catch { self.error = error.localizedDescription }
  }

  private func begin(name: String?, url: URL) {
    stopConnection()
    serverURL = url.absoluteString
    UserDefaults.standard.set(serverURL, forKey: "server")
    pendingName = name
    error = nil
    shouldReconnect = true
    let generation = generation
    lifecycle = Task { [weak self] in
      guard let self else { return }
      var attempt = 0
      while !Task.isCancelled && shouldReconnect && self.generation == generation {
        status = attempt == 0 ? .connecting : .reconnecting
        let socket = WebSocketConnection(url: url)
        connection = socket
        lastMessage = Date()
        do {
          try await socket.send(
            .hello(
              name: resumeToken == nil ? pendingName : nil,
              token: resumeToken, platform: platform))
          startHeartbeat(socket, generation: generation)
          while !Task.isCancelled && self.generation == generation && shouldReconnect {
            let message = try await socket.receive()
            guard self.generation == generation else { break }
            lastMessage = Date()
            receive(message)
            if status == .connected { attempt = 0 }
          }
        } catch {
          if shouldReconnect && self.generation == generation && !Task.isCancelled {
            self.error = "Connection interrupted: \(error.localizedDescription). Retrying…"
          }
        }
        await socket.close()
        heartbeat?.cancel()
        guard shouldReconnect && !Task.isCancelled && self.generation == generation else { break }
        frame = nil
        previousFrame = nil
        status = .reconnecting
        attempt += 1
        try? await Task.sleep(for: .seconds(min(8, 0.4 * pow(2, Double(min(attempt, 5))))))
      }
      if self.generation == generation {
        status = .offline
        lifecycle = nil
      }
    }
  }

  private func startHeartbeat(_ socket: WebSocketConnection, generation: UUID) {
    heartbeat?.cancel()
    heartbeat = Task { [weak self] in
      var cycles = 0
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(500))
        guard let self, !Task.isCancelled, self.generation == generation else { return }
        cycles += 1
        if Date().timeIntervalSince(lastMessage) > (me == nil ? 20 : 35) {
          await socket.close()
          return
        }
        if cycles % 20 == 0 { try? await socket.send(.ping(serverNow)) }
        if config.test && testServer { driver.update(self) }
      }
    }
  }

  func send(_ command: Command) {
    guard status == .connected, let connection else {
      error = "Not connected. Wait for your session to reconnect, or sign in again."
      return
    }
    let previous = sendQueue
    let generation = generation
    sendQueue = Task { [weak self] in
      await previous?.value
      guard let self, !Task.isCancelled, self.generation == generation else { return }
      do { try await connection.send(command) } catch {
        if self.generation == generation { self.error = error.localizedDescription }
      }
    }
  }
  func input(_ input: Input) {
    guard status == .connected, room?.phase == .playing else { return }
    send(.input(input))
  }
  func showProfile(_ id: String) {
    viewedProfile = nil
    requestedSheet = "profile"
    send(.profile(id))
  }
  func leaveRoom() { send(.roomLeave) }

  func signOut() {
    stopConnection()
    do { try SessionStore.write(nil, server: serverURL) } catch {
      self.error = error.localizedDescription
    }
    resumeToken = nil
    restoringLegacySession = false
    pendingName = nil
    me = nil
    room = nil
    party = nil
    frame = nil
    previousFrame = nil
    results = nil
    places = []
    friends = FriendsState()
    chat = []
    daily = nil
    driver.reset()
  }
  func reconnect() {
    guard let url = try? Endpoint.validated(serverURL) else {
      error = "Enter a valid ws:// or wss:// server URL."
      return
    }
    begin(name: pendingName, url: url)
  }
  func pause() { stopConnection() }
  func resume() {
    if me != nil && lifecycle == nil { reconnect() } else if lifecycle == nil { start() }
  }
  private func stopConnection() {
    shouldReconnect = false
    generation = UUID()
    lifecycle?.cancel()
    lifecycle = nil
    heartbeat?.cancel()
    heartbeat = nil
    sendQueue?.cancel()
    sendQueue = nil
    let old = connection
    connection = nil
    Task { await old?.close() }
    status = .offline
  }

  private func receive(_ message: ServerMessage) {
    switch message {
    case .welcome(let welcome):
      guard welcome.protocolVersion == 1 else {
        error = "This server uses an unsupported protocol."
        shouldReconnect = false
        return
      }
      me = welcome.player
      resumeToken = welcome.token
      status = .connected
      testServer = welcome.testMode
      serverOffset = welcome.serverTime - Int64(Date().timeIntervalSince1970 * 1000)
      error = nil
      UserDefaults.standard.set(welcome.player.name, forKey: "session.name")
      if !config.test {
        do {
          try SessionStore.write(welcome.token, server: serverURL)
          if restoringLegacySession {
            SessionStore.removeLegacyToken()
            restoringLegacySession = false
            hasLegacySession = false
          }
        } catch {
          self.error = error.localizedDescription
        }
      }
      if welcome.roomCode == nil {
        room = nil
        frame = nil
        previousFrame = nil
      }
      if welcome.partyCode == nil { party = nil }
      if config.test && !testServer { error = "Automation requires the server's --test-mode flag." }
    case .pong(let time): serverOffset = time - Int64(Date().timeIntervalSince1970 * 1000)
    case .error(let failure):
      error = failure.message
      if failure.inReplyTo == "hello" || failure.message == "Signed in from another client." {
        shouldReconnect = false
        if failure.code == "unauthenticated" {
          resumeToken = nil
          do { try SessionStore.write(nil, server: serverURL) } catch {
            self.error = error.localizedDescription
          }
        }
        if failure.inReplyTo == "hello" { me = nil }
      }
    case .playerUpdated(let player): me = player
    case .daily(let daily): self.daily = daily
    case .friends(let friends): self.friends = friends
    case .party(let party):
      if self.party?.code != party?.code { chat.removeAll { $0.channel == .party } }
      self.party = party
    case .chat(let message):
      if !chat.contains(where: { $0.id == message.id && $0.timestamp == message.timestamp }) {
        chat.append(message)
        if chat.count > 200 { chat.removeFirst(chat.count - 200) }
      }
    case .places(let places, let online):
      self.places = places
      onlineCount = online
    case .profile(let profile): viewedProfile = profile
    case .room(let room, let bots, let time):
      if self.room?.code != room?.code || self.room?.round != room?.round || room?.phase == .lobby {
        frame = nil
        previousFrame = nil
        results = nil
      }
      if self.room?.code != room?.code {
        chat.removeAll { $0.channel == .room }
        requestedSheet = nil
        placeSelection = nil
        eventText = nil
      }
      self.room = room
      botCount = bots
      if let time { serverOffset = time - Int64(Date().timeIntervalSince1970 * 1000) }
    case .game(let frame):
      guard room?.phase == .playing else { return }
      previousFrame = self.frame
      if let previousFrame {
        frameInterval = max(1.0 / 30, min(0.25, Double(frame.tick - previousFrame.tick) / 30))
      }
      self.frame = frame
      frameReceivedAt = Date()
    case .events(let events):
      for event in events
      where ["checkpoint", "death", "finish", "freeze", "thaw", "roundStart", "roundEnd", "start"]
        .contains(event.kind)
      {
        showEvent(event)
      }
    case .results(let results, let endsAt):
      self.results = results
      resultsEndsAt = endsAt
      if results.checksum != results.computedChecksum {
        error = "The result checksum did not match. Reconnect to refresh."
      }
    case .control(let control):
      if config.test && testServer { driver.control(control, client: self) }
    case .unknown: break
    }
    if config.test && testServer { driver.update(self) }
  }

  private func showEvent(_ event: GameEvent) {
    let name = room?.members.first { $0.id == event.player }?.player.name ?? ""
    eventText = "\(name) \(event.kind)"
    eventDismissal?.cancel()
    eventDismissal = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      if !Task.isCancelled { self?.eventText = nil }
    }
    if event.player == myID || event.kind == "start" {
      if sound { AudioServicesPlaySystemSound(1104) }
      #if os(iOS)
        if haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
      #endif
    }
  }
}
