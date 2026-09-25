import Foundation

struct Media: Codable, Identifiable, Equatable {
  var id: String
  var name: String
  var detail: String
  var duration: Double
  var path: String
}

struct Clip: Codable, Identifiable, Equatable {
  var id = UUID()
  var mediaID: String
  var inPoint: Double
  var outPoint: Double
  var duration: Double { outPoint - inPoint }
}

enum TitleStyle: String, Codable, CaseIterable {
  case editorial = "Editorial"
  case postcard = "Postcard"
  case minimal = "Minimal"
}

struct Project: Codable, Equatable {
  var version = 1
  var name = "Somewhere, slowly"
  var media: [Media] = []
  var clips: [Clip] = []
  var title = "Somewhere,\nslowly."
  var subtitle = "A LITTLE FURTHER FROM EVERYDAY"
  var titleStyle: TitleStyle = .editorial
  var titleEnabled = true
  var duration: Double { clips.reduce(0) { $0 + $1.duration } }

  func validated() throws -> Project {
    guard version == 1, media.count <= 100, clips.count <= 100,
      Set(media.map(\.id)).count == media.count,
      Set(clips.map(\.id)).count == clips.count,
      name.count <= 150, title.count <= 120, subtitle.count <= 100
    else { throw EditorError.invalidProject }
    for item in media {
      guard item.duration.isFinite, item.duration > 0, !item.path.isEmpty else {
        throw EditorError.invalidProject
      }
    }
    for clip in clips {
      guard let source = media.first(where: { $0.id == clip.mediaID }),
        clip.inPoint.isFinite, clip.outPoint.isFinite,
        clip.inPoint >= 0, clip.outPoint <= source.duration + 0.001,
        clip.duration >= 0.25
      else { throw EditorError.invalidProject }
    }
    return self
  }

  mutating func trim(_ id: UUID, start: Double, end: Double) throws {
    guard let index = clips.firstIndex(where: { $0.id == id }),
      let source = media.first(where: { $0.id == clips[index].mediaID }),
      start.isFinite, end.isFinite, start >= 0, end <= source.duration + 0.001,
      end - start >= 0.25
    else { throw EditorError.invalidTrim }
    clips[index].inPoint = start
    clips[index].outPoint = end
  }

  mutating func move(_ id: UUID, by offset: Int) {
    guard let index = clips.firstIndex(where: { $0.id == id }),
      clips.indices.contains(index + offset)
    else { return }
    clips.swapAt(index, index + offset)
  }

  func clip(at seconds: Double) -> Clip? {
    var end = 0.0
    for clip in clips {
      end += clip.duration
      if seconds < end { return clip }
    }
    return clips.last
  }
}

enum EditorError: LocalizedError {
  case invalidProject, invalidTrim, missingMedia, noVideo
  case exportFailed(String)
  var errorDescription: String? {
    switch self {
    case .invalidProject: return "This project is invalid or uses an unsupported version."
    case .invalidTrim:
      return "Keep at least 0.25 seconds, with In before Out and inside the source."
    case .missingMedia:
      return "A source movie is missing. Restore it, or remove the clip and import it again."
    case .noVideo: return "Choose a playable video file. Audio-only files are not supported."
    case .exportFailed(let reason): return reason
    }
  }
}

enum Storage {
  static var root: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Cutline", isDirectory: true)
  }
  static var autosave: URL { root.appendingPathComponent("Last Session.cutline") }
  static func prepare() throws {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }
  static func save(_ project: Project, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(project.validated()).write(to: url, options: .atomic)
  }
  static func load(_ url: URL) throws -> Project {
    try JSONDecoder().decode(Project.self, from: Data(contentsOf: url)).validated()
  }
}

func timecode(_ seconds: Double) -> String {
  let frames = Int(max(0, seconds) * 24)
  return String(format: "%02d:%02d:%02d", frames / 1440, (frames / 24) % 60, frames % 24)
}
