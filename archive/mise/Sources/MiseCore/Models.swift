import Foundation

struct Ingredient: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let name: String
  let amount: Double
  let unit: String
  let note: String

  func quantity(servings: Int, base: Int) -> String {
    Quantity.format(amount * Double(servings) / Double(max(base, 1)))
      + (unit.isEmpty ? "" : " \(unit)")
  }
}

enum Quantity {
  static func format(_ value: Double) -> String {
    let whole = Int(value)
    let fraction = value - Double(whole)
    let fractions: [(Double, String)] = [
      (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"),
      (2.0 / 3, "⅔"), (0.75, "¾"),
    ]
    if fraction < 0.005 { return "\(whole)" }
    if let match = fractions.first(where: { abs($0.0 - fraction) < 0.005 }) {
      return (whole > 0 ? "\(whole)" : "") + match.1
    }
    return value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

struct CookingStep: Codable, Equatable, Sendable {
  let title: String
  let instruction: String
  let tip: String
  let timerName: String?
  let timerSeconds: Int?
}

struct Substitution: Codable, Equatable, Sendable {
  let original: String
  let alternative: String
}

struct Recipe: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let subtitle: String
  let category: String
  let minutes: Int
  let baseServings: Int
  let story: String
  let ingredients: [Ingredient]
  let steps: [CookingStep]
  let substitutions: [Substitution]
}

struct CookingSession: Codable, Equatable, Sendable {
  var servings: Int = 2
  var prepared: Set<String> = []
  var step: Int = 0
  var started = false
  var completed = false

  mutating func adjustServings(by delta: Int) {
    servings = min(12, max(1, servings + delta))
  }

  mutating func moveStep(by delta: Int, count: Int) {
    step = min(max(count - 1, 0), max(0, step + delta))
  }
}

struct KitchenTimer: Codable, Identifiable, Equatable, Sendable {
  let id: UUID
  let recipeID: String
  let name: String
  let duration: TimeInterval
  var deadline: Date?
  var pausedRemaining: TimeInterval

  init(recipeID: String, name: String, seconds: Int, now: Date = .now) {
    id = UUID()
    self.recipeID = recipeID
    self.name = name
    duration = TimeInterval(max(1, seconds))
    deadline = now.addingTimeInterval(duration)
    pausedRemaining = duration
  }

  func remaining(at now: Date = .now) -> TimeInterval {
    max(0, deadline.map { $0.timeIntervalSince(now) } ?? pausedRemaining)
  }

  func isFinished(at now: Date = .now) -> Bool { remaining(at: now) <= 0 }
  var isPaused: Bool { deadline == nil }

  mutating func togglePause(at now: Date = .now) {
    if deadline != nil {
      pausedRemaining = remaining(at: now)
      deadline = nil
    } else if pausedRemaining > 0 {
      deadline = now.addingTimeInterval(pausedRemaining)
    }
  }

  mutating func restart(at now: Date = .now) {
    pausedRemaining = duration
    deadline = now.addingTimeInterval(duration)
  }

  static func clock(_ seconds: TimeInterval) -> String {
    let total = Int(ceil(max(0, seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}

struct KitchenState: Codable, Equatable, Sendable {
  var favorites: Set<String> = []
  var sessions: [String: CookingSession] = [:]
  var timers: [KitchenTimer] = []
  var activeRecipeID: String?
  var isCooking = false
}

enum KitchenPersistence {
  static func load(from url: URL) throws -> KitchenState {
    try JSONDecoder().decode(KitchenState.self, from: Data(contentsOf: url))
  }

  static func save(_ state: KitchenState, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(state).write(to: url, options: .atomic)
  }
}
