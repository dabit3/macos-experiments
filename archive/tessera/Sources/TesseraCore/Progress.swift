import Foundation

public struct ChamberState: Codable, Equatable, Sendable {
  public var orientations: [String: Int]
  public var history: [[String: Int]]
  public var moves: Int { history.count }
  public init(chamber: Chamber) {
    orientations = chamber.initial
    history = []
  }
  public mutating func rotate(_ optic: Optic) {
    history.append(orientations)
    orientations[optic.id] = ((orientations[optic.id] ?? optic.initial) + 1) % optic.turns
  }
  public mutating func undo() {
    if let previous = history.popLast() { orientations = previous }
  }
  public mutating func reset(_ chamber: Chamber) {
    guard orientations != chamber.initial else { return }
    history.append(orientations)
    orientations = chamber.initial
  }
}

public struct Progress: Codable, Equatable, Sendable {
  public var current: Int = 0
  public var completed: Set<Int> = []
  public var states: [Int: ChamberState] = [:]
  public init() {}
  public var unlocked: Int { min(Chambers.all.count - 1, (completed.max() ?? -1) + 1) }
  public func encoded() throws -> Data { try JSONEncoder().encode(self) }
  public static func decode(_ data: Data) -> Progress {
    guard var progress = try? JSONDecoder().decode(Progress.self, from: data) else {
      return Progress()
    }
    progress.completed = progress.completed.filter { Chambers.all.indices.contains($0) }
    progress.current = min(max(progress.current, 0), progress.unlocked)
    progress.states = progress.states.filter { Chambers.all.indices.contains($0.key) }
    for (id, state) in progress.states {
      let chamber = Chambers.all[id]
      var valid = state
      valid.orientations = chamber.normalized(state.orientations)
      valid.history = state.history.suffix(500).map { chamber.normalized($0) }
      progress.states[id] = valid
    }
    return progress
  }
}
