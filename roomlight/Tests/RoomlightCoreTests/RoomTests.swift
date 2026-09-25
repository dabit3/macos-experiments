import Foundation
import Testing

@testable import RoomlightCore

@Test func rotatedFootprintStaysInsideRoom() {
  var room = Room(furniture: [Furniture(kind: .sofa, x: 10, z: -2, rotation: 90)])
  room.constrain(snap: true)
  #expect(room.furniture[0].x == 6 - 0.95 / 2)
  #expect(room.furniture[0].z == 2.3 / 2)
  #expect(room.furniture[0].footprintWidth == 0.95)
}

@Test func snappingAndResizingPreserveBounds() {
  var room = Room(furniture: [Furniture(kind: .coffeeTable, x: 2.34, z: 1.76)])
  room.constrain(snap: true)
  #expect(room.furniture[0].x == 2.3)
  #expect(room.furniture[0].z == 1.8)
  room.width = 1
  room.depth = .infinity
  room.furniture[0].x = .nan
  room.constrain()
  #expect(room.width == 3)
  #expect(room.depth == 5)
  #expect(room.furniture[0].x.isFinite)
}

@Test func allFurnitureFitsMinimumRoomInEveryRotation() {
  for kind in FurnitureKind.allCases {
    for rotation in [0, 90, 180, 270] {
      var room = Room(
        width: 3, depth: 3,
        furniture: [Furniture(kind: kind, x: 100, z: -100, rotation: rotation)])
      room.constrain()
      let item = room.furniture[0]
      #expect(item.x + item.footprintWidth / 2 <= 3)
      #expect(item.z - item.footprintDepth / 2 >= 0)
    }
  }
}

@Test func archiveRoundTripsAndSaveUpdatesSameRoom() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  var archive = RoomArchive()
  archive.save()
  archive.current.name = "Edited"
  archive.current.wall = .clay
  archive.save()
  #expect(archive.saved.count == 1)
  try archive.write(to: url)
  #expect(try RoomArchive.read(from: url) == archive)
  archive.current = Room(name: "Another")
  archive.save()
  #expect(archive.saved.count == 2)
}

@Test func corruptArchiveThrows() throws {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  try Data("not json".utf8).write(to: url)
  #expect(throws: (any Error).self) { try RoomArchive.read(from: url) }
}
