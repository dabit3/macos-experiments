import Foundation
import SwiftUI

@MainActor
final class GameStore: ObservableObject {
  @Published private(set) var state: GameState
  @Published var soundEnabled: Bool {
    didSet { defaults.set(soundEnabled, forKey: "gtcbingo.sound") }
  }
  @Published var hapticsEnabled: Bool {
    didSet { defaults.set(hapticsEnabled, forKey: "gtcbingo.haptics") }
  }

  private let defaults = UserDefaults.standard
  private let stateKey = "gtcbingo.state"

  init() {
    if let data = defaults.data(forKey: stateKey),
      let saved = try? JSONDecoder().decode(GameState.self, from: data)
    {
      state = saved
    } else {
      state = GameState()
    }
    soundEnabled = defaults.object(forKey: "gtcbingo.sound") as? Bool ?? true
    hapticsEnabled = defaults.object(forKey: "gtcbingo.haptics") as? Bool ?? true
  }

  var currentPlayer: Player { state.current }

  func save() {
    if let data = try? JSONEncoder().encode(state) {
      defaults.set(data, forKey: stateKey)
    }
  }

  func toggleCurrent(_ index: Int) -> (bingo: Bool, oneAway: Bool) {
    let before = state.current.card
    let oneAway = before.wouldCompleteLine(byMarking: index)
    state.current.card.toggle(index)
    let bingo = !before.hasBingo && state.current.card.hasBingo
    if bingo { state.markBingo(for: state.current.id) }
    save()
    if soundEnabled {
      if bingo {
        SoundEngine.shared.playFanfare()
      } else if oneAway {
        SoundEngine.shared.playOneAway()
      } else {
        SoundEngine.shared.playTick(marked: state.current.card.marked.contains(index))
      }
    }
    if hapticsEnabled {
      if bingo {
        Haptics.success()
      } else {
        Haptics.marked(state.current.card.marked.contains(index))
      }
    }
    return (bingo, oneAway)
  }

  func newCard() {
    state.newCard(for: state.current.id, seed: freshSeed())
    save()
  }

  func passToNextPlayer() {
    state.nextPlayer()
    save()
  }

  func selectPlayer(_ id: UUID) {
    guard let index = state.players.firstIndex(where: { $0.id == id }) else { return }
    state.currentIndex = index
    save()
  }

  func addPlayer(name: String) {
    if state.addPlayer(name: name) { save() }
  }

  func removePlayer(id: UUID) {
    state.removePlayer(id: id)
    save()
  }

  func newRound() {
    state.newRound(seed: freshSeed())
    save()
  }

  func resetScores() {
    for index in state.players.indices { state.players[index].wins = 0 }
    save()
  }

  private func freshSeed() -> UInt64 {
    UInt64.random(in: UInt64.min...UInt64.max)
  }
}
