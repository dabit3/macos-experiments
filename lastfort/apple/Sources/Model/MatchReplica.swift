import Combine
import Foundation

@MainActor final class MatchReplica: ObservableObject {
  let start: MatchStart
  let island: Island
  @Published var players: [Int: Player]
  @Published var state: MatchState?
  @Published var localID = 0
  @Published var summary: MatchSummary?
  @Published var feed: [String] = []
  var loot: [Loot] = []
  var effects: [(event: GameEvent, date: Date)] = []
  var previousPlayers: [Int: Player] = [:]
  var lastSnapshot = Date()
  var snapshots = 0
  private var sequence = 0
  private var pending: [InputFrame] = []
  var me: Player? { players[localID] }
  /// Snapshots only carry players inside the local interest radius, so names
  /// fall back to the full roster sent at match start.
  func name(_ id: Int?) -> String? {
    guard let id else { return nil }
    return players[id]?.n ?? start.players.first { $0.id == id }?.n
  }
  var target: Player? {
    guard let me else { return nil }
    return me.s == .eliminated ? players[me.spec ?? 0] ?? me : me
  }
  init(_ start: MatchStart) {
    self.start = start
    island = Island(rules: start.rules, seed: start.seed)
    players = Dictionary(uniqueKeysWithValues: start.players.map { ($0.id, $0) })
  }
  func apply(_ snapshot: Snapshot) {
    snapshots += 1
    previousPlayers = players
    lastSnapshot = Date()
    state = snapshot.match
    for structure in snapshot.structs {
      island.structures[island.key(structure.gx, structure.gy)] = structure
    }
    let gone = Set(snapshot.gone)
    island.structures = island.structures.filter { !gone.contains($0.value.id) }
    for node in snapshot.nodes { island.nodes[node.id]?.hp = node.hp }
    for chest in snapshot.chests { island.chests[chest.id]?.o = chest.o }
    loot = snapshot.loot
    var updated = Dictionary(uniqueKeysWithValues: snapshot.players.map { ($0.id, $0) })
    if var local = updated[localID] {
      let acknowledged = local.seq ?? 0
      sequence = max(sequence, acknowledged)
      pending.removeAll { $0.seq <= acknowledged }
      if local.s != .alive { pending.removeAll() }
      for frame in pending { island.move(&local, frame: frame) }
      updated[localID] = local
    }
    players = updated
    for event in snapshot.ev {
      effects.append((event, Date()))
      if event.e == "eliminated" {
        let victim = name(event.p) ?? "#\(event.p ?? 0)"
        let killer = name(event.by) ?? "Storm"
        feed.insert("\(killer) eliminated \(victim)", at: 0)
      } else if event.e == "thanked" {
        feed.insert("\(name(event.p) ?? "Player") thanked the driver", at: 0)
      }
    }
    feed = Array(feed.prefix(5))
    effects.removeAll { $0.date.timeIntervalSinceNow < -1 }
  }
  func input(mx: Double, my: Double, aim: Double, fire: Bool, sprint: Bool, actions: [GameAction])
    -> InputFrame?
  {
    guard var local = me, summary == nil else { return nil }
    sequence += 1
    let length = max(1, hypot(mx, my))
    func quantize(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
    let frame = InputFrame(
      seq: sequence, mx: quantize(mx / length), my: quantize(my / length),
      aim: quantize(aim), fire: fire, sprint: sprint, act: actions)
    if local.s == .alive {
      island.move(&local, frame: frame)
      players[localID] = local
      pending.append(frame)
      if pending.count > 64 { pending.removeFirst(pending.count - 64) }
    }
    return frame
  }
  func position(_ player: Player, at date: Date) -> (x: Double, y: Double) {
    guard player.id != localID, let prior = previousPlayers[player.id], prior.s == player.s else {
      return (player.x, player.y)
    }
    let alpha = min(1, max(0, date.timeIntervalSince(lastSnapshot) / start.rules.dt))
    return (prior.x + (player.x - prior.x) * alpha, prior.y + (player.y - prior.y) * alpha)
  }
}
