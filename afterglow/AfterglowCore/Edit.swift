import Foundation

public enum FilmLook: String, Codable, CaseIterable, Sendable {
  case original = "Original"
  case ember = "Ember"
  case coast = "Coastal"
  case silver = "Silver"
  case dusk = "Dusk"

  public var note: String {
    switch self {
    case .original: "True to the moment"
    case .ember: "Warm highlights · soft shadows"
    case .coast: "Cool air · quiet color"
    case .silver: "Timeless monochrome"
    case .dusk: "Muted color · deep atmosphere"
    }
  }
}

public enum CropFormat: String, Codable, CaseIterable, Sendable {
  case original = "Full"
  case portrait = "4:5"
  case square = "1:1"
  case cinema = "16:9"

  public var ratio: Double? {
    switch self {
    case .original: nil
    case .portrait: 0.8
    case .square: 1
    case .cinema: 16.0 / 9.0
    }
  }
}

public struct Edit: Codable, Equatable, Sendable {
  public var look: FilmLook = .original
  public var exposure: Double = 0
  public var contrast: Double = 1
  public var saturation: Double = 1
  public var warmth: Double = 0
  public var crop: CropFormat = .original
  public var rotation: Int = 0
  public var zoom: Double = 1
  public var panX: Double = 0
  public var panY: Double = 0

  public init() {}

  public func sanitized() -> Edit {
    var result = self
    result.exposure = Self.bound(exposure, -2...2, fallback: 0)
    result.contrast = Self.bound(contrast, 0.5...1.5, fallback: 1)
    result.saturation = Self.bound(saturation, 0...2, fallback: 1)
    result.warmth = Self.bound(warmth, -1...1, fallback: 0)
    result.zoom = Self.bound(zoom, 1...2.5, fallback: 1)
    result.panX = Self.bound(panX, -1...1, fallback: 0)
    result.panY = Self.bound(panY, -1...1, fallback: 0)
    result.rotation = ((rotation % 4) + 4) % 4
    return result
  }

  private static func bound(
    _ value: Double, _ range: ClosedRange<Double>, fallback: Double
  ) -> Double {
    value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
  }
}

public struct EditHistory: Codable, Equatable, Sendable {
  public private(set) var current = Edit()
  public private(set) var undoStack: [Edit] = []
  public private(set) var redoStack: [Edit] = []

  public init() {}
  public var canUndo: Bool { !undoStack.isEmpty }
  public var canRedo: Bool { !redoStack.isEmpty }

  public mutating func apply(_ edit: Edit) {
    let value = edit.sanitized()
    guard value != current else { return }
    undoStack.append(current)
    undoStack = Array(undoStack.suffix(60))
    current = value
    redoStack.removeAll()
  }

  public mutating func undo() {
    guard let previous = undoStack.popLast() else { return }
    redoStack.append(current)
    current = previous
  }

  public mutating func redo() {
    guard let next = redoStack.popLast() else { return }
    undoStack.append(current)
    current = next
  }
}

public struct Project: Codable, Equatable, Sendable {
  public var version = 1
  public var selectedID = "dunes"
  public var photos: [String: EditHistory] = [:]
  public init() {}
}

public enum ProjectFile {
  public static func save(_ project: Project, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(project).write(to: url, options: .atomic)
  }

  public static func load(from url: URL) throws -> Project {
    let project = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url))
    guard project.version == 1 else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return project
  }
}
