import Foundation
import Observation

@MainActor @Observable final class Connection {
  enum State: String { case offline, connecting, online, reconnecting, failed }
  private(set) var state = State.offline
  private(set) var playerId = ""
  private(set) var latency = 0
  var error: String?
  var onMessage: ((ServerMessage) -> Void)?
  var profile = Preferences()
  private var socket: URLSessionWebSocketTask?
  private var session: URLSession?
  private var run: Task<Void, Never>?
  private var writer: Task<Void, Never>?
  private var heartbeat: Task<Void, Never>?
  private var handshake: Task<Void, Never>?
  private var credentials: Credentials?
  private var generation = UUID()
  private var server = ""
  var serverURL: String { server }
  private var ephemeral = false
  static var platform: String {
    #if os(macOS)
      return "macos"
    #else
      return "ios"
    #endif
  }
  func connect(_ preferences: Preferences, ephemeral: Bool = false) {
    let previousCredentials = server == preferences.server ? credentials : nil
    disconnect()
    profile = preferences
    server = preferences.server
    self.ephemeral = ephemeral
    guard let url = URL(string: server), ["ws", "wss"].contains(url.scheme), url.host != nil,
      url.user == nil, url.password == nil
    else {
      state = .failed
      error = "Enter a valid ws:// or wss:// server URL."
      return
    }
    error = nil
    state = .connecting
    credentials = previousCredentials ?? (ephemeral ? nil : TokenStore.read(server))
    let id = generation
    run = Task { [weak self] in
      guard let self else { return }
      for attempt in 0..<6 {
        if Task.isCancelled || id != generation { return }
        if attempt > 0 {
          state = .reconnecting
          try? await Task.sleep(for: .seconds(min(8, Double(attempt))))
          if Task.isCancelled || id != generation { return }
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        let session = URLSession(configuration: config)
        self.session = session
        let socket = session.webSocketTask(with: url)
        self.socket = socket
        socket.resume()
        if let credentials {
          send(.resume(playerId: credentials.playerId, token: credentials.token))
        } else {
          hello()
        }
        handshake = Task { [weak self, weak socket] in
          try? await Task.sleep(for: .seconds(12))
          guard !Task.isCancelled, self?.state != .online else { return }
          socket?.cancel(with: .goingAway, reason: nil)
        }
        do {
          while !Task.isCancelled && id == generation {
            let packet = try await socket.receive()
            let data: Data
            switch packet {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: continue
            }
            let message = try JSONDecoder().decode(ServerMessage.self, from: data)
            if id != generation { return }
            receive(message)
          }
        } catch {
          if Task.isCancelled || id != generation { return }
          self.error = "Connection interrupted: \(error.localizedDescription)"
        }
        writer?.cancel()
        writer = nil
        handshake?.cancel()
        heartbeat?.cancel()
        socket.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
      }
      if id == generation {
        state = .failed
        error = "Could not reconnect. Check the server address and choose Try again."
      }
    }
  }
  private func hello() {
    send(
      .hello(
        name: profile.name, character: profile.character, kart: profile.kart,
        platform: Self.platform))
  }
  func sendProfile(_ preferences: Preferences) {
    profile = preferences
    if state == .online {
      send(.profile(name: profile.name, character: profile.character, kart: profile.kart))
    }
  }
  func send(_ message: ClientMessage) {
    guard let socket else { return }
    let previous = writer
    let id = generation
    writer = Task { [weak self] in
      await previous?.value
      guard !Task.isCancelled, let self, id == generation, self.socket === socket else { return }
      do {
        let bytes = try JSONEncoder().encode(message)
        try await socket.send(.string(String(decoding: bytes, as: UTF8.self)))
      } catch {
        if !Task.isCancelled && id == generation && self.socket === socket {
          self.error = error.localizedDescription
          socket.cancel(with: .goingAway, reason: nil)
        }
      }
    }
  }
  private func receive(_ message: ServerMessage) {
    switch message {
    case .welcome(let value):
      guard value.v == 1 else {
        error = "Incompatible server protocol \(value.v)."
        disconnect()
        state = .failed
        return
      }
      handshake?.cancel()
      state = .online
      error = nil
      playerId = value.playerId
      credentials = Credentials(playerId: value.playerId, token: value.token)
      if !ephemeral, let credentials {
        do { try TokenStore.save(credentials, server) } catch {
          self.error =
            "Resume credentials could not be saved securely: \(error.localizedDescription)"
        }
      }
      if value.resumed == true { sendProfile(profile) }
      heartbeat?.cancel()
      heartbeat = Task { [weak self] in
        while !Task.isCancelled {
          self?.send(.ping(Date().timeIntervalSince1970 * 1000))
          try? await Task.sleep(for: .seconds(2))
        }
      }
    case .error(let value):
      error = "\(value.code): \(value.message)"
      if value.code == "resume_failed" || value.code == "invalid_token" {
        credentials = nil
        if !ephemeral { TokenStore.clear(server) }
        hello()
      }
    case .pong(let value): latency = max(0, Int(Date().timeIntervalSince1970 * 1000 - value.t))
    default: break
    }
    onMessage?(message)
  }
  func disconnect() {
    generation = UUID()
    run?.cancel()
    writer?.cancel()
    heartbeat?.cancel()
    handshake?.cancel()
    run = nil
    writer = nil
    heartbeat = nil
    handshake = nil
    socket?.cancel(with: .normalClosure, reason: nil)
    socket = nil
    session?.invalidateAndCancel()
    session = nil
    state = .offline
  }
}
