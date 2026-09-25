import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class KitchenStore {
  var state = KitchenState()
  var storageMessage: String?
  var showTimers = false
  var showSaved = false
  var prepUndo: (String, Set<String>)?
  private let file: URL

  init() {
    file = URL.applicationSupportDirectory.appendingPathComponent("Mise/kitchen.json")
    if FileManager.default.fileExists(atPath: file.path) {
      do {
        state = try KitchenPersistence.load(from: file)
        sanitize()
      } catch {
        storageMessage = "Your saved kitchen could not be read. A fresh session is ready."
      }
    }
  }

  var recipe: Recipe? { Recipes.all.first { $0.id == state.activeRecipeID } }

  func session(_ recipe: Recipe) -> CookingSession {
    state.sessions[recipe.id] ?? CookingSession(servings: recipe.baseServings)
  }

  func edit(_ recipe: Recipe, _ change: (inout CookingSession) -> Void) {
    var value = session(recipe)
    change(&value)
    state.sessions[recipe.id] = value
    save()
  }

  func open(_ recipe: Recipe) {
    state.activeRecipeID = recipe.id
    state.isCooking = false
    save()
  }

  func home() {
    state.activeRecipeID = nil
    state.isCooking = false
    save()
  }

  func begin(_ recipe: Recipe) {
    edit(recipe) {
      if $0.completed { $0.step = 0 }
      $0.started = true
      $0.completed = false
    }
    state.isCooking = true
    save()
  }

  func favorite(_ recipe: Recipe) {
    if state.favorites.contains(recipe.id) {
      state.favorites.remove(recipe.id)
    } else {
      state.favorites.insert(recipe.id)
    }
    save()
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }

  func toggleIngredient(_ ingredient: Ingredient, recipe: Recipe) {
    edit(recipe) {
      if $0.prepared.contains(ingredient.id) {
        $0.prepared.remove(ingredient.id)
      } else {
        $0.prepared.insert(ingredient.id)
      }
    }
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }

  func resetPrep(_ recipe: Recipe) {
    prepUndo = (recipe.id, session(recipe).prepared)
    edit(recipe) { $0.prepared = [] }
  }

  func undoPrep(_ recipe: Recipe) {
    guard let undo = prepUndo, undo.0 == recipe.id else { return }
    edit(recipe) { $0.prepared = undo.1 }
    prepUndo = nil
  }

  func addTimer(recipe: Recipe, name: String, seconds: Int) {
    state.timers.append(KitchenTimer(recipeID: recipe.id, name: name, seconds: seconds))
    save()
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
  }

  func toggleTimer(_ id: UUID) {
    guard let index = state.timers.firstIndex(where: { $0.id == id }) else { return }
    state.timers[index].togglePause()
    save()
  }

  func restartTimer(_ id: UUID) {
    guard let index = state.timers.firstIndex(where: { $0.id == id }) else { return }
    state.timers[index].restart()
    save()
  }

  func removeTimer(_ id: UUID) {
    state.timers.removeAll { $0.id == id }
    save()
  }

  func export(_ recipe: Recipe) -> String {
    let current = session(recipe)
    let ingredients = recipe.ingredients.map {
      "\($0.quantity(servings: current.servings, base: recipe.baseServings)) \($0.name)"
    }.joined(separator: "\n")
    let steps = recipe.steps.enumerated().map {
      "\($0.offset + 1). \($0.element.title.replacingOccurrences(of: "\n", with: " "))\n\($0.element.instruction)"
    }.joined(separator: "\n\n")
    return
      "MISE — \(recipe.title.replacingOccurrences(of: "\n", with: " "))\n\(current.servings) servings\n\n\(ingredients)\n\n\(steps)"
  }

  func save() {
    do { try KitchenPersistence.save(state, to: file) } catch {
      storageMessage = "Mise couldn’t save this change. Please check device storage and try again."
    }
  }

  private func sanitize() {
    if recipe == nil {
      state.activeRecipeID = nil
      state.isCooking = false
    }
    for recipe in Recipes.all {
      guard var current = state.sessions[recipe.id] else { continue }
      current.adjustServings(by: 0)
      current.moveStep(by: 0, count: recipe.steps.count)
      current.prepared.formIntersection(recipe.ingredients.map(\.id))
      state.sessions[recipe.id] = current
    }
  }
}
