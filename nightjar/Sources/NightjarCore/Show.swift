import Foundation

public struct Vector3: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public var z: Double

  public init(_ x: Double, _ y: Double, _ z: Double) {
    self.x = x
    self.y = y
    self.z = z
  }

  public static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self {
    .init(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
  }
}

public struct LightColor: Codable, Equatable, Sendable {
  public var r: Double
  public var g: Double
  public var b: Double

  public init(_ r: Double, _ g: Double, _ b: Double) {
    self.r = r
    self.g = g
    self.b = b
  }

  public var hex: String {
    String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
  }

  public static let amber = Self(1, 0.53, 0.19)
  public static let cyan = Self(0.12, 0.82, 1)
  public static let violet = Self(0.52, 0.25, 1)
  public static let rose = Self(1, 0.19, 0.43)
  public static let mint = Self(0.19, 1, 0.64)
  public static let frost = Self(0.83, 0.9, 1)

  public static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self {
    .init(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
  }
}

public struct Fixture: Codable, Equatable, Identifiable, Sendable {
  public var id: Int
  public var name: String
  public var position: Vector3
  public var target: Vector3
  public var color: LightColor
  public var intensity: Double
  public var beam: Double

  public init(
    id: Int, name: String, position: Vector3, target: Vector3,
    color: LightColor, intensity: Double, beam: Double
  ) {
    self.id = id
    self.name = name
    self.position = position
    self.target = target
    self.color = color
    self.intensity = intensity
    self.beam = beam
  }

  public static func crossfade(from: [Self], to: [Self], progress: Double) -> [Self] {
    let t = min(1, max(0, progress))
    if t == 1 { return to }
    let eased = t * t * (3 - 2 * t)
    let source = Dictionary(uniqueKeysWithValues: from.map { ($0.id, $0) })
    return to.map { destination in
      guard let start = source[destination.id] else { return destination }
      if t == 0 { return start }
      var result = destination
      result.position = .mix(start.position, destination.position, eased)
      result.target = .mix(start.target, destination.target, eased)
      result.color = .mix(start.color, destination.color, eased)
      result.intensity = start.intensity + (destination.intensity - start.intensity) * eased
      result.beam = start.beam + (destination.beam - start.beam) * eased
      return result
    }
  }
}

public struct Cue: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var fade: Double
  public var hold: Double
  public var fixtures: [Fixture]

  public init(name: String, fade: Double = 3, hold: Double = 2, fixtures: [Fixture]) {
    self.id = UUID()
    self.name = name
    self.fade = fade
    self.hold = hold
    self.fixtures = fixtures
  }
}

public struct Show: Codable, Equatable, Sendable {
  public var version: Int
  public var name: String
  public var live: [Fixture]
  public var cues: [Cue]

  public init(name: String, live: [Fixture], cues: [Cue]) {
    self.version = 1
    self.name = name
    self.live = live
    self.cues = cues
  }

  public func validated() throws -> Self {
    guard version == 1 else {
      throw ShowError.invalid("This show uses an unsupported file version.")
    }
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 120 else {
      throw ShowError.invalid("The show needs a title of 1–120 characters.")
    }
    guard cues.count <= 100, Set(cues.map(\.id)).count == cues.count else {
      throw ShowError.invalid("The cue list is invalid or exceeds 100 cues.")
    }
    try Self.validateFixtures(live)
    for cue in cues {
      guard !cue.name.isEmpty, cue.name.count <= 120,
        (0.2...30).contains(cue.fade), (0...60).contains(cue.hold)
      else { throw ShowError.invalid("Cue names or timings are outside the supported range.") }
      try Self.validateFixtures(cue.fixtures)
    }
    return self
  }

  private static func validateFixtures(_ fixtures: [Fixture]) throws {
    guard fixtures.count == 6, Set(fixtures.map(\.id)) == Set(0..<6) else {
      throw ShowError.invalid("Each look must contain exactly six unique fixtures.")
    }
    for f in fixtures {
      guard (0...1).contains(f.intensity), (10...70).contains(f.beam),
        (0...1).contains(f.color.r), (0...1).contains(f.color.g), (0...1).contains(f.color.b),
        (-6...6).contains(f.position.x), (3...8).contains(f.position.y),
        (-4...5).contains(f.position.z),
        (-6...6).contains(f.target.x), (0...2.5).contains(f.target.y),
        (-3.5...4).contains(f.target.z), !f.name.isEmpty, f.name.count <= 60
      else { throw ShowError.invalid("A fixture contains an invalid position, color or level.") }
    }
  }

  public func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(validated())
  }

  public static func decode(_ data: Data) throws -> Self {
    guard data.count < 5_000_000 else {
      throw ShowError.invalid("This file is too large to be a Nightjar show.")
    }
    return try JSONDecoder().decode(Self.self, from: data).validated()
  }

  public var cueSheet: String {
    let header = [
      "Show", "Cue", "Look", "Fade seconds", "Hold seconds", "Fixture", "Name", "Level percent",
      "Color sRGB", "Beam degrees", "Position X", "Position Y", "Position Z", "Aim X", "Aim Y",
      "Aim Z",
    ]
    var rows = [header]
    for (index, cue) in cues.enumerated() {
      for fixture in cue.fixtures {
        rows.append([
          name, "\(index + 1)", cue.name, Self.decimal(cue.fade), Self.decimal(cue.hold),
          "\(fixture.id + 1)", fixture.name, Self.decimal(fixture.intensity * 100),
          fixture.color.hex, Self.decimal(fixture.beam),
          Self.decimal(fixture.position.x), Self.decimal(fixture.position.y),
          Self.decimal(fixture.position.z), Self.decimal(fixture.target.x),
          Self.decimal(fixture.target.y), Self.decimal(fixture.target.z),
        ])
      }
    }
    return rows.map { $0.map(Self.csvCell).joined(separator: ",") }.joined(separator: "\r\n")
      + "\r\n"
  }

  private static func decimal(_ value: Double) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
  }

  private static func csvCell(_ text: String) -> String {
    // Prevent spreadsheet formula evaluation in user-editable labels.
    let safe =
      ["=", "+", "-", "@"].contains(String(text.prefix(1))) && Double(text) == nil
      ? "'" + text : text
    return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  public static var sample: Self {
    let positions: [Vector3] = [
      .init(-4.5, 5.5, 3), .init(4.5, 5.5, 3),
      .init(-4, 5.8, -2.6), .init(4, 5.8, -2.6),
      .init(-1.5, 6.5, -1), .init(1.5, 6.5, -1),
    ]
    let names = ["Key left", "Key right", "Rim left", "Rim right", "Special A", "Special B"]
    let targets: [Vector3] = [
      .init(-1.3, 0, 0.8), .init(1.3, 0, 0.8),
      .init(-0.7, 0.8, -0.5), .init(0.7, 0.8, -0.5),
      .init(-2.8, 0, 0), .init(2.8, 0, 0),
    ]
    let colors: [LightColor] = [.amber, .cyan, .violet, .cyan, .amber, .violet]
    let base = (0..<6).map { i in
      Fixture(
        id: i, name: names[i], position: positions[i], target: targets[i],
        color: colors[i], intensity: [0.85, 0.8, 0.65, 0.75, 0.65, 0.7][i],
        beam: i < 4 ? 38 : 24
      )
    }
    let rose = base.enumerated().map { i, fixture in
      var f = fixture
      f.color = i.isMultiple(of: 2) ? .rose : .violet
      f.intensity = i < 4 ? 0.9 : 0.4
      f.beam = 44
      return f
    }
    let frost = base.enumerated().map { i, fixture in
      var f = fixture
      f.color = i < 2 ? .frost : .cyan
      f.intensity = i < 2 ? 0.15 : 0.85
      f.beam = 22
      f.target.x *= 0.6
      return f
    }
    return Self(
      name: "The midnight room", live: base,
      cues: [
        Cue(name: "Blue hour", fixtures: base),
        Cue(name: "Velvet bloom", fade: 4, hold: 2, fixtures: rose),
        Cue(name: "After the rain", fade: 4, hold: 3, fixtures: frost),
      ]
    )
  }
}

public enum ShowError: LocalizedError {
  case invalid(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

public struct CueClock: Equatable, Sendable {
  public enum Phase: String, Sendable { case fade, hold, finished }
  public let fade: Double
  public let hold: Double
  public private(set) var elapsed: Double = 0

  public init(fade: Double, hold: Double) {
    self.fade = max(0.2, fade)
    self.hold = max(0, hold)
  }

  public var phase: Phase {
    if elapsed < fade { return .fade }
    return elapsed < fade + hold ? .hold : .finished
  }

  public var progress: Double { min(1, max(0, elapsed / fade)) }
  public var totalProgress: Double { min(1, elapsed / (fade + hold)) }

  public mutating func advance(_ delta: Double) {
    guard delta.isFinite, delta > 0 else { return }
    elapsed += delta
  }
}
