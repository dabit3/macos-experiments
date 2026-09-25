import Foundation

enum Layer: String, CaseIterable, Codable, Identifiable {
  case rain, ocean, wind, brown

  var id: String { rawValue }
  var title: String { self == .brown ? "Brown noise" : rawValue.capitalized }
  var subtitle: String {
    switch self {
    case .rain: "Soft rainfall"
    case .ocean: "Rolling tide"
    case .wind: "Night air"
    case .brown: "Deep noise"
    }
  }
  var symbol: String {
    switch self {
    case .rain: "cloud.rain"
    case .ocean: "water.waves"
    case .wind: "wind"
    case .brown: "waveform"
    }
  }
}

struct Mix: Codable, Equatable {
  var levels: [Double] = [0.65, 0.45, 0, 0]
  var master: Double = 0.7

  var activeCount: Int { levels.filter { $0 > 0 }.count }

  mutating func set(_ layer: Layer, to value: Double) {
    levels[Layer.allCases.firstIndex(of: layer)!] = Self.clamp(value)
  }

  func level(_ layer: Layer) -> Double {
    levels[Layer.allCases.firstIndex(of: layer)!]
  }

  static func clamp(_ value: Double) -> Double {
    value.isFinite ? min(1, max(0, value)) : 0
  }

  func sanitized() -> Mix {
    Mix(
      levels: (0..<4).map { $0 < levels.count ? Self.clamp(levels[$0]) : 0 },
      master: Self.clamp(master))
  }
}

struct SavedScene: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var note: String
  var mix: Mix

  static let originals = [
    SavedScene(name: "Moonlit shore", note: "Rain over a sleeping sea", mix: Mix()),
    SavedScene(
      name: "Cabin in the rain", note: "A soft roof. A world away.",
      mix: Mix(levels: [0.8, 0, 0.25, 0.15], master: 0.7)),
    SavedScene(
      name: "After the world", note: "Low, warm and wonderfully still",
      mix: Mix(levels: [0, 0, 0.2, 0.75], master: 0.7)),
  ]
}

struct Preferences: Codable {
  var mix = Mix()
  var sceneName = "Moonlit shore"
  var scenes: [SavedScene] = []
  var fadeSeconds: Double = 8
  var haptics = true

  static func load(from defaults: UserDefaults) -> Preferences {
    guard let data = defaults.data(forKey: "hush.preferences"),
      var value = try? JSONDecoder().decode(Preferences.self, from: data)
    else { return Preferences() }
    value.mix = value.mix.sanitized()
    value.scenes = value.scenes.map {
      var scene = $0
      scene.mix = scene.mix.sanitized()
      return scene
    }
    value.fadeSeconds = [3.0, 8.0, 15.0].contains(value.fadeSeconds) ? value.fadeSeconds : 8
    return value
  }

  func save(to defaults: UserDefaults) {
    if let data = try? JSONEncoder().encode(self) {
      defaults.set(data, forKey: "hush.preferences")
    }
  }
}

struct SleepCountdown: Equatable {
  let end: Date
  let duration: TimeInterval
  let fade: TimeInterval

  init(now: Date, duration: TimeInterval, fade: TimeInterval = 10) {
    self.duration = max(1, duration)
    end = now.addingTimeInterval(self.duration)
    self.fade = min(self.duration, max(1, fade))
  }

  func remaining(at date: Date) -> TimeInterval { max(0, end.timeIntervalSince(date)) }
  func gain(at date: Date) -> Double { min(1, remaining(at: date) / fade) }
}
