import Foundation
import SwiftUI

struct Shoot: Codable, Identifiable {
  var id = UUID()
  var title: String
  var notes: String
  var place: Place
  var date: Date
}

struct PlannerState: Codable {
  var place: Place
  var date: Date
  var shoots: [Shoot]
}

@MainActor @Observable
final class Planner {
  var place: Place
  var date: Date
  var shoots: [Shoot]
  var day: SunDay
  private let defaults: UserDefaults
  private let key = "sunward.planner.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let state = defaults.data(forKey: key).flatMap {
      try? JSONDecoder().decode(PlannerState.self, from: $0)
    }
    let place = state?.place ?? Place.presets[0]
    let today = Date()
    let date =
      state?.date ?? place.calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today)!
    self.place = place
    self.date = date
    self.shoots = state?.shoots ?? []
    self.day = Solar.day(on: date, place: place)
  }

  func persist() {
    if let data = try? JSONEncoder().encode(PlannerState(place: place, date: date, shoots: shoots))
    {
      defaults.set(data, forKey: key)
    }
  }
  func select(_ newPlace: Place) {
    let components = place.calendar.dateComponents(
      [.year, .month, .day, .hour, .minute], from: date)
    place = newPlace
    date = place.calendar.date(from: components) ?? date
    refresh()
  }
  func selectDate(_ newDate: Date) {
    let time = place.calendar.dateComponents([.hour, .minute], from: date)
    date =
      place.calendar.date(
        bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: newDate) ?? newDate
    refresh()
  }
  func shiftDay(_ amount: Int) {
    date = place.calendar.date(byAdding: .day, value: amount, to: date) ?? date
    refresh()
  }
  func scrub(_ fraction: Double) {
    date = day.date(at: fraction)
    persist()
  }
  func refresh() {
    day = Solar.day(on: date, place: place)
    persist()
  }
  func save(title: String, notes: String) {
    shoots.insert(
      Shoot(
        title: title.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes, place: place,
        date: date), at: 0)
    persist()
  }
  func open(_ shoot: Shoot) {
    place = shoot.place
    date = shoot.date
    refresh()
  }
  func delete(_ id: UUID) {
    shoots.removeAll { $0.id == id }
    persist()
  }
  func update(_ shoot: Shoot) {
    if let index = shoots.firstIndex(where: { $0.id == shoot.id }) {
      shoots[index] = shoot
      persist()
    }
  }
}
