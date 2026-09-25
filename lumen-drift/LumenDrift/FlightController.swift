import Combine
import SwiftUI
import UIKit

@MainActor
final class FlightController: ObservableObject {
  @Published private(set) var engine = DriftEngine()
  @Published private(set) var record: FlightRecord
  @Published var tutorial = false
  @Published var message = ""
  @Published var messageDetail = ""
  @Published var hitFlash = false
  private let store = FlightStore(defaults: .standard)
  private var messageUntil = 0.0
  private var saved = false
  weak var scene: CanyonScene?

  init() {
    record = store.load()
  }

  func start(_ mode: FlightMode) {
    saved = false
    message = ""
    engine.start(mode, seed: UInt64.random(in: 1...UInt64.max))
    scene?.resetFlight()
  }

  func steer(_ lane: Int) {
    let previous = engine.lane
    engine.steer(to: lane)
    if previous != engine.lane {
      UISelectionFeedbackGenerator().selectionChanged()
    }
  }

  func tick(_ delta: Double) {
    guard engine.phase == .running else { return }
    let events = engine.tick(delta)
    if engine.elapsed > messageUntil { message = "" }
    for event in events {
      switch event {
      case .energy(let points):
        message = "ENERGY CAPTURED"
        messageDetail = "+\(points)  /  CLEAN LINE"
        scene?.burst(collision: false)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      case .nearMiss(let points):
        message = "CLOSE ENCOUNTER"
        messageDetail = "+\(points)  /  NEAR MISS"
      case .collision:
        message = engine.shields > 0 ? "SHIELD ABSORBED" : "HULL EXPOSED"
        messageDetail = "FIND A CLEAR LINE"
        scene?.burst(collision: true)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      case .gameOver:
        saveFlight()
      }
      messageUntil = engine.elapsed + 2.8
    }
  }

  func pause() { engine.pause() }
  func resume() { engine.resume() }

  func home() {
    if engine.phase != .ready { saveFlight() }
    engine = DriftEngine()
    message = ""
    scene?.resetFlight()
  }

  private func saveFlight() {
    guard !saved else { return }
    saved = true
    record.save(mode: engine.mode, score: engine.score, energy: engine.energy)
    store.save(record)
  }
}
