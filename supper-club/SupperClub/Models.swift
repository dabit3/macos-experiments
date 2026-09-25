import Combine
import Foundation

struct Ingredient: Codable, Hashable, Identifiable {
  var name: String
  var quantity: Double
  var unit: String
  var note: String = ""
  var id: String { name.lowercased() + "|" + unit.lowercased() }

  func scaled(_ servings: Int, from base: Int) -> Ingredient {
    var copy = self
    copy.quantity *= Double(servings) / Double(base)
    return copy
  }

  var amount: String {
    [Quantity.format(quantity), unit].filter { !$0.isEmpty }.joined(separator: " ")
  }
}

enum Quantity {
  static func format(_ value: Double) -> String {
    let whole = Int(value)
    let fraction = value - Double(whole)
    let fractions: [(Double, String)] = [
      (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"),
      (2.0 / 3, "⅔"), (0.75, "¾"), (0.875, "⅞"),
    ]
    if abs(fraction) < 0.001 { return "\(whole)" }
    if let match = fractions.first(where: { abs($0.0 - fraction) < 0.001 }) {
      return (whole > 0 ? "\(whole)" : "") + match.1
    }
    return value.formatted(.number.precision(.fractionLength(0...2)))
  }
}

struct CookStep: Identifiable, Hashable {
  let title: String
  let instruction: String
  var timerName: String? = nil
  var seconds: Int = 0
  var id: String { title }
}

struct Recipe: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String
  let minutes: Int
  let servings: Int
  let label: String
  let style: Int
  let ingredients: [Ingredient]
  let steps: [CookStep]

  func matches(_ query: String) -> Bool {
    let words = query.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "," })
    let haystack = ([title, subtitle] + ingredients.map(\.name)).joined(separator: " ").lowercased()
    return words.allSatisfy { haystack.contains($0) }
  }
}

struct ShoppingItem: Identifiable {
  let id: String
  var ingredient: Ingredient
  var sources: [String]
  var customID: UUID?
}

struct CustomItem: Codable, Identifiable {
  var id = UUID()
  var name: String
}

struct KitchenTimer: Codable, Identifiable {
  var id: String
  var name: String
  var duration: TimeInterval
  var remainingWhenPaused: TimeInterval
  var deadline: Date?

  init(id: String, name: String, seconds: Int) {
    self.id = id
    self.name = name
    self.duration = TimeInterval(seconds)
    self.remainingWhenPaused = TimeInterval(seconds)
  }

  func remaining(at now: Date = .now) -> TimeInterval {
    max(0, deadline.map { $0.timeIntervalSince(now) } ?? remainingWhenPaused)
  }

  func isFinished(at now: Date = .now) -> Bool {
    deadline != nil && remaining(at: now) <= 0
  }

  mutating func start(at now: Date = .now) {
    guard deadline == nil else { return }
    deadline = now.addingTimeInterval(remainingWhenPaused)
  }

  mutating func pause(at now: Date = .now) {
    remainingWhenPaused = remaining(at: now)
    deadline = nil
  }

  mutating func reset() {
    deadline = nil
    remainingWhenPaused = duration
  }
}

struct KitchenState: Codable {
  var favorites: Set<String> = []
  var servings: [String: Int] = [:]
  var shoppingRecipes: [String: Int] = [:]
  var checked: Set<String> = []
  var custom: [CustomItem] = []
  var cookRecipeID: String?
  var cookStep = 0
  var timers: [String: KitchenTimer] = [:]
  var mealsCooked = 0
}

@MainActor
final class KitchenStore: ObservableObject {
  @Published var state: KitchenState {
    didSet { save() }
  }
  private let defaults: UserDefaults
  private let key = "supper-club.kitchen.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let decoded = try? JSONDecoder().decode(KitchenState.self, from: data)
    {
      state = decoded
    } else {
      state = KitchenState()
    }
  }

  private func save() {
    if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
  }

  func servings(for recipe: Recipe) -> Int { state.servings[recipe.id] ?? recipe.servings }

  func setServings(_ count: Int, for recipe: Recipe) {
    state.servings[recipe.id] = min(12, max(1, count))
  }

  func toggleFavorite(_ recipe: Recipe) {
    if state.favorites.contains(recipe.id) {
      state.favorites.remove(recipe.id)
    } else {
      state.favorites.insert(recipe.id)
    }
  }

  var shopping: [ShoppingItem] {
    var combined: [String: ShoppingItem] = [:]
    for recipe in Recipes.all {
      guard let servings = state.shoppingRecipes[recipe.id] else { continue }
      for item in recipe.ingredients {
        let scaled = item.scaled(servings, from: recipe.servings)
        if var existing = combined[item.id] {
          existing.ingredient.quantity += scaled.quantity
          existing.sources.append(recipe.title)
          combined[item.id] = existing
        } else {
          combined[item.id] = ShoppingItem(
            id: item.id, ingredient: scaled, sources: [recipe.title])
        }
      }
    }
    return combined.values.sorted { $0.ingredient.name < $1.ingredient.name }
      + state.custom.map {
        ShoppingItem(
          id: $0.id.uuidString, ingredient: Ingredient(name: $0.name, quantity: 1, unit: ""),
          sources: ["Your extra"], customID: $0.id)
      }
  }

  func addIngredients(_ recipe: Recipe) {
    let old = shopping
    state.shoppingRecipes[recipe.id] = servings(for: recipe)
    let changed = shopping.filter { item in
      old.first(where: { $0.id == item.id })?.ingredient.quantity != item.ingredient.quantity
    }
    state.checked.subtract(changed.map(\.id))
  }

  func toggleChecked(_ id: String) {
    if state.checked.contains(id) { state.checked.remove(id) } else { state.checked.insert(id) }
  }

  func clearShopping() {
    state.shoppingRecipes = [:]
    state.custom = []
    state.checked = []
  }

  func saveCustom(_ name: String, id: UUID? = nil) {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return }
    if let id, let index = state.custom.firstIndex(where: { $0.id == id }) {
      state.custom[index].name = name
    } else if !state.custom.contains(where: { $0.name.lowercased() == name.lowercased() }) {
      state.custom.append(CustomItem(name: name))
    }
  }

  func deleteCustom(_ id: UUID) {
    state.custom.removeAll { $0.id == id }
    state.checked.remove(id.uuidString)
  }

  func beginCooking(_ recipe: Recipe) {
    if state.cookRecipeID != recipe.id {
      state.cookStep = 0
      state.cookRecipeID = recipe.id
    }
  }

  func finishCooking() {
    state.mealsCooked += 1
    state.cookRecipeID = nil
    state.cookStep = 0
  }

  func makeTimer(id: String, name: String, seconds: Int) {
    guard state.timers[id] == nil else { return }
    state.timers[id] = KitchenTimer(id: id, name: name, seconds: seconds)
  }

  func toggleTimer(_ id: String, now: Date = .now) {
    guard var timer = state.timers[id] else { return }
    if timer.isFinished(at: now) { timer.reset() }
    if timer.deadline == nil { timer.start(at: now) } else { timer.pause(at: now) }
    state.timers[id] = timer
  }

  func resetTimer(_ id: String) { state.timers[id]?.reset() }
}
