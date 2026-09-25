import Foundation
import Testing

@testable import MiseCore

@Test func ingredientScalingAndFractions() {
  let pasta = Recipes.all[0].ingredients[0]
  #expect(pasta.quantity(servings: 3, base: 2) == "300 g")
  #expect(Quantity.format(0.5) == "½")
  #expect(Quantity.format(1.25) == "1¼")
  #expect(Quantity.format(0.125) == "⅛")
  #expect(Quantity.format(2) == "2")
}

@Test func servingsAndStepBounds() {
  var session = CookingSession()
  session.adjustServings(by: -50)
  #expect(session.servings == 1)
  session.adjustServings(by: 50)
  #expect(session.servings == 12)
  session.moveStep(by: 8, count: 5)
  #expect(session.step == 4)
  session.moveStep(by: -20, count: 5)
  #expect(session.step == 0)
}

@Test func independentTimersPauseResumeAndRestart() {
  let start = Date(timeIntervalSince1970: 100)
  var first = KitchenTimer(recipeID: "pomodoro", name: "Water", seconds: 15, now: start)
  let second = KitchenTimer(recipeID: "pomodoro", name: "Sauce", seconds: 30, now: start)
  first.togglePause(at: start.addingTimeInterval(5))
  #expect(first.remaining(at: start.addingTimeInterval(20)) == 10)
  #expect(second.remaining(at: start.addingTimeInterval(20)) == 10)
  first.togglePause(at: start.addingTimeInterval(20))
  #expect(first.remaining(at: start.addingTimeInterval(25)) == 5)
  #expect(first.isFinished(at: start.addingTimeInterval(31)))
  first.restart(at: start.addingTimeInterval(40))
  #expect(first.remaining(at: start.addingTimeInterval(40)) == 15)
  #expect(KitchenTimer.clock(0.2) == "00:01")
  #expect(KitchenTimer.clock(-3) == "00:00")
}

@Test func persistenceRestoresCookingAndElapsedDeadlines() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("state.json")
  var state = KitchenState()
  state.favorites = ["pomodoro"]
  state.sessions["pomodoro"] = CookingSession(
    servings: 4, prepared: ["pasta"], step: 2, started: true)
  state.activeRecipeID = "pomodoro"
  state.isCooking = true
  let start = Date(timeIntervalSince1970: 100)
  state.timers = [KitchenTimer(recipeID: "pomodoro", name: "Sauce", seconds: 15, now: start)]
  try KitchenPersistence.save(state, to: file)
  let restored = try KitchenPersistence.load(from: file)
  #expect(restored == state)
  #expect(restored.timers[0].isFinished(at: start.addingTimeInterval(20)))
  #expect(restored.sessions["pomodoro"]?.prepared.contains("pasta") == true)
}

@Test func malformedPersistenceThrows() throws {
  let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: file) }
  try Data("not json".utf8).write(to: file)
  #expect(throws: (any Error).self) { try KitchenPersistence.load(from: file) }
}

@Test func completeAndInternallyConsistentRecipeCollection() {
  #expect(Recipes.all.count == 5)
  #expect(Set(Recipes.all.map(\.id)).count == 5)
  for recipe in Recipes.all {
    #expect(recipe.ingredients.count >= 7)
    #expect(recipe.steps.count >= 5)
    #expect(!recipe.substitutions.isEmpty)
    #expect(Set(recipe.ingredients.map(\.id)).count == recipe.ingredients.count)
    for step in recipe.steps {
      #expect((step.timerName == nil) == (step.timerSeconds == nil))
      #expect(step.timerSeconds.map { $0 > 0 } ?? true)
    }
  }
}
