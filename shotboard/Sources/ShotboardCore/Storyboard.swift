import Foundation

struct InkPoint: Codable, Equatable {
  var x: Double
  var y: Double
}

enum InkColor: String, Codable, CaseIterable {
  case graphite, shadow, mist, yellow, ivory
}

struct InkStroke: Codable, Equatable, Identifiable {
  var id = UUID()
  var points: [InkPoint]
  var color: InkColor = .graphite
  var width: Double = 0.003
  var filled = false
}

enum FrameRatio: String, Codable, CaseIterable {
  case cinema = "2.39:1"
  case wide = "16:9"
  case academy = "4:3"

  var value: Double {
    switch self {
    case .cinema: 2.39
    case .wide: 16.0 / 9.0
    case .academy: 4.0 / 3.0
    }
  }
}

enum ShotSize: String, Codable, CaseIterable {
  case wide = "Wide"
  case medium = "Medium"
  case closeUp = "Close-up"
  case detail = "Detail"
  case overhead = "Overhead"
}

enum CameraMove: String, Codable, CaseIterable {
  case locked = "Locked off"
  case pan = "Pan"
  case tilt = "Tilt"
  case dolly = "Dolly in"
  case tracking = "Tracking"
  case handheld = "Handheld"
}

struct Scene: Codable, Equatable, Identifiable {
  var id = UUID()
  var title: String
  var location: String
}

struct Shot: Codable, Equatable, Identifiable {
  var id = UUID()
  var sceneID: UUID
  var title: String
  var size: ShotSize = .wide
  var movement: CameraMove = .locked
  var duration: Int = 5
  var notes = ""
  var ratio: FrameRatio = .cinema
  var strokes: [InkStroke] = []
}

struct Storyboard: Codable, Equatable, Identifiable {
  var id = UUID()
  var title: String
  var subtitle: String
  var scenes: [Scene]
  var shots: [Shot]
  var updatedAt = Date()
  var schemaVersion = 1

  var runtime: Int { shots.reduce(0) { $0 + $1.duration } }
  var runtimeLabel: String { Self.timecode(runtime) }

  static func timecode(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }

  mutating func moveShot(_ id: UUID, by offset: Int) {
    guard let index = shots.firstIndex(where: { $0.id == id }) else { return }
    let destination = min(max(index + offset, 0), shots.count - 1)
    guard destination != index else { return }
    let shot = shots.remove(at: index)
    shots.insert(shot, at: destination)
  }

  func shotIndex(at elapsed: Int) -> Int? {
    guard elapsed >= 0 else { return nil }
    var start = 0
    for (index, shot) in shots.enumerated() {
      start += shot.duration
      if elapsed < start { return index }
    }
    return nil
  }

  func validated() throws -> Storyboard {
    guard schemaVersion == 1 else { throw ProjectError.unsupportedVersion }
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !scenes.isEmpty, !shots.isEmpty,
      Set(shots.map(\.id)).count == shots.count,
      Set(scenes.map(\.id)).count == scenes.count
    else { throw ProjectError.invalidProject }
    let sceneIDs = Set(scenes.map(\.id))
    for shot in shots {
      guard sceneIDs.contains(shot.sceneID), (1...120).contains(shot.duration),
        !shot.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { throw ProjectError.invalidProject }
      for stroke in shot.strokes {
        guard stroke.width.isFinite, (0.0001...0.1).contains(stroke.width),
          !stroke.points.isEmpty,
          stroke.points.allSatisfy({
            $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x)
              && (0...1).contains($0.y)
          })
        else { throw ProjectError.invalidProject }
      }
    }
    return self
  }

  static func empty() -> Storyboard {
    let scene = Scene(title: "Opening scene", location: "EXT. / DAY")
    return Storyboard(
      title: "Untitled film", subtitle: "A new story starts with one frame.",
      scenes: [scene], shots: [Shot(sceneID: scene.id, title: "The first frame")]
    )
  }
}

enum ProjectError: LocalizedError {
  case unsupportedVersion, invalidProject
  var errorDescription: String? {
    switch self {
    case .unsupportedVersion: "This project was created with an unsupported file version."
    case .invalidProject:
      "This project contains invalid storyboard data. Your current film is safe."
    }
  }
}

struct ProjectArchive {
  let directory: URL

  func save(_ project: Storyboard) throws {
    _ = try project.validated()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(project)
    try data.write(to: url(for: project.id), options: .atomic)
  }

  func load(_ url: URL) throws -> Storyboard {
    try JSONDecoder().decode(Storyboard.self, from: Data(contentsOf: url)).validated()
  }

  func list() throws -> [Storyboard] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    let urls = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    return try urls.filter { $0.pathExtension == "shotboard" }
      .map { try load($0) }.sorted { $0.updatedAt > $1.updatedAt }
  }

  func url(for id: UUID) -> URL {
    directory.appendingPathComponent(id.uuidString).appendingPathExtension("shotboard")
  }
}
