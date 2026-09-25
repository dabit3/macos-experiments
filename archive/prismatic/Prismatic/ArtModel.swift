import Foundation
import Observation

struct ArtPoint: Codable, Equatable {
  var x: Double
  var y: Double

  func transformed(axis: Int, count: Int, mirrored: Bool) -> ArtPoint {
    let angle = Double(axis) * 2 * .pi / Double(max(1, count))
    let dx = (x - 0.5) * (mirrored ? -1 : 1)
    let dy = y - 0.5
    return ArtPoint(
      x: 0.5 + dx * cos(angle) - dy * sin(angle),
      y: 0.5 + dx * sin(angle) + dy * cos(angle))
  }
}

enum Brush: String, Codable, CaseIterable, Identifiable {
  case silk, ink, stardust
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var subtitle: String {
    switch self {
    case .silk: "Light with a soft halo"
    case .ink: "A clean, flowing line"
    case .stardust: "A trail of tiny constellations"
    }
  }
}

struct Pigment: Identifiable, Equatable {
  var name: String
  var hex: String
  var id: String { hex }
}

enum Palette: String, CaseIterable, Identifiable {
  case aurora, ember, mineral
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
  var colors: [Pigment] {
    switch self {
    case .aurora:
      [
        Pigment(name: "Moonstone", hex: "EFE8D8"), Pigment(name: "Mint", hex: "83EAC3"),
        Pigment(name: "Lagoon", hex: "6FCFEF"), Pigment(name: "Iris", hex: "ADA2FA"),
        Pigment(name: "Orchid", hex: "EF9CDD"), Pigment(name: "Citron", hex: "E2DE9D"),
      ]
    case .ember:
      [
        Pigment(name: "Pearl", hex: "FFF0D5"), Pigment(name: "Honey", hex: "EFC87E"),
        Pigment(name: "Apricot", hex: "FFA274"), Pigment(name: "Coral", hex: "F47B7F"),
        Pigment(name: "Rose", hex: "E6A6B6"), Pigment(name: "Clay", hex: "C39485"),
      ]
    case .mineral:
      [
        Pigment(name: "Chalk", hex: "E8ECEA"), Pigment(name: "Jade", hex: "A2D7B3"),
        Pigment(name: "Moss", hex: "C3CD88"), Pigment(name: "Glacier", hex: "99CBCD"),
        Pigment(name: "Quartz", hex: "B8B6DE"), Pigment(name: "Sand", hex: "DACEB4"),
      ]
    }
  }
}

struct ArtStroke: Codable, Equatable, Identifiable {
  var id = UUID()
  var points: [ArtPoint]
  var pigment: String
  var brush: Brush
  var width: Double
  var symmetry: Int
  var mirror: Bool
}

struct Artwork: Codable, Identifiable, Equatable {
  var id = UUID()
  var title: String
  var strokes: [ArtStroke] = []
  var updated = Date()
  var isSample = false
}

struct StudioSettings: Codable {
  var symmetry = 8
  var mirror = true
  var brush: Brush = .silk
  var pigment = "83EAC3"
  var width = 2.5
  var guides = true
  var palette = "aurora"
}

struct StudioArchive: Codable {
  var version = 1
  var current: Artwork
  var gallery: [Artwork]
  var settings: StudioSettings
}

struct StrokeHistory {
  private var undoStack: [[ArtStroke]] = []
  private var redoStack: [[ArtStroke]] = []
  var canUndo: Bool { !undoStack.isEmpty }
  var canRedo: Bool { !redoStack.isEmpty }

  mutating func record(_ strokes: [ArtStroke]) {
    undoStack.append(strokes)
    if undoStack.count > 80 { undoStack.removeFirst() }
    redoStack.removeAll()
  }

  mutating func undo(_ current: [ArtStroke]) -> [ArtStroke]? {
    guard let previous = undoStack.popLast() else { return nil }
    redoStack.append(current)
    return previous
  }

  mutating func redo(_ current: [ArtStroke]) -> [ArtStroke]? {
    guard let next = redoStack.popLast() else { return nil }
    undoStack.append(current)
    return next
  }
}

@Observable final class Studio {
  var current: Artwork
  var gallery: [Artwork]
  var settings: StudioSettings
  var history = StrokeHistory()
  var errorMessage: String?
  private let storageURL: URL

  init(storageURL: URL? = nil) {
    self.storageURL = storageURL ?? URL.documentsDirectory.appending(path: "prismatic-v1.json")
    current = Samples.aurora
    gallery = []
    settings = StudioSettings()
    do {
      if FileManager.default.fileExists(atPath: self.storageURL.path) {
        let archive = try JSONDecoder().decode(
          StudioArchive.self, from: Data(contentsOf: self.storageURL))
        guard archive.version == 1 else {
          errorMessage = "This archive was made by a newer version of Prismatic."
          return
        }
        current = archive.current
        gallery = archive.gallery
        settings = archive.settings
      }
    } catch {
      errorMessage =
        "Your saved studio could not be opened. The original file is still on this device."
    }
  }

  func persist() {
    do {
      let data = try JSONEncoder().encode(
        StudioArchive(current: current, gallery: gallery, settings: settings))
      try data.write(to: storageURL, options: .atomic)
    } catch {
      errorMessage = "Your changes could not be saved. Please free up device storage and try again."
    }
  }

  func add(_ stroke: ArtStroke) {
    guard !stroke.points.isEmpty else { return }
    history.record(current.strokes)
    current.strokes.append(stroke)
    markEdited()
  }

  func clear() {
    guard !current.strokes.isEmpty else { return }
    history.record(current.strokes)
    current.strokes = []
    markEdited()
  }

  func undo() {
    guard let strokes = history.undo(current.strokes) else { return }
    current.strokes = strokes
    markEdited()
  }

  func redo() {
    guard let strokes = history.redo(current.strokes) else { return }
    current.strokes = strokes
    markEdited()
  }

  private func markEdited() {
    if current.isSample {
      current.title = "\(current.title) study"
      current.isSample = false
    }
    current.updated = Date()
    persist()
  }

  func open(_ artwork: Artwork) {
    current = artwork
    history = StrokeHistory()
    persist()
  }

  func newCanvas() { open(Artwork(title: "Untitled study")) }

  func save(title: String) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    current.title = String((trimmed.isEmpty ? "Untitled study" : trimmed).prefix(60))
    current.isSample = false
    current.updated = Date()
    if let index = gallery.firstIndex(where: { $0.id == current.id }) {
      gallery[index] = current
    } else {
      gallery.insert(current, at: 0)
    }
    persist()
  }

  func delete(_ artwork: Artwork) {
    gallery.removeAll { $0.id == artwork.id }
    persist()
  }
}

enum Samples {
  static let aurora = flower(title: "Aurora", count: 12, colors: ["83EAC3", "ADA2FA", "EFE8D8"])
  static let ember = flower(title: "Solstice", count: 9, colors: ["FFA274", "EFC87E", "F47B7F"])
  static let all = [aurora, ember]

  static func flower(title: String, count: Int, colors: [String]) -> Artwork {
    var strokes: [ArtStroke] = []
    for layer in 0..<7 {
      let radius = 0.39 - Double(layer) * 0.044
      let points = (0...100).map { step -> ArtPoint in
        let t = Double(step) / 100
        let angle = sin(t * .pi) * (0.20 + Double(layer) * 0.015)
        let r = 0.04 + sin(t * .pi) * radius
        return ArtPoint(x: 0.5 + sin(angle) * r, y: 0.5 - cos(angle) * r)
      }
      strokes.append(
        ArtStroke(
          points: points, pigment: colors[layer % colors.count], brush: .silk,
          width: layer % 3 == 0 ? 1.5 : 0.8, symmetry: count, mirror: true))
    }
    for ring in 0..<3 {
      let r = 0.29 + Double(ring) * 0.036
      strokes.append(
        ArtStroke(
          points: (0...25).map { step in
            let angle = Double(step) / 25 * .pi / Double(count)
            return ArtPoint(x: 0.5 + sin(angle) * r, y: 0.5 - cos(angle) * r)
          },
          pigment: colors[ring % 3], brush: .stardust, width: 1.6,
          symmetry: count, mirror: true))
    }
    return Artwork(title: title, strokes: strokes, isSample: true)
  }
}
