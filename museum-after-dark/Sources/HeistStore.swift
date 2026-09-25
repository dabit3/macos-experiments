import AudioToolbox
import SwiftUI
import UIKit

struct SavedHeist: Codable {
  var roomIndex = 0
  var state = HeistEngine.initial(Rooms.all[0])
  var history: [HeistState] = []
  var best: [Int: Int] = [:]
  var sound = false
  var haptics = true
}

@MainActor
final class HeistStore: ObservableObject {
  @Published var saved: SavedHeist
  @Published var screen = Screen.home
  @Published var showPause = false
  @Published var showSettings = false
  @Published var message = ""
  @Published var revealArtifact = false
  let defaults: UserDefaults
  enum Screen { case home, rooms, play }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: "museum.heist.v1"),
      let record = try? JSONDecoder().decode(SavedHeist.self, from: data),
      Rooms.all.indices.contains(record.roomIndex)
    {
      saved = record
    } else {
      saved = SavedHeist()
    }
  }

  var room: Room { Rooms.all[saved.roomIndex] }
  var state: HeistState { saved.state }
  var unlocked: Int { min(10, (saved.best.keys.max() ?? 0) + 1) }
  var medals: Int { Rooms.all.filter { (saved.best[$0.id] ?? Int.max) <= $0.par }.count }

  func persist() {
    if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: "museum.heist.v1") }
  }

  func begin(_ index: Int, fresh: Bool = true) {
    guard Rooms.all.indices.contains(index), index < unlocked else { return }
    saved.roomIndex = index
    if fresh {
      saved.state = HeistEngine.initial(room)
      saved.history = []
    }
    message = ""
    revealArtifact = false
    screen = .play
    persist()
  }

  func act(_ action: HeistAction) {
    guard let next = HeistEngine.applying(action, to: state, in: room) else {
      message = "One tile at a time. Choose a mint-outlined neighbor."
      return
    }
    let acquired = next.hasArtifact && !state.hasArtifact
    saved.history.append(state)
    saved.state = next
    message = ""
    if acquired { revealArtifact = true }
    if next.outcome == .escaped {
      saved.best[room.id] = min(saved.best[room.id] ?? Int.max, next.turn)
    }
    if saved.haptics {
      if next.outcome == .caught {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      } else if acquired || next.outcome == .escaped {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    }
    if saved.sound { AudioServicesPlaySystemSound(next.outcome == .caught ? 1053 : 1104) }
    persist()
  }

  func tap(_ tile: Tile) {
    if room.nodes.contains(tile) || room.mirrors.contains(tile) {
      if state.player.distance(to: tile) != 1 {
        message = "Stand beside this device to use it."
      } else {
        act(.interact(tile))
      }
    } else if let direction = Direction.allCases.first(where: { state.player.moved($0) == tile }) {
      act(.move(direction))
    } else {
      message = "Tap a mint-outlined neighbor to move one tile."
    }
  }

  func undo() {
    guard let previous = saved.history.popLast() else { return }
    saved.state = previous
    revealArtifact = false
    message = "One step back. Your next move is yours."
    persist()
  }

  func restart() {
    begin(saved.roomIndex)
    showPause = false
  }
}
