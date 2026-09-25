import Foundation
import SwiftUI

#if SWIFT_PACKAGE
  import TerraCore
#endif

@MainActor
final class StudioModel: ObservableObject {
  @Published var terrain = Terrain()
  @Published var brush: Brush = .raise
  @Published var radius: Float = 1.05
  @Published var strength: Float = 0.55
  @Published var contours = false
  @Published var history = TerrainHistory()
  @Published var saved: [SavedWorld] = []
  @Published var status = "Your island, your imagination."
  @Published var error: String?
  @Published var revision = 0
  @Published var homeRevision = 0
  @Published var zoom: Float = 1
  private var transaction: Terrain?

  private let documents: URL
  private var autosaveURL: URL { documents.appendingPathComponent("Current.terra") }
  private var libraryURL: URL { documents.appendingPathComponent("Library.json") }

  init(documents: URL = .documentsDirectory) {
    self.documents = documents
    do {
      if FileManager.default.fileExists(atPath: autosaveURL.path) {
        let restored = try JSONDecoder().decode(Terrain.self, from: Data(contentsOf: autosaveURL))
        guard restored.isValid else { throw CocoaError(.fileReadCorruptFile) }
        terrain = restored
        status = "Welcome back. Your landscape is restored."
      }
      if FileManager.default.fileExists(atPath: libraryURL.path) {
        saved = try JSONDecoder().decode([SavedWorld].self, from: Data(contentsOf: libraryURL))
        guard saved.allSatisfy({ $0.terrain.isValid }) else {
          saved = []
          throw CocoaError(.fileReadCorruptFile)
        }
      }
    } catch {
      self.error =
        "The saved file could not be read. A fresh island is ready; the file was not deleted."
    }
  }

  func begin() {
    end()
    transaction = terrain
  }

  func end() {
    guard let before = transaction else { return }
    history.record(before, after: terrain)
    transaction = nil
    persist()
  }

  func sculpt(x: Float, z: Float) {
    terrain.apply(brush, x: x, z: z, radius: radius, strength: strength)
    revision += 1
    status = "\(brush.rawValue) brush · one stroke, one undo"
  }

  func setWater(_ value: Float) {
    let standalone = transaction == nil
    if standalone { begin() }
    terrain.water = max(0, min(0.85, value))
    revision += 1
    status = "Waterline at \(Int(terrain.water * 1000)) m"
    if standalone {
      end()
    } else {
      persist()
    }
  }

  func preset(_ landscape: Landscape) {
    begin()
    terrain = Terrain(landscape: landscape)
    revision += 1
    end()
    status = "\(landscape.rawValue) loaded · undo to return"
  }

  func undo() {
    end()
    if let restored = history.undo(terrain) {
      terrain = restored
      revision += 1
      persist()
      status = "Last change undone"
    }
  }

  func redo() {
    end()
    if let restored = history.redo(terrain) {
      terrain = restored
      revision += 1
      persist()
      status = "Change restored"
    }
  }

  func persist() {
    do {
      try JSONEncoder().encode(terrain).write(to: autosaveURL, options: .atomic)
    } catch {
      self.error = "Could not save this landscape: \(error.localizedDescription)"
    }
  }

  func save() {
    end()
    let world = SavedWorld(terrain: terrain)
    let next = [world] + saved
    do {
      try JSONEncoder().encode(next).write(to: libraryURL, options: .atomic)
      saved = next
      persist()
      status = "Snapshot saved to My landscapes"
    } catch {
      self.error = "Could not save snapshot: \(error.localizedDescription)"
    }
  }

  func reopen(_ world: SavedWorld) {
    begin()
    terrain = world.terrain
    revision += 1
    end()
    status = "Reopened \(world.terrain.title)"
  }

  func exportMesh() -> URL? {
    do {
      let directory = documents.appendingPathComponent("Exports")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appendingPathComponent("TerraTable.obj")
      try terrain.obj().write(to: url, atomically: true, encoding: .utf8)
      status = "Mesh exported · 6,561 vertices / 12,800 faces"
      return url
    } catch {
      self.error = "Export failed: \(error.localizedDescription)"
      return nil
    }
  }
}
