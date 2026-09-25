import Foundation
import SwiftUI

@MainActor
@Observable
final class StudioStore {
  var archive: RoomArchive
  var selection: UUID?
  var snap = true
  var message = "A little space. A lot of possibility."
  var error: String?
  private var history: [Room] = []
  private var dragOrigin: Room?
  private let archiveURL: URL

  var room: Room { archive.current }
  var canUndo: Bool { !history.isEmpty }
  var selected: Furniture? { room.furniture.first { $0.id == selection } }

  init() {
    archiveURL = URL.documentsDirectory.appendingPathComponent("roomlight-rooms.json")
    do {
      archive =
        FileManager.default.fileExists(atPath: archiveURL.path)
        ? try RoomArchive.read(from: archiveURL) : RoomArchive()
    } catch {
      archive = RoomArchive()
      self.error =
        "The saved file could not be read. Your original file is preserved until you make an edit."
    }
  }

  func change(_ action: (inout Room) -> Void) {
    history.append(room)
    if history.count > 60 { history.removeFirst() }
    action(&archive.current)
    archive.current.constrain()
    persist()
  }

  func add(_ kind: FurnitureKind) {
    change { selection = $0.add(kind, snap: snap) }
    message = "\(kind.title) placed · drag it into position"
  }

  func move(_ id: UUID, x: Double, z: Double, ended: Bool) {
    if dragOrigin == nil { dragOrigin = room }
    if let index = archive.current.furniture.firstIndex(where: { $0.id == id }) {
      archive.current.furniture[index].x = x
      archive.current.furniture[index].z = z
      archive.current.constrain(snap: snap)
    }
    if ended {
      if let origin = dragOrigin, origin != room { history.append(origin) }
      dragOrigin = nil
      persist()
      message = snap ? "Position set · snapped to 10 cm" : "Position set"
    }
  }

  func rotate() {
    guard let selection else { return }
    change { room in
      guard let index = room.furniture.firstIndex(where: { $0.id == selection }) else { return }
      room.furniture[index].rotation = (room.furniture[index].rotation + 90) % 360
    }
    message = "Rotated 90°"
  }

  func remove() {
    guard let selection else { return }
    change { $0.furniture.removeAll { $0.id == selection } }
    self.selection = nil
    message = "Piece removed · Undo to bring it back"
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    archive.current = previous
    selection = nil
    persist()
    message = "Last edit undone"
  }

  func save(name: String) {
    let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
    archive.current.name = clean.isEmpty ? "Untitled room" : String(clean.prefix(70))
    archive.save()
    persist()
    message = "Saved “\(room.name)”"
  }

  func open(_ room: Room) {
    change { $0 = room }
    selection = nil
    message = "Opened “\(room.name)”"
  }

  func newRoom() {
    change { $0 = Room(name: "A room of your own") }
    selection = nil
    message = "An empty canvas · choose your first piece"
  }

  private func persist() {
    do { try archive.write(to: archiveURL) } catch {
      self.error = "Could not save your room: \(error.localizedDescription)"
    }
  }
}
