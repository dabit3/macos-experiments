import Combine
import Foundation
import UIKit

@MainActor
final class RallyStore: ObservableObject {
  @Published var settings: MatchSettings {
    didSet { save() }
  }
  @Published private(set) var records: [MatchRecord]
  private let defaults: UserDefaults
  private let settingsKey = "velvet.settings.v1"
  private let recordsKey = "velvet.records.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    settings =
      defaults.data(forKey: settingsKey)
      .flatMap { try? JSONDecoder().decode(MatchSettings.self, from: $0) } ?? MatchSettings()
    records =
      defaults.data(forKey: recordsKey)
      .flatMap { try? JSONDecoder().decode([MatchRecord].self, from: $0) } ?? []
    if settings.target != 3 && settings.target != 7 { settings.target = 7 }
  }

  func add(_ record: MatchRecord) {
    guard !records.contains(where: { $0.id == record.id }) else { return }
    records.insert(record, at: 0)
    records = Array(records.prefix(50))
    save()
  }

  func clearRecords() {
    records = []
    save()
  }

  private func save() {
    if let data = try? JSONEncoder().encode(settings) {
      defaults.set(data, forKey: settingsKey)
    }
    if let data = try? JSONEncoder().encode(records) {
      defaults.set(data, forKey: recordsKey)
    }
  }
}

@MainActor
final class MatchSession: ObservableObject {
  @Published var engine: GameEngine
  private var previousTime: TimeInterval?
  private var saved = false
  private let impact = UIImpactFeedbackGenerator(style: .light)
  private let notification = UINotificationFeedbackGenerator()

  init(settings: MatchSettings) { engine = GameEngine(settings: settings) }

  func advance(at time: TimeInterval, store: RallyStore) {
    defer { previousTime = time }
    guard let previousTime else { return }
    let event = engine.tick(delta: time - previousTime)
    if engine.settings.haptics {
      if event == .paddle { impact.impactOccurred(intensity: 0.55) }
      if event == .playerPoint || event == .opponentPoint {
        notification.notificationOccurred(event == .playerPoint ? .success : .warning)
      }
    }
    if engine.phase == .finished && !saved {
      saved = true
      store.add(engine.record())
    }
  }

  func reset() {
    engine = GameEngine(settings: engine.settings)
    previousTime = nil
    saved = false
  }
}
