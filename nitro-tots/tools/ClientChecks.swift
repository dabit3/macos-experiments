import Foundation

enum CheckError: Error { case failed(String) }
@main struct ClientChecks {
  static func check(_ value: Bool, _ label: String) throws {
    if !value { throw CheckError.failed(label) }
  }
  @MainActor static func main() throws {
    for online in [false, true] {
      for fps in [60, 120] {
        let info = MatchStart(
          code: nil, raceIndex: 0, totalRaces: 1, trackId: "bowl", seed: 4242, laps: 1,
          mode: .battle, battleSeconds: 30, tick: 0,
          racers: [
            RacerProfile(
              slot: 0, playerId: "p", name: "Pip", character: "pip", kart: "jellybean", bot: false,
              platform: "test")
          ])
        let session = RaceSession(info: info, slot: 0, online: online)
        session.sim.phase = .racing
        session.sim.tick = 120
        guard let racer = session.local else { throw CheckError.failed("Missing local racer") }
        racer.item = .rocket
        session.input.add(KartInput(item: true, lookBack: true))
        for _ in 0..<(fps / 30) {
          session.input.add(KartInput(lookBack: true))
          session.advance(1 / Double(fps))
        }
        try check(
          racer.item == nil && session.sim.projectiles.count == 1,
          "Item pulse lost at \(fps) fps, online=\(online)")
        guard let projectile = session.sim.projectiles.first else {
          throw CheckError.failed("Missing rocket")
        }
        try check(abs(wrap(projectile.heading - racer.heading)) > 3, "Reverse throw lost look-back")
        session.input.add(KartInput())
        session.advance(tickDt)
        racer.item = .tripleTurbo
        racer.itemCharges = 3
        session.input.add(KartInput(item: true))
        session.advance(tickDt * 3.1)
        try check(racer.itemCharges == 2, "Slow frame consumed multiple charges")
        session.input.add(KartInput(item: true))
        session.advance(tickDt)
        try check(racer.itemCharges == 1, "Second item tap was lost")
      }
    }
    let domain = "dev.nitrotots.checks.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: domain) else {
      throw CheckError.failed("No test preferences")
    }
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("Migrated Racer", forKey: "flutter.name")
    defaults.set(false, forKey: "flutter.autoAccel")
    let model = AppModel(defaults: defaults)
    model.preferences.musicVolume = 0
    model.preferences.sfxVolume = 0
    try check(
      model.preferences.name == "Migrated Racer" && !model.preferences.autoAccelerate,
      "Legacy profile migration")
    model.preferences.character = "tank"
    model.save()
    let saved = AppModel(defaults: defaults)
    try check(saved.preferences.character == "tank", "Native preferences round-trip")
    model.chooseMode(.grandPrix)
    model.startLocal()
    guard let session = model.session else { throw CheckError.failed("No local race") }
    let profiles = session.sim.racers.map(\.profile)
    try check(
      profiles.count == 8 && Set(profiles.map(\.character)).count == 8,
      "Duplicate characters in cup roster")
    model.steer(0.75)
    model.control("gas", down: true)
    model.control("drift", down: true)
    try check(
      session.input.current.steer == 0.75 && session.input.current.throttle == 1
        && session.input.current.drift, "Touch steering did not survive simultaneous buttons")
    model.control("look", down: true)
    model.control("item", down: true)
    model.control("item", down: false)
    let input = session.input.consume()
    try check(
      input.lookBack && input.item && !session.input.consume().item, "Input edge/held look-back")
    model.control("escape", down: true)
    try check(
      model.paused && session.input.current == KartInput(), "Pause did not clear held controls")
    model.control("escape", down: true)
    let result = profiles.reversed().enumerated().map { i, p in
      RaceResult(
        slot: p.slot, name: p.name, character: p.character, kart: p.kart, bot: p.bot,
        platform: p.platform, place: i + 1, finishTick: 3120, lapTicks: [3000],
        points: pointsForPlace(i + 1), score: 0)
    }
    session.sim.phase = .finished
    session.sim.results = result
    model.advance(0)
    try check(model.screen == .podium && model.races.count == 1, "Local race results flow")
    model.next()
    try check(
      model.session?.sim.racers.map(\.profile) == profiles, "Cup opponents changed identity")
    model.leave()
    model.chooseMode(.timeTrial)
    model.startLocal()
    try check(
      model.session?.sim.racers.count == 1 && model.session?.sim.mode == .timeTrial,
      "Time trial mode")
    let room = Room(
      code: "TEST", hostId: "", status: "matchOver", settings: RoomSettings(), players: [],
      raceIndex: 0, totalRaces: 1, standings: [])
    model.receive(.room(room))
    model.returnToLobby()
    model.receive(.room(room))
    try check(model.screen == .lobby, "Finished room update reopened podium")
    model.matchFinished = true
    let start = MatchStart(
      code: "TEST", raceIndex: 0, totalRaces: 1, trackId: "sprinkle", seed: 1, laps: 1, mode: .race,
      battleSeconds: 30, tick: 0,
      racers: [
        RacerProfile(
          slot: 0, playerId: "", name: "Test", character: "pip", kart: "jellybean", bot: false,
          platform: "test")
      ])
    model.receive(.start(start))
    try check(
      !model.matchFinished && model.races.isEmpty && model.screen == .race,
      "Rematch retained old results")
    model.leave()
    model.connection.disconnect()
    print(
      "PASS: local/network 60/120fps item pulses, reverse throws, charge edges, profile migration/persistence, simultaneous touch controls, pause, cup identity/progression, time trials and lobby/rematch regressions."
    )
  }
}
