import Foundation
import Testing

@testable import TerraCore

@Test func presetsAreDeterministicDistinctAndValid() {
  for landscape in Landscape.allCases {
    let terrain = Terrain(landscape: landscape)
    #expect(terrain.isValid)
    #expect(terrain == Terrain(landscape: landscape))
    #expect(terrain != Terrain(landscape: landscape, seed: 101))
    #expect(terrain.landPercent > 0 && terrain.landPercent < 100)
  }
  #expect(Terrain(landscape: .alpine).heights != Terrain(landscape: .caldera).heights)
}

@Test func brushHasCompactSupportAndBoundedHeights() {
  var terrain = Terrain()
  let original = terrain.heights
  let center = Terrain.resolution * (Terrain.resolution / 2) + Terrain.resolution / 2
  terrain.apply(.raise, x: 0, z: 0, radius: 1, strength: 1)
  #expect(terrain.heights[center] > original[center])
  #expect(terrain.heights[0] == original[0])
  terrain.apply(.lower, x: 0, z: 0, radius: 1, strength: 1)
  #expect(abs(terrain.heights[center] - original[center]) < 0.00001)
  for _ in 0..<100 {
    terrain.apply(.raise, x: 0, z: 0, radius: 1, strength: 1)
  }
  #expect(terrain.heights[center] == 1.25)
  #expect(terrain.isValid)
}

@Test func smoothingReducesAnImpulseWithoutTouchingDistantCells() {
  var terrain = Terrain()
  terrain.heights = Array(repeating: 0.2, count: Terrain.resolution * Terrain.resolution)
  let center = Terrain.resolution * (Terrain.resolution / 2) + Terrain.resolution / 2
  terrain.heights[center] = 1
  terrain.apply(.smooth, x: 0, z: 0, radius: 1, strength: 0.5)
  #expect(terrain.heights[center] < 0.3)
  #expect(terrain.heights[center + 1] > 0.2)
  #expect(terrain.heights[0] == 0.2)
}

@Test func invalidBrushInputsDoNotCorruptTerrain() {
  var terrain = Terrain()
  let original = terrain
  terrain.apply(.raise, x: .nan, z: 0, radius: 1, strength: 1)
  terrain.apply(.raise, x: 0, z: 0, radius: -1, strength: 1)
  terrain.apply(.lower, x: 0, z: 0, radius: 1, strength: .infinity)
  terrain.apply(.orbit, x: 0, z: 0, radius: 1, strength: 1)
  #expect(terrain == original)
}

@Test func undoRedoBranchesAndEmptyTransactions() {
  var history = TerrainHistory()
  let first = Terrain()
  let second = Terrain(landscape: .caldera)
  let third = Terrain(landscape: .archipelago)
  history.record(first, after: first)
  #expect(history.undoStack.isEmpty)
  history.record(first, after: second)
  #expect(history.undo(second) == first)
  #expect(history.redo(first) == second)
  #expect(history.undo(second) == first)
  history.record(first, after: third)
  #expect(history.redoStack.isEmpty)
  #expect(history.undo(third) == first)
}

@Test func historyIsBounded() {
  var history = TerrainHistory()
  var terrain = Terrain()
  for _ in 0..<40 {
    let before = terrain
    terrain.water += 0.001
    history.record(before, after: terrain)
  }
  #expect(history.undoStack.count == 30)
}

@Test func serializationRoundTripAndCorruptDimensions() throws {
  var terrain = Terrain(landscape: .caldera)
  terrain.apply(.lower, x: 1, z: 1, radius: 2, strength: 0.8)
  terrain.water = 0.48
  let restored = try JSONDecoder().decode(Terrain.self, from: JSONEncoder().encode(terrain))
  #expect(restored == terrain)
  #expect(restored.isValid)
  let world = SavedWorld(terrain: terrain)
  let saved = try JSONDecoder().decode(SavedWorld.self, from: JSONEncoder().encode(world))
  #expect(saved.id == world.id)
  #expect(saved.terrain == terrain)
  terrain.heights.removeLast()
  #expect(!terrain.isValid)
}

@Test func exportHasValidTopologyAndUpwardFaces() {
  let terrain = Terrain()
  let lines = terrain.obj().split(separator: "\n")
  let vertices = lines.filter { $0.hasPrefix("v ") }
  let faces = lines.filter { $0.hasPrefix("f ") }
  #expect(vertices.count == 6561)
  #expect(faces.count == 12800)
  #expect(faces.first == "f 1 82 2")
  for face in faces {
    let indices = face.split(separator: " ").dropFirst().compactMap { Int($0) }
    #expect(indices.count == 3)
    #expect(indices.allSatisfy { (1...vertices.count).contains($0) })
  }
}

@Test func risingWaterNeverIncreasesDryLand() {
  var terrain = Terrain()
  var previous = 100
  for level in stride(from: Float(0), through: 0.85, by: 0.05) {
    terrain.water = level
    #expect(terrain.landPercent <= previous)
    previous = terrain.landPercent
  }
}
