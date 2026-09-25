import AVFoundation
import Combine
import CoreText
import Foundation
import HearthCore
import Security

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

@MainActor final class Preferences: ObservableObject {
  @Published var name: String { didSet { defaults.set(name, forKey: "name") } }
  @Published var server: String { didSet { defaults.set(server, forKey: "server") } }
  @Published var sensitivity: Double { didSet { defaults.set(sensitivity, forKey: "sensitivity") } }
  @Published var fov: Double { didSet { defaults.set(fov, forKey: "fov") } }
  @Published var invertY: Bool { didSet { defaults.set(invertY, forKey: "invertY") } }
  @Published var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
  @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  @Published var showFPS: Bool { didSet { defaults.set(showFPS, forKey: "showFPS") } }
  @Published var quality: Int { didSet { defaults.set(quality, forKey: "quality") } }
  @Published var theme: String { didSet { defaults.set(theme, forKey: "theme") } }
  @Published var touch: Bool { didSet { defaults.set(touch, forKey: "touch") } }
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    defaults.register(defaults: [
      "name": "Wanderer", "server": "ws://127.0.0.1:8787/ws",
      "sensitivity": 1.0, "fov": 70.0, "sound": true, "haptics": true,
      "quality": 1, "theme": "dark", "touch": true,
    ])
    name = defaults.string(forKey: "name") ?? "Wanderer"
    server = defaults.string(forKey: "server") ?? "ws://127.0.0.1:8787/ws"
    sensitivity = defaults.double(forKey: "sensitivity")
    fov = defaults.double(forKey: "fov")
    invertY = defaults.bool(forKey: "invertY")
    sound = defaults.bool(forKey: "sound")
    haptics = defaults.bool(forKey: "haptics")
    showFPS = defaults.bool(forKey: "showFPS")
    quality = defaults.integer(forKey: "quality")
    theme = defaults.string(forKey: "theme") ?? "dark"
    touch = defaults.bool(forKey: "touch")
  }
}

enum ResumeToken {
  static func query(_ server: String) -> [String: NSObject] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.voxelhearth.resume" as NSString,
      kSecAttrAccount as String: server as NSString,
    ]
  }
  static func read(_ server: String) -> String? {
    var attributes = query(server)
    attributes[kSecReturnData as String] = kCFBooleanTrue
    attributes[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(attributes as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
  static func write(_ token: String, server: String) -> OSStatus {
    let attributes = query(server)
    let data = Data(token.utf8) as NSData
    let update = [kSecValueData as String: data]
    let status = SecItemUpdate(attributes as CFDictionary, update as CFDictionary)
    if status != errSecItemNotFound { return status }
    var entry = attributes
    entry[kSecValueData as String] = data
    entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(entry as CFDictionary, nil)
  }
}

@MainActor final class Feedback {
  let preferences: Preferences
  var audio: [String: AVAudioPlayer] = [:]
  init(_ preferences: Preferences) { self.preferences = preferences }
  func play(_ name: String, vibrate: Bool = false) {
    if preferences.sound {
      if audio[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav") {
        audio[name] = try? AVAudioPlayer(contentsOf: url)
      }
      audio[name]?.currentTime = 0
      audio[name]?.play()
    }
    if vibrate && preferences.haptics {
      #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      #else
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
      #endif
    }
  }
}

@MainActor final class Session: ObservableObject {
  enum Connection: String { case idle, connecting, online, reconnecting, failed }
  let preferences: Preferences
  let feedback: Feedback
  let launch = LaunchConfiguration()
  @Published var connection: Connection = .idle
  @Published var error: String?
  @Published var rooms: [RoomSummary] = []
  @Published var code: String?
  @Published var roomName = ""
  @Published var phase = "lobby"
  @Published var mode = "survival"
  @Published var host = ""
  @Published var playerID = ""
  @Published var players: [Player] = []
  @Published var chat: [ChatLine] = []
  @Published var inventory = [ItemStack](repeating: .empty, count: 36)
  @Published var selected = 0
  @Published var hp = 20
  @Published var food = 20
  @Published var air = 300
  @Published var score = 0
  @Published var tick = 0
  @Published var time = 1000
  @Published var endTick = 0
  @Published var duration = 0
  @Published var freezeTime = false
  @Published var spawnMobs = true
  @Published var containerKind: String?
  @Published var chest = [ItemStack](repeating: .empty, count: 27)
  @Published var kiln: Kiln?
  @Published var results: [Player] = []
  @Published var worldHash = ""
  @Published var chatHash = ""
  @Published var toast: String?
  var world: World?
  var remotePlayers: [Player] = []
  var mobs: [Mob] = []
  var onPosition: ((Double, Double, Double, Double?, Double?) -> Void)?
  var onEffect: ((ServerMessage) -> Void)?
  var onDrive: ((DriveAction) async -> ClientReport)?
  private var serverTestMode = false
  private var socket: URLSessionWebSocketTask?
  private let urlSession = URLSession(configuration: .default)
  private var receiveTask: Task<Void, Never>?
  private var reconnectTask: Task<Void, Never>?
  private var heartbeat: Task<Void, Never>?
  private var sendTask: Task<Void, Never>?
  private var generation = UUID()
  private var attempts = 0
  private var stopped = false
  private var pendingLaunch = true
  private var endpoint = ""
  private var sessionToken: String?
  var isHost: Bool { host == playerID }
  var online: Bool { connection == .online }

  init(preferences: Preferences) {
    self.preferences = preferences
    feedback = Feedback(preferences)
    if let server = launch.server { preferences.server = server }
    if let name = launch.name { preferences.name = name }
  }
  func connect() {
    stopped = false
    attempts = 0
    let changed = endpoint != preferences.server
    if changed {
      clearRoom()
      sessionToken = nil
    }
    endpoint = preferences.server
    open()
  }
  func disconnect() {
    stopped = true
    generation = UUID()
    receiveTask?.cancel()
    heartbeat?.cancel()
    reconnectTask?.cancel()
    sendTask?.cancel()
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
    connection = .idle
  }
  private func open() {
    receiveTask?.cancel()
    heartbeat?.cancel()
    reconnectTask?.cancel()
    sendTask?.cancel()
    socket?.cancel(with: .goingAway, reason: nil)
    let identity = UUID()
    generation = identity
    guard let url = ServerAddress.parse(endpoint) else {
      connection = .failed
      error = "Enter a valid ws:// or wss:// server URL."
      return
    }
    connection = attempts == 0 ? .connecting : .reconnecting
    let socket = urlSession.webSocketTask(with: url)
    self.socket = socket
    socket.resume()
    var hello = ClientMessage(.hello)
    hello.name = String(preferences.name.prefix(20))
    hello.version = 1
    #if os(macOS)
      hello.platform = "macos"
    #else
      hello.platform = "ios"
    #endif
    hello.token = sessionToken ?? (launch.test ? nil : ResumeToken.read(endpoint))
    send(hello, allowHandshake: true)
    receiveTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          let message = try await socket.receive()
          guard let self, self.generation == identity else { return }
          let data: Data
          switch message {
          case .data(let value): data = value
          case .string(let value): data = Data(value.utf8)
          @unknown default: continue
          }
          let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
          self.handle(decoded)
        } catch {
          guard let self, self.generation == identity, !Task.isCancelled else { return }
          self.failed(error.localizedDescription, identity: identity)
          return
        }
      }
    }
    heartbeat = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(5)) } catch { return }
        guard let self, self.generation == identity else { return }
        if self.connection != .online {
          self.failed("The server did not complete the handshake.", identity: identity)
          return
        }
        var ping = ClientMessage(.ping)
        ping.ts = Int64(Date().timeIntervalSince1970 * 1000)
        self.send(ping)
      }
    }
  }
  private func failed(_ reason: String, identity: UUID) {
    guard generation == identity, !stopped else { return }
    generation = UUID()
    receiveTask?.cancel()
    heartbeat?.cancel()
    sendTask?.cancel()
    socket?.cancel(with: .goingAway, reason: nil)
    socket = nil
    attempts += 1
    error = reason
    guard attempts <= 8 else {
      connection = .failed
      return
    }
    connection = .reconnecting
    let delay = min(8.0, pow(2, Double(attempts - 1)))
    reconnectTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      self?.open()
    }
  }
  func send(_ message: ClientMessage, allowHandshake: Bool = false) {
    sendEncoded(message, allowHandshake: allowHandshake)
  }
  func send(_ report: ClientReport) { sendEncoded(report) }
  private func sendEncoded<Message: Encodable & Sendable>(
    _ message: Message, allowHandshake: Bool = false
  ) {
    guard let socket, online || allowHandshake else { return }
    let identity = generation
    let previous = sendTask
    sendTask = Task { [weak self] in
      await previous?.value
      guard let self, self.generation == identity, !Task.isCancelled else { return }
      do {
        let data = try JSONEncoder().encode(message)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
      } catch { self.failed(error.localizedDescription, identity: identity) }
    }
  }
  func send(_ intent: Intent) { send(ClientMessage(intent)) }
  func chatSend(_ text: String) {
    let text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
    guard !text.isEmpty else { return }
    var message = ClientMessage(.chat)
    message.text = text
    send(message)
  }
  func select(_ slot: Int) {
    guard (0..<9).contains(slot) else { return }
    selected = slot
    var message = ClientMessage(.selectSlot)
    message.slot = slot
    send(message)
  }
  func join(_ code: String) {
    var message = ClientMessage(.joinRoom)
    message.code = code.uppercased()
    send(message)
  }
  func leave() {
    send(.leaveRoom)
    clearRoom()
  }
  func dropConnection() { failed("Connection dropped", identity: generation) }
  private func clearRoom() {
    code = nil
    world = nil
    players = []
    remotePlayers = []
    mobs = []
    chat = []
    containerKind = nil
    results = []
    phase = "lobby"
    worldHash = ""
    chatHash = ""
  }
  func closeInventory() {
    containerKind = nil
    send(.closeUI)
  }
  private func handle(_ m: ServerMessage) {
    switch m.t {
    case "welcome":
      serverTestMode = m.testMode == true
      connection = .online
      attempts = 0
      error = nil
      playerID = m.playerId ?? ""
      if let token = m.token {
        sessionToken = token
        if !launch.test {
          let status = ResumeToken.write(token, server: endpoint)
          if status != errSecSuccess {
            error =
              "Resume token could not be saved in Keychain (\(status)). It remains available for this session."
          }
        }
      }
    case "error":
      error = m.msg ?? m.code ?? "Server rejected the request."
    case "drive":
      guard launch.test, serverTestMode, let action = m.action else { return }
      Task { [weak self] in
        guard let self else { return }
        var response = await self.onDrive?(action) ?? ClientReport()
        response.id = m.id?.player
        self.send(response)
      }
    case "hash_request":
      guard launch.test, serverTestMode else { return }
      var report = ClientReport("client_hash")
      report.id = m.id?.player
      report.world = world?.editsHash
      report.chat = Fingerprint.chat(chat)
      report.phase = phase
      report.players = players.count
      if let region = m.region { report.region = world?.regionHash(region) }
      send(report)
    case "rooms":
      rooms = m.rooms ?? []
      if code != nil { clearRoom() }
      if pendingLaunch {
        pendingLaunch = false
        if let join = launch.join {
          self.join(join)
        } else if launch.create {
          var create = ClientMessage(.createRoom)
          create.name = "VoxelHearth"
          create.seed = 424242
          create.mode = launch.test ? "creative" : "survival"
          create.bots = launch.test ? 1 : 0
          send(create)
        }
      }
    case "room_joined":
      code = m.code
      roomName = m.roomName ?? m.name ?? "World"
      world = World(seed: m.seed ?? 0)
      players = m.players ?? []
      chat = m.chat ?? []
      phase = m.phase ?? "lobby"
      mode = m.mode ?? "survival"
      host = m.host ?? ""
      remotePlayers = []
      mobs = []
      results = []
      updateRoom(m)
      onPosition?(m.x ?? 0, m.y ?? 40, m.z ?? 0, m.yaw, m.pitch)
      feedback.play("ui_confirm")
    case "room_state": updateRoom(m)
    case "player_joined":
      if let p = m.player, !players.contains(where: { $0.id == p.id }) { players.append(p) }
    case "player_left":
      if let id = m.id?.player { players.removeAll { $0.id == id } }
    case "chunk":
      if let cx = m.cx, let cz = m.cz { world?.apply(cx, cz, edits: m.edits ?? []) }
    case "block_set":
      if let x = m.x, let y = m.y, let z = m.z, let id = m.id?.number {
        world?.set(Int(x), Int(y), Int(z), id)
      }
    case "snapshot":
      remotePlayers = m.players ?? []
      mobs = m.mobs ?? []
      tick = m.tick ?? tick
      time = m.time ?? time
    case "inventory":
      if let slots = m.slots {
        inventory = Array((slots + Array(repeating: .empty, count: 36)).prefix(36))
      }
      selected = max(0, min(8, m.selected ?? selected))
    case "stats":
      if (m.hp ?? hp) < hp { feedback.play("hurt", vibrate: true) }
      hp = m.hp ?? hp
      food = m.food ?? food
      air = m.air ?? air
      score = m.score ?? score
    case "chat_msg":
      chat.append(
        ChatLine(
          tick: m.tick ?? tick, from: m.from ?? "", text: m.text ?? "", system: m.system ?? false))
      if chat.count > 300 { chat.removeFirst(chat.count - 300) }
      feedback.play("chat")
    case "phase":
      phase = m.phase ?? phase
      tick = m.tick ?? tick
      time = m.time ?? time
      endTick = m.matchEndTick ?? endTick
      results = m.results ?? results
      worldHash = m.worldHash ?? worldHash
      chatHash = m.chatHash ?? chatHash
      containerKind = nil
      feedback.play(phase == "playing" ? "match_start" : "match_end")
    case "time_set": time = m.time ?? time
    case "teleport": onPosition?(m.x ?? 0, m.y ?? 40, m.z ?? 0, m.yaw, m.pitch)
    case "open_ui": containerKind = m.kind
    case "container":
      if let slots = m.slots { chest = slots }
      kiln = m.kiln ?? kiln
    case "effect":
      if let text = m.text { toast = text }
      let sounds = [
        "break": "break_hard", "place": "place", "craft": "craft", "eat": "eat",
        "sleep": "sleep", "pickup": "pickup", "hurt": "hurt", "smelt": "smelt",
      ]
      if let sound = sounds[m.kind ?? ""] { feedback.play(sound, vibrate: true) }
      if m.kind == "inventory_full" { toast = "Inventory full" }
      onEffect?(m)
    default: break
    }
  }
  private func updateRoom(_ m: ServerMessage) {
    roomName = m.roomName ?? m.name ?? roomName
    phase = m.phase ?? phase
    host = m.host ?? host
    mode = m.mode ?? mode
    players = m.players ?? players
    tick = m.tick ?? tick
    time = m.time ?? time
    endTick = m.matchEndTick ?? endTick
    duration = m.durationTicks ?? duration
    freezeTime = m.freezeTime ?? freezeTime
    spawnMobs = m.spawnMobs ?? spawnMobs
  }
}
