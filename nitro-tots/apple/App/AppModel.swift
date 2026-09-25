import Foundation
import Observation

enum Screen: String { case title, garage, track, online, lobby, race, podium, settings }
enum PlayMode: String, CaseIterable, Identifiable {
  case grandPrix = "Grand Prix"
  case quick = "Quick Race"
  case timeTrial = "Time Trial"
  case battle = "Battle"
  var id: String { rawValue }
  var gameMode: GameMode { self == .battle ? .battle : self == .timeTrial ? .timeTrial : .race }
}
@MainActor @Observable final class AppModel {
  var preferences = Preferences()
  var screen = Screen.title
  var playMode = PlayMode.grandPrix
  var settings = RoomSettings()
  var roomCode = ""
  var room: Room?
  var session: RaceSession?
  var paused = false
  var frame = 0
  var races: [RaceHistory] = []
  var table: [Standing] = []
  var matchFinished = false
  var notice: String?
  var pendingRoomAction: ClientMessage?
  let connection = Connection()
  let feedback = Feedback()
  let launch: LaunchConfig
  private let defaults: UserDefaults
  private var raceIndex = 0
  private var tracks: [String] = []
  private var roster: [RacerProfile] = []
  private var seed = 1
  private var totalFrames = 0
  private var testStarted = false
  private var ghosts: [String: Ghost] = [:]
  private var held = Set<String>()
  private var touchSteer = 0.0
  var isHost: Bool { room?.hostId == connection.playerId }
  var online: Bool { session?.online == true || room != nil }
  init(defaults: UserDefaults = .standard, launch: LaunchConfig = LaunchConfig()) {
    self.defaults = defaults
    self.launch = launch
    Assets.registerFonts()
    if launch["STILL"] != "1" {
      preferences = LegacyPreferences.load(defaults)
      ghosts = LegacyPreferences.ghosts(defaults)
      if let data = defaults.data(forKey: "native.preferences"),
        let value = try? JSONDecoder().decode(Preferences.self, from: data)
      {
        preferences = value
      }
      if let data = defaults.data(forKey: "native.ghosts"),
        let value = try? JSONDecoder().decode([String: Ghost].self, from: data)
      {
        ghosts = value
      }
      if !launch.active {
        do { try LegacyPreferences.moveToken(defaults, server: preferences.server) } catch {
          notice = "Could not migrate your saved session to Keychain: \(error.localizedDescription)"
        }
      }
    }
    preferences.server = launch["SERVER"] ?? preferences.server
    if let port = launch["PORT"].flatMap(Int.init),
      var url = URLComponents(string: preferences.server)
    {
      url.port = port
      preferences.server = url.string ?? preferences.server
    }
    preferences.name = launch["NAME"] ?? preferences.name
    preferences.character = launch["CHARACTER"] ?? preferences.character
    preferences.kart = launch["KART"] ?? preferences.kart
    preferences.theme = launch["THEME"] ?? preferences.theme
    if launch.active {
      settings.laps = launch["LAPS"].flatMap(Int.init) ?? 1
      settings.cupId = launch["CUP"] ?? "sugar"
      settings.mode = launch["MODE"].flatMap(GameMode.init(rawValue:)) ?? .race
      settings.grandPrix = settings.mode == .race
      settings.minPlayers = launch["PLAYERS"].flatMap(Int.init) ?? 2
    }
    roomCode = launch["ROOM"] ?? preferences.lastRoom
    connection.onMessage = { [weak self] in self?.receive($0) }
    if let target = launch["SCREEN"].flatMap(Screen.init(rawValue:)) {
      screen = target
    } else if launch.active {
      screen = .online
      pendingRoomAction =
        launch["HOST"] == "1"
        ? .create(settings, code: roomCode.isEmpty ? nil : roomCode) : .join(roomCode)
      connection.connect(preferences, ephemeral: true)
    }
    feedback.playMusic("music_menu", preferences: preferences)
  }
  func save() {
    guard !launch.active && launch["STILL"] != "1" else { return }
    if let data = try? JSONEncoder().encode(preferences) {
      defaults.set(data, forKey: "native.preferences")
    }
    connection.sendProfile(preferences)
    feedback.volumes(preferences)
  }
  func go(_ screen: Screen) {
    feedback.sound("click", preferences: preferences)
    self.screen = screen
  }
  func chooseMode(_ mode: PlayMode) {
    playMode = mode
    settings.mode = mode.gameMode
    settings.grandPrix = mode == .grandPrix
    if mode == .battle {
      settings.trackId = "bowl"
    } else if settings.trackId == "bowl" {
      settings.trackId = "sprinkle"
    }
    go(.track)
  }
  func connect(_ action: ClientMessage? = nil) {
    save()
    pendingRoomAction = action
    if connection.state == .online && connection.serverURL == preferences.server {
      if let action {
        connection.send(action)
        pendingRoomAction = nil
      }
    } else {
      connection.connect(preferences, ephemeral: launch.active)
    }
  }
  func receive(_ message: ServerMessage) {
    switch message {
    case .welcome:
      if let action = pendingRoomAction {
        pendingRoomAction = nil
        connection.send(action)
      }
    case .room(let value):
      room = value
      roomCode = value.code
      preferences.lastRoom = value.code
      if !launch.active, let data = try? JSONEncoder().encode(preferences) {
        defaults.set(data, forKey: "native.preferences")
      }
      if value.status == "lobby" {
        if screen != .garage && screen != .settings { screen = .lobby }
        settings = value.settings
      }
      if launch.active && value.status == "lobby" && !testStarted {
        if !isHost, launch["READY"] != "0",
          let me = value.players.first(where: { $0.id == connection.playerId }), !me.ready
        {
          connection.send(.ready(true))
        }
        if isHost
          && value.players.filter({ $0.connected }).count
            >= (launch["PLAYERS"].flatMap(Int.init) ?? 2)
          && value.players.allSatisfy({ $0.ready || $0.host })
        {
          testStarted = true
          connection.send(.start)
        }
      }
    case .start(let info):
      guard let me = info.racers.first(where: { $0.playerId == connection.playerId }) else {
        notice = "Your seat is missing from the server's roster."
        return
      }
      if info.raceIndex == 0 {
        races = []
        table = []
        matchFinished = false
      }
      let race = RaceSession(info: info, slot: me.slot, online: true)
      race.send = { [weak self] in self?.connection.send($0) }
      if launch.active {
        race.autopilot = Autopilot(lane: launch["LANE"].flatMap(Double.init) ?? -3)
      }
      begin(race)
    case .snapshot(let snapshot): session?.apply(snapshot)
    case .raceFinished(let outcome):
      if !races.indices.contains(outcome.raceIndex) {
        races.append(RaceHistory(trackId: outcome.trackId, results: outcome.results))
      }
      table = outcome.standings
      matchFinished = false
      held.removeAll()
      paused = false
      screen = .podium
      feedback.playMusic("music_menu", preferences: preferences)
      feedback.sound("finish", preferences: preferences)
      if launch.active && isHost { connection.send(.next) }
    case .matchOver(let outcome):
      races = outcome.races
      table = outcome.standings
      matchFinished = true
      screen = .podium
      if launch.active {
        connection.send(
          .report(
            hash: outcome.hash, standings: outcome.standings, lastTick: session?.sim.tick ?? 0,
            frames: totalFrames))
      }
    case .playerLeft(let value):
      if value.playerId == connection.playerId {
        room = nil
        session = nil
        screen = .online
      }
    default: break
    }
  }
  func startLocal() {
    if room != nil {
      connection.send(.leave)
      room = nil
    }
    races = []
    table = []
    matchFinished = false
    raceIndex = 0
    tracks =
      playMode == .grandPrix ? Catalog.shared.cup(settings.cupId).trackIds : [settings.trackId]
    seed = Int.random(in: 1...1_000_000)
    roster = [
      RacerProfile(
        slot: 0, playerId: "local", name: preferences.name,
        character: preferences.character, kart: preferences.kart, bot: false,
        platform: Connection.platform)
    ]
    if playMode != .timeTrial && settings.fillBots {
      let rng = Rng(seed)
      var pool = Catalog.shared.characters.filter { $0.id != preferences.character }
      for i in stride(from: pool.count - 1, through: 1, by: -1) {
        pool.swapAt(i, rng.nextInt(i + 1))
      }
      for i in 1..<settings.maxPlayers {
        let c = pool[(i - 1) % pool.count]
        let k = Catalog.shared.karts[rng.nextInt(Catalog.shared.karts.count)]
        roster.append(
          RacerProfile(
            slot: i, playerId: "", name: c.name, character: c.id, kart: k.id, bot: true,
            platform: "bot"))
      }
    }
    startLocalRace()
  }
  private func startLocalRace() {
    let info = MatchStart(
      code: nil, raceIndex: raceIndex, totalRaces: tracks.count,
      trackId: tracks[raceIndex], seed: seed + raceIndex * 997, laps: settings.laps,
      mode: playMode.gameMode, battleSeconds: settings.battleSeconds, tick: 0, racers: roster)
    let race = RaceSession(info: info, slot: 0, online: false, skill: settings.botSkill)
    if let ghost = ghosts[info.trackId], ghost.laps == info.laps { race.ghost = ghost }
    begin(race)
  }
  private func begin(_ race: RaceSession) {
    session = race
    held.removeAll()
    touchSteer = 0
    paused = false
    screen = .race
    race.input.add(KartInput(throttle: preferences.autoAccelerate ? 1 : 0))
    feedback.playMusic("music_race", preferences: preferences)
  }
  func advance(_ delta: Double) {
    guard let session, screen == .race else { return }
    session.paused = paused
    let before = session.sim.tick
    session.advance(delta)
    frame &+= 1
    totalFrames += 1
    if session.sim.phase == .countdown && before / 30 != session.sim.tick / 30 {
      feedback.sound("countdown", preferences: preferences)
    }
    for event in session.events where event.r == nil || event.r == session.localSlot {
      feedback.event(event.e, preferences: preferences)
    }
    if !session.online && session.sim.phase == .finished {
      guard let results = session.sim.results else { return }
      races.append(RaceHistory(trackId: session.info.trackId, results: results))
      table = standings(races.map(\.results))
      matchFinished = raceIndex + 1 >= tracks.count
      if playMode == .timeTrial, let me = results.first {
        let old = ghosts[session.info.trackId]
        if old == nil || old?.laps != session.info.laps || me.raceTicks < (old?.ticks ?? Int.max) {
          ghosts[session.info.trackId] = Ghost(
            ticks: me.raceTicks, laps: session.info.laps, frames: session.recording)
          if let data = try? JSONEncoder().encode(ghosts) {
            defaults.set(data, forKey: "native.ghosts")
          }
        }
      }
      held.removeAll()
      screen = .podium
      feedback.playMusic("music_menu", preferences: preferences)
      feedback.sound("finish", preferences: preferences)
    }
  }
  func next() {
    if online {
      connection.send(.next)
    } else if !matchFinished {
      raceIndex += 1
      startLocalRace()
    } else {
      startLocal()
    }
  }
  func returnToLobby() {
    session = nil
    paused = false
    held.removeAll()
    go(room == nil ? .title : .lobby)
  }
  func leave() {
    if room != nil { connection.send(.leave) }
    room = nil
    session = nil
    held.removeAll()
    paused = false
    screen = .title
    feedback.playMusic("music_menu", preferences: preferences)
  }
  func control(_ key: String, down: Bool) {
    if ["escape", "p"].contains(key) {
      if down && screen == .race {
        paused.toggle()
        held.removeAll()
        touchSteer = 0
        session?.input = InputBuffer()
      }
      return
    }
    if down { held.insert(key) } else { held.remove(key) }
    func has(_ keys: [String]) -> Bool { keys.contains { held.contains($0) } }
    let itemKeys = ["z", "x", "return", "e", "control", "item"]
    session?.input.add(
      KartInput(
        throttle: has(["down", "s", "brake"])
          ? -1 : has(["up", "w", "gas"]) || preferences.autoAccelerate ? 1 : 0,
        steer: clamp(
          touchSteer + (has(["right", "d"]) ? 1.0 : 0) - (has(["left", "a"]) ? 1.0 : 0), -1, 1),
        drift: has(["space", "shift", "drift"]), item: down && itemKeys.contains(key),
        lookBack: has(["q", "option", "look"])))
  }
  func steer(_ value: Double) {
    touchSteer = value
    guard let session else { return }
    var input = session.input.current
    input.steer = value
    session.input.add(input)
  }
  func clearControls() {
    held.removeAll()
    touchSteer = 0
    session?.input = InputBuffer()
    paused = true
  }
  func bestTime(_ track: String) -> Int? { ghosts[track]?.ticks }
}
