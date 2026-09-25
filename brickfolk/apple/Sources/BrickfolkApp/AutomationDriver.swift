import BrickfolkCore
import Foundation

@MainActor
final class AutomationDriver {
  private var reports: Set<String> = []
  private var lastAttempt = Date.distantPast
  private var pendingLaunch = false
  private var lastTick = -1
  private var pilot: AutomationPilot?
  private var matchKey = ""
  func reset() {
    reports = []
    lastAttempt = .distantPast
    pendingLaunch = false
    lastTick = -1
    pilot = nil
    matchKey = ""
  }
  func update(_ client: Client) {
    guard client.status == .connected, let me = client.me else { return }
    report("signedIn", payload: TestReport(name: me.name), key: "signedIn", client: client)
    if client.config.tour {
      report("tour", payload: TestReport(screen: "ready"), key: "tour-ready", client: client)
      return
    }
    guard let room = client.room else {
      guard Date().timeIntervalSince(lastAttempt) > 1 else { return }
      lastAttempt = Date()
      if let code = client.config.party {
        guard let party = client.party else {
          client.send(client.config.host ? .partyCreate(code) : .partyJoin(code))
          return
        }
        report(
          "party", payload: TestReport(code: party.code, members: party.members.count),
          key: "party", client: client)
        if let code = party.roomCode {
          client.send(.roomJoin(code))
          return
        }
        if client.config.host && !pendingLaunch
          && party.members.filter(\.online).count >= client.config.players
        {
          pendingLaunch = true
          client.send(.partyLaunch(client.config.experience, bots: client.config.bots))
        }
      } else if !pendingLaunch {
        pendingLaunch = true
        client.send(.roomCreate(client.config.experience, bots: client.config.bots))
      }
      return
    }
    let key = "\(room.code)-\(room.round)"
    report(
      "launch", payload: TestReport(room: room.code, members: room.members.count),
      key: "launch-\(room.code)", client: client)
    report(
      room.phase.rawValue, payload: TestReport(room: room.code, members: room.members.count),
      key: "\(room.phase.rawValue)-\(key)", client: client, exceptResults: room.phase == .results)
    switch room.phase {
    case .lobby:
      if room.round == 0 && client.config.autoReady
        && room.members.first(where: { $0.id == client.myID })?.ready == false
      {
        if reports.insert("ready-\(key)").inserted { client.send(.ready(true)) }
      }
    case .countdown: break
    case .playing:
      if matchKey != key {
        matchKey = key
        pilot = AutomationPilot(name: me.name)
        lastTick = -1
      }
      guard let frame = client.frame, let content = client.content, frame.tick != lastTick else {
        return
      }
      lastTick = frame.tick
      if let input = pilot?.decide(frame: frame, id: client.myID, content: content) {
        client.input(input)
      }
    case .results:
      if let results = client.results {
        report(
          "results",
          payload: TestReport(
            room: room.code, checksum: results.checksum, experience: results.experience.rawValue,
            round: room.round, entries: results.entries), key: "results-\(key)", client: client)
      }
    }
  }
  func control(_ control: TestControl, client: Client) {
    guard control.platform == nil || control.platform == client.platform else { return }
    switch control.cmd {
    case "leave": client.leaveRoom()
    case "ready": client.send(.ready(true))
    case "report": client.send(.report("ping", TestReport(room: client.room?.code)))
    case "show":
      let screen = control.screen ?? "hub"
      switch screen {
      case "hub", "places": client.selectedTab = "places"
      case "place":
        client.selectedTab = "places"
        client.placeSelection = client.config.experience
      case "avatar", "shop": client.selectedTab = "avatar"
      case "social", "friends": client.selectedTab = "social"
      case "profile": client.selectedTab = "profile"
      case "daily", "settings", "chat": client.requestedSheet = screen
      default: client.error = "Unknown native tour screen: \(screen)"
      }
      client.send(.report("tour", TestReport(screen: screen)))
    default: break
    }
  }
  private func report(
    _ phase: String, payload: TestReport, key: String, client: Client, exceptResults: Bool = false
  ) {
    guard !exceptResults, reports.insert(key).inserted else { return }
    client.send(.report(phase, payload))
  }
}
