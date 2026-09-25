import Foundation
import Observation

enum PlayPhase { case pickup, lowering, hoisting, release, falling, settling, finished }

@Observable
final class GameModel {
  var isPlaying = false
  var practice = false
  var paused = false
  var phase = PlayPhase.pickup
  var contract = Contract.all[0]
  var stack: [StackedCargo] = []
  var cargoIndex = 0
  var score = 0
  var losses = 0
  var timeLeft = 90.0
  var trim = 0.0
  var clock = 0.0
  var phaseTime = 0.0
  var actionX = 0.0
  var actionStartX = 0.0
  var impact = 0.0
  var lastAward = 0
  var preciseLanding = false
  var message = "Line up with the treasure on the left."
  var resultReason = ""
  var won = false
  var cue: FeedbackCue?
  var cueSerial = 0
  var best: Int
  var unlocked: Int
  var completed: Int
  var audioEnabled: Bool { didSet { defaults.set(audioEnabled, forKey: "audio") } }
  var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "haptics") } }
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    best = defaults.integer(forKey: "best")
    unlocked = min(2, defaults.integer(forKey: "unlocked"))
    completed = defaults.integer(forKey: "completed")
    audioEnabled = defaults.object(forKey: "audio") as? Bool ?? true
    hapticsEnabled = defaults.object(forKey: "haptics") as? Bool ?? true
  }

  var cargo: CargoKind { contract.cargo[min(cargoIndex, contract.cargo.count - 1)] }
  var targetX: Double { stack.last?.x ?? DockRules.shipX }
  var swing: Double { sin(clock * contract.swing) * (practice ? 30 : 44) }
  var hookX: Double {
    let anchor = phase == .pickup || phase == .lowering ? DockRules.dockX : DockRules.shipX
    return anchor + swing + trim * 52
  }
  var balance: Double { DockRules.balance(stack) }
  var projectedX: Double {
    guard phase == .release else { return hookX }
    return hookX + cos(clock * contract.swing) * contract.swing * (practice ? 30 : 44) * 0.12
  }
  var onTarget: Bool {
    if phase == .pickup { return DockRules.canCatch(hookX: hookX, cargo: cargo) }
    guard phase == .release else { return false }
    let projectedStack = stack + [StackedCargo(id: cargoIndex, kind: cargo, x: projectedX)]
    return DockRules.hasSupport(x: projectedX, kind: cargo, stack: stack)
      && DockRules.isStable(projectedStack)
  }
  var actionable: Bool { phase == .pickup || phase == .release }
  var buttonTitle: String {
    switch phase {
    case .pickup: "Drop hook"
    case .release: "Release cargo"
    case .lowering: "Going down…"
    case .hoisting: "Treasure aboard…"
    case .falling: "Easy does it…"
    case .settling: "Steadying the ship…"
    case .finished: "Manifest complete"
    }
  }

  func start(contract index: Int = 0, practice: Bool = false) {
    contract = Contract.all[max(0, min(index, Contract.all.count - 1))]
    self.practice = practice
    stack = []
    score = 0
    losses = 0
    cargoIndex = 0
    clock = 0
    phaseTime = 0
    trim = 0
    impact = 0
    lastAward = 0
    preciseLanding = false
    timeLeft = contract.seconds
    phase = .pickup
    paused = false
    won = false
    resultReason = ""
    message = "Drop when the hook crosses the treasure."
    isPlaying = true
  }

  func tick(_ dt: Double) {
    guard !paused else { return }
    clock += dt
    guard isPlaying, phase != .finished else { return }
    phaseTime += dt
    impact *= pow(0.04, dt)
    if !practice {
      timeLeft = max(0, timeLeft - dt)
      if timeLeft == 0 {
        finish(
          won: false, reason: "The harbor bell rang. Your cargo is safe, but the contract expired.")
        return
      }
    }
    switch phase {
    case .lowering where phaseTime >= 0.6:
      if DockRules.canCatch(hookX: actionX, cargo: cargo) {
        changePhase(.hoisting)
        message = "\(cargo.title) secured. Watch the landing guide."
        signal(.catchCargo)
      } else {
        miss("Empty hook. Aim for the orange dock marker.")
      }
    case .hoisting where phaseTime >= 1.1:
      changePhase(.release)
      message = "Release over the deck. Trim to keep your stack centered."
    case .falling where phaseTime >= 0.7:
      land()
    case .settling where phaseTime >= 1.1:
      cargoIndex += 1
      if cargoIndex == contract.cargo.count {
        finish(won: true, reason: "Every treasure has a new horizon.")
      } else {
        trim = 0
        changePhase(.pickup)
        message = "Next: \(cargo.title). Drop over the left dock."
      }
    default: break
    }
  }

  func act() {
    guard !paused, actionable else { return }
    actionStartX = hookX
    actionX = hookX
    if phase == .pickup {
      changePhase(.lowering)
    } else {
      actionX = projectedX
      changePhase(.falling)
    }
    signal(.releaseCargo)
  }

  func shift(_ amount: Double) {
    trim = max(-1, min(1, trim + amount))
  }

  func home() {
    isPlaying = false
    paused = false
  }

  private func land() {
    guard DockRules.hasSupport(x: actionX, kind: cargo, stack: stack) else {
      miss("Cargo slipped past the stack. Follow the dashed landing guide.")
      return
    }
    let earned = DockRules.points(x: actionX, kind: cargo, stack: stack)
    let precise = abs(actionX - targetX) < 14
    lastAward = earned
    preciseLanding = precise
    stack.append(StackedCargo(id: cargoIndex, kind: cargo, x: actionX))
    impact = 1
    guard DockRules.isStable(stack) else {
      finish(won: false, reason: "Too much weight on one side. Aim toward the center of the ship.")
      return
    }
    score += earned
    message = precise ? "Beautiful landing. +\(earned)" : "Cargo secured. +\(earned)"
    changePhase(.settling)
    signal(.land)
  }

  private func miss(_ text: String) {
    losses += 1
    trim = 0
    message = text
    signal(.miss)
    if losses >= 3 && !practice {
      finish(won: false, reason: "Three missed lifts. The dock crew needs a fresh start.")
    } else {
      changePhase(.pickup)
    }
  }

  private func changePhase(_ value: PlayPhase) {
    phase = value
    phaseTime = 0
  }

  private func finish(won: Bool, reason: String) {
    self.won = won
    resultReason = reason
    changePhase(.finished)
    if !practice {
      if won {
        score += Int(timeLeft) * 5
        unlocked = max(unlocked, min(2, contract.id + 1))
        completed += 1
        defaults.set(unlocked, forKey: "unlocked")
        defaults.set(completed, forKey: "completed")
      }
      best = max(best, score)
      defaults.set(best, forKey: "best")
    }
    signal(won ? .win : .miss)
  }

  private func signal(_ value: FeedbackCue) {
    cue = value
    cueSerial += 1
  }
}
