import XCTest

@testable import SupperClub

final class KitchenTests: XCTestCase {
  func testFractionsAndScaling() {
    XCTAssertEqual(Quantity.format(0.25), "¼")
    XCTAssertEqual(Quantity.format(1.5), "1½")
    XCTAssertEqual(Quantity.format(0.125), "⅛")
    XCTAssertEqual(Quantity.format(22.5), "22½")
    let lemon = Ingredient(name: "Lemon", quantity: 0.5, unit: "")
    XCTAssertEqual(lemon.scaled(1, from: 2).amount, "¼")
    XCTAssertEqual(lemon.scaled(3, from: 2).amount, "¾")
  }

  func testIngredientSearchAndRecipeIntegrity() {
    XCTAssertEqual(Recipes.all.count, 10)
    XCTAssertEqual(Set(Recipes.all.map(\.id)).count, 10)
    XCTAssertEqual(
      Recipes.all.filter { $0.matches("  TOMATO   basil ") }.map(\.id), ["tomato-orzo"])
    XCTAssertTrue(Recipes.all.filter { $0.matches("impossibleingredient") }.isEmpty)
    XCTAssertEqual(Recipes.all.filter { $0.matches("chickpeas") }.count, 2)
    for recipe in Recipes.all {
      XCTAssertFalse(recipe.ingredients.isEmpty)
      XCTAssertGreaterThanOrEqual(recipe.steps.count, 4)
      XCTAssertEqual(Set(recipe.ingredients.map(\.id)).count, recipe.ingredients.count)
      XCTAssertTrue(recipe.ingredients.allSatisfy { $0.quantity > 0 })
      for step in recipe.steps where step.timerName != nil {
        XCTAssertGreaterThan(step.seconds, 0)
      }
    }
  }

  @MainActor
  func testShoppingDeduplicationAndRescaling() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let store = KitchenStore(defaults: defaults)
    let orzo = Recipes.all[0]
    let toast = Recipes.all[1]
    store.setServings(1, for: orzo)
    store.addIngredients(orzo)
    store.addIngredients(orzo)
    XCTAssertEqual(store.shopping.count, orzo.ingredients.count)
    XCTAssertEqual(
      store.shopping.first { $0.ingredient.name == "Lemon" }?.ingredient.quantity, 0.25)
    store.addIngredients(toast)
    XCTAssertEqual(
      store.shopping.first { $0.ingredient.name == "Lemon" }?.ingredient.quantity, 0.75)
    XCTAssertEqual(
      store.shopping.first { $0.ingredient.name == "Olive oil" }?.ingredient.quantity, 1.5)
    let lemonID = "lemon|"
    store.toggleChecked(lemonID)
    store.setServings(3, for: orzo)
    store.addIngredients(orzo)
    XCTAssertFalse(store.state.checked.contains(lemonID))
    XCTAssertEqual(
      store.shopping.first { $0.ingredient.name == "Lemon" }?.ingredient.quantity, 1.25)
  }

  @MainActor
  func testPersistenceCustomEditingAndServingBounds() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let recipe = Recipes.all[0]
    let store = KitchenStore(defaults: defaults)
    store.setServings(30, for: recipe)
    XCTAssertEqual(store.servings(for: recipe), 12)
    store.setServings(0, for: recipe)
    XCTAssertEqual(store.servings(for: recipe), 1)
    store.toggleFavorite(recipe)
    store.addIngredients(recipe)
    store.saveCustom("  Bread  ")
    store.saveCustom("bread")
    store.saveCustom("   ")
    XCTAssertEqual(store.state.custom.count, 1)
    let id = store.state.custom[0].id
    store.saveCustom("2 loaves", id: id)
    store.toggleChecked(id.uuidString)
    store.beginCooking(recipe)
    store.state.cookStep = 2
    store.makeTimer(id: "test", name: "Sauce", seconds: 30)
    store.toggleTimer("test", now: Date(timeIntervalSince1970: 100))
    let restored = KitchenStore(defaults: defaults)
    XCTAssertTrue(restored.state.favorites.contains(recipe.id))
    XCTAssertEqual(restored.state.cookStep, 2)
    XCTAssertEqual(restored.state.custom[0].name, "2 loaves")
    XCTAssertTrue(restored.state.checked.contains(id.uuidString))
    XCTAssertEqual(restored.state.shoppingRecipes[recipe.id], 1)
    XCTAssertEqual(restored.state.timers["test"]?.deadline, Date(timeIntervalSince1970: 130))
    restored.deleteCustom(id)
    XCTAssertTrue(restored.state.custom.isEmpty)
    XCTAssertFalse(restored.state.checked.contains(id.uuidString))
    restored.clearShopping()
    XCTAssertTrue(restored.shopping.isEmpty)
    XCTAssertTrue(restored.state.favorites.contains(recipe.id))
  }

  func testTimerPauseResumeRelaunchExpiryAndReset() throws {
    let start = Date(timeIntervalSince1970: 100)
    var timer = KitchenTimer(id: "rice", name: "Rice", seconds: 60)
    timer.start(at: start)
    timer.start(at: start.addingTimeInterval(5))
    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(10)), 50)
    timer.pause(at: start.addingTimeInterval(20))
    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(100)), 40)
    timer.start(at: start.addingTimeInterval(100))
    let data = try JSONEncoder().encode(timer)
    var restored = try JSONDecoder().decode(KitchenTimer.self, from: data)
    XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(110)), 30)
    XCTAssertTrue(restored.isFinished(at: start.addingTimeInterval(140)))
    XCTAssertEqual(restored.remaining(at: start.addingTimeInterval(999)), 0)
    restored.reset()
    XCTAssertEqual(restored.remaining(), 60)
    XCTAssertNil(restored.deadline)
  }

  @MainActor
  func testCookingResumeAndCompletion() {
    let store = KitchenStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    store.beginCooking(Recipes.all[0])
    store.state.cookStep = 3
    store.beginCooking(Recipes.all[0])
    XCTAssertEqual(store.state.cookStep, 3)
    store.beginCooking(Recipes.all[1])
    XCTAssertEqual(store.state.cookStep, 0)
    store.finishCooking()
    XCTAssertNil(store.state.cookRecipeID)
    XCTAssertEqual(store.state.mealsCooked, 1)
  }
}
