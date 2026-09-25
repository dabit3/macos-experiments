import Foundation

enum SmokeError: Error { case failed(String) }
@MainActor final class SmokePeer {
  let connection = Connection()
  var room: Room?
  var race: RaceSession?
  var outcome: RaceOutcome?
  var match: MatchOutcome?
  var snapshots = 0, starts = 0
  init(name: String, server: String) {
    var profile = Preferences()
    profile.name = name
    profile.server = server
    connection.onMessage = { [weak self] message in
      guard let self else { return }
      switch message {
      case .room(let value): room = value
      case .start(let info):
        guard let slot = info.racers.first(where: { $0.playerId == self.connection.playerId })?.slot
        else { return }
        starts += 1
        let race = RaceSession(info: info, slot: slot, online: true)
        race.autopilot = Autopilot(lane: Double(slot * 7 - 4))
        race.send = { [weak self] in self?.connection.send($0) }
        self.race = race
      case .snapshot(let value):
        snapshots += 1
        race?.apply(value)
      case .raceFinished(let value): outcome = value
      case .matchOver(let value): match = value
      default: break
      }
    }
    connection.connect(profile, ephemeral: true)
  }
}
@main struct ProtocolSmoke {
  @MainActor static func until(_ label: String, seconds: Double = 10, _ predicate: () -> Bool)
    async throws
  {
    let deadline = Date().addingTimeInterval(seconds)
    while !predicate() {
      if Date() > deadline { throw SmokeError.failed("Timed out: \(label)") }
      try await Task.sleep(for: .milliseconds(30))
    }
  }
  @MainActor static func main() async throws {
    let server = ProcessInfo.processInfo.environment["NT_SERVER"] ?? "ws://127.0.0.1:8787/ws"
    let invalid = Connection()
    var bad = Preferences()
    bad.server = "not a websocket"
    invalid.connect(bad, ephemeral: true)
    guard invalid.state == .failed && invalid.error != nil else {
      throw SmokeError.failed("Invalid URL must be visible")
    }
    let a = SmokePeer(name: "Native Host", server: server)
    let b = SmokePeer(name: "Native Guest", server: server)
    defer {
      a.connection.disconnect()
      b.connection.disconnect()
    }
    try await until("two welcomes") {
      a.connection.state == .online && b.connection.state == .online
    }
    var settings = RoomSettings()
    settings.mode = .battle
    settings.trackId = "bowl"
    settings.grandPrix = false
    settings.maxPlayers = 4
    settings.minPlayers = 2
    settings.battleSeconds = 30
    a.connection.send(.create(settings))
    try await until("room created") { a.room != nil }
    guard let room = a.room else { throw SmokeError.failed("Missing room") }
    b.connection.send(.join(room.code))
    try await until("two seats") { a.room?.players.count == 2 && b.room?.players.count == 2 }
    let original = b.connection.playerId
    b.connection.send(.next)
    try await until("server rejects non-host") { b.connection.error?.contains("not_host") == true }
    b.connection.error = nil
    a.connection.send(.settings(settings))
    b.connection.send(.ready(true))
    a.connection.send(.start)
    try await until("authoritative start with bot seats") {
      a.race?.sim.racers.count == 4 && b.race?.sim.racers.count == 4
    }
    let driver = Task { @MainActor in
      while !Task.isCancelled {
        a.race?.advance(tickDt)
        b.race?.advance(tickDt)
        a.race?.events.removeAll()
        b.race?.events.removeAll()
        try? await Task.sleep(for: .milliseconds(33))
      }
    }
    defer { driver.cancel() }
    try await until("live snapshots") { a.snapshots > 10 && b.snapshots > 10 }
    b.connection.disconnect()
    try await until("disconnected seat") {
      a.room?.players.first(where: { $0.id == original })?.connected == false
    }
    b.connection.connect(b.connection.profile, ephemeral: true)
    try await until("same seat resumed mid-match") {
      b.connection.state == .online && b.connection.playerId == original && b.starts == 2
    }
    try await until("authoritative battle results", seconds: 45) {
      a.outcome != nil && b.outcome != nil
    }
    guard a.outcome?.results == b.outcome?.results else {
      throw SmokeError.failed("Clients disagree on race results")
    }
    a.connection.send(.next)
    try await until("match over") { a.match != nil && b.match != nil }
    guard let match = a.match, match.hash == b.match?.hash, match.standings == b.match?.standings
    else {
      throw SmokeError.failed("Clients disagree on match hash or standings")
    }
    a.connection.send(
      .report(
        hash: match.hash, standings: match.standings, lastTick: a.race?.sim.tick ?? 0,
        frames: a.snapshots))
    var profile = b.connection.profile
    profile.name = "Resumed Driver"
    profile.character = "mabel"
    profile.kart = "pinewood"
    b.connection.sendProfile(profile)
    try await until("profile updated in rematch lobby") {
      a.room?.players.first(where: { $0.id == original })?.character == "mabel"
    }
    a.connection.send(.start)
    try await until("rematch") { a.starts == 2 && b.starts == 3 }
    b.connection.send(.leave)
    try await until("leave room") { a.room?.players.count == 1 }
    guard a.connection.error == nil && b.connection.error == nil else {
      throw SmokeError.failed(
        "Unexpected connection error: \(a.connection.error ?? b.connection.error ?? "")")
    }
    driver.cancel()
    a.connection.send(.leave)
    try await checkApplicationFlow(server)
    print(
      "PASS: native URLSession/Codable hello, room, settings, ready, bots, inputs, snapshots, error, resume, results, matching hash, profile, rematch and leave (\(a.snapshots + b.snapshots) snapshots); real AppModel host/guest auto-ready, start, race, results, final standings and lobby return."
    )
  }
  @MainActor static func checkApplicationFlow(_ server: String) async throws {
    let domain = "dev.nitrotots.protocol.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: domain) else {
      throw SmokeError.failed("Test preferences")
    }
    defer { defaults.removePersistentDomain(forName: domain) }
    let launch = LaunchConfig(
      environment: [
        "NT_TEST": "1", "NT_SCREEN": "online", "NT_MODE": "battle", "NT_SERVER": server,
      ], arguments: [])
    let host = AppModel(defaults: defaults, launch: launch)
    let guest = AppModel(defaults: defaults, launch: launch)
    defer {
      host.connection.disconnect()
      guest.connection.disconnect()
    }
    host.preferences.name = "Model Host"
    guest.preferences.name = "Model Guest"
    host.settings.battleSeconds = 30
    host.settings.trackId = "bowl"
    host.settings.maxPlayers = 4
    host.connect(.create(host.settings))
    try await until("application room") { host.room != nil }
    guest.connect(.join(host.roomCode))
    try await until("application ready-up and start") {
      host.screen == .race && guest.screen == .race
    }
    let driver = Task { @MainActor in
      while !Task.isCancelled {
        host.advance(tickDt)
        guest.advance(tickDt)
        host.session?.events.removeAll()
        guest.session?.events.removeAll()
        try? await Task.sleep(for: .milliseconds(33))
      }
    }
    defer { driver.cancel() }
    try await until("application automatic next/final standings", seconds: 45) {
      host.matchFinished && guest.matchFinished
    }
    guard host.screen == .podium, guest.screen == .podium, host.races.count == 1,
      host.table == guest.table,
      host.connection.error == nil, guest.connection.error == nil
    else {
      throw SmokeError.failed(
        "Application match flow failed: screens \(host.screen)/\(guest.screen), races \(host.races.count)/\(guest.races.count), equal table \(host.table == guest.table), errors \(host.connection.error ?? "none") / \(guest.connection.error ?? "none")"
      )
    }
    host.returnToLobby()
    var profile = guest.preferences
    profile.name = "Model Lobby"
    guest.connection.sendProfile(profile)
    try await until("application finished-room broadcast") {
      host.room?.players.contains(where: { $0.name == "Model Lobby" }) == true
    }
    guard host.screen == .lobby else { throw SmokeError.failed("Room update reopened results") }
    host.leave()
    guest.leave()
  }
}
