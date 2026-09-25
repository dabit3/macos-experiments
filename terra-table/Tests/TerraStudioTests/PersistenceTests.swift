import Foundation
import TerraCore
import Testing

@testable import TerraStudio

@Test @MainActor func inFlightWaterIsDurableAndUndoable() throws {
  let directory = URL.cachesDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let model = StudioModel(documents: directory)
  let original = model.terrain
  model.begin()
  model.setWater(0.35)
  model.setWater(0.264)

  #expect(StudioModel(documents: directory).terrain.water == 0.264)
  model.undo()
  #expect(model.terrain == original)
  model.redo()
  #expect(model.terrain.water == 0.264)
  #expect(StudioModel(documents: directory).terrain == model.terrain)
}

@Test @MainActor func waterChangesPersistAcrossEditingCallbackOrder() throws {
  let directory = URL.cachesDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let model = StudioModel(documents: directory)

  model.setWater(0.318)
  #expect(StudioModel(documents: directory).terrain.water == 0.318)
  model.undo()
  #expect(model.terrain.water == Terrain().water)
  model.redo()
  #expect(model.terrain.water == 0.318)

  model.begin()
  model.setWater(0.35)
  model.setWater(0.4)
  model.end()
  #expect(StudioModel(documents: directory).terrain.water == 0.4)
  model.undo()
  #expect(model.terrain.water == 0.318)
  model.redo()
  #expect(model.terrain.water == 0.4)

  model.begin()
  model.end()
  model.setWater(0.46)
  #expect(StudioModel(documents: directory).terrain.water == 0.46)
  model.undo()
  #expect(model.terrain.water == 0.4)
}

@Test @MainActor func snapshotAndSubsequentWaterEditRestoreIndependently() throws {
  let directory = URL.cachesDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let model = StudioModel(documents: directory)
  model.save()
  let snapshot = try #require(model.saved.first)
  model.preset(.caldera)
  model.reopen(snapshot)
  model.setWater(0.318)

  let restored = StudioModel(documents: directory)
  #expect(restored.terrain.heights == snapshot.terrain.heights)
  #expect(restored.terrain.water == 0.318)
  #expect(restored.saved.first?.terrain == snapshot.terrain)
  restored.reopen(snapshot)
  #expect(restored.terrain == snapshot.terrain)
  #expect(StudioModel(documents: directory).terrain == snapshot.terrain)
}
