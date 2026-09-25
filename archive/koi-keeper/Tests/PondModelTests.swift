import XCTest

@testable import KoiKeeper

@MainActor
final class PondModelTests: XCTestCase {
  private func model() -> PondModel {
    let defaults = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
    return PondModel(defaults: defaults)
  }

  func testFoodCapacityAndSingleConsumptionReward() {
    let pond = model()
    for _ in 0..<10 { pond.feed(at: PondPoint(x: 0.5, y: 0.5)) }
    XCTAssertEqual(pond.food.count, 8)
    let food = pond.food[0]
    let fish = pond.save.fish[0]
    XCTAssertTrue(pond.consume(foodID: food.id, fishID: fish.id))
    XCTAssertFalse(pond.consume(foodID: food.id, fishID: fish.id))
    XCTAssertEqual(pond.save.pearls, 13)
    XCTAssertEqual(pond.save.totalMeals, 1)
    XCTAssertEqual(pond.save.fish[0].meals, 1)
  }

  func testInvalidFeedingAndFoodExpiryDoNotReward() {
    let pond = model()
    XCTAssertFalse(pond.feed(at: PondPoint(x: .nan, y: 0.4)))
    XCTAssertFalse(pond.feed(at: PondPoint(x: 0, y: 0)))
    pond.feed(at: PondPoint(x: 0.5, y: 0.4))
    pond.ageFood(by: 46)
    XCTAssertTrue(pond.food.isEmpty)
    XCTAssertEqual(pond.save.pearls, 12)
  }

  func testPurchaseIsAtomicAndCapacityIsEnforced() {
    let pond = model()
    XCTAssertFalse(pond.addFish(.asagi))
    XCTAssertEqual(pond.save.fish.count, 2)
    XCTAssertEqual(pond.save.pearls, 12)
    XCTAssertTrue(pond.addFish(.kohaku))
    XCTAssertEqual(pond.save.pearls, 0)
    for _ in 0..<40 {
      pond.feed(at: PondPoint(x: 0.5, y: 0.4))
      for grain in pond.food { pond.consume(foodID: grain.id, fishID: pond.save.fish[0].id) }
    }
    for _ in 0..<3 { XCTAssertTrue(pond.addFish(.kohaku)) }
    let balance = pond.save.pearls
    XCTAssertFalse(pond.addFish(.kohaku))
    XCTAssertEqual(pond.save.pearls, balance)
    XCTAssertEqual(pond.save.fish.count, 6)
  }

  func testPlacementValidatesBoundsOverlapAndBalance() {
    let pond = model()
    XCTAssertFalse(pond.place(.stone, at: PondPoint(x: 0.02, y: 0.4)))
    XCTAssertFalse(pond.place(.stone, at: PondPoint(x: 0.22, y: 0.29)))
    XCTAssertEqual(pond.save.pearls, 12)
    XCTAssertTrue(pond.place(.lily, at: PondPoint(x: 0.5, y: 0.5)))
    XCTAssertEqual(pond.save.pearls, 4)
    XCTAssertFalse(pond.place(.stone, at: PondPoint(x: 0.3, y: 0.65)))
    XCTAssertEqual(pond.save.garden.count, 4)
    XCTAssertTrue(pond.remove(at: PondPoint(x: 0.5, y: 0.5)))
    XCTAssertEqual(pond.save.pearls, 12)
    XCTAssertFalse(pond.remove(at: PondPoint(x: 0.5, y: 0.5)))
    XCTAssertEqual(pond.save.pearls, 12)
  }

  func testSaveLoadAndReset() {
    let defaults = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
    let pond = PondModel(defaults: defaults)
    pond.place(.lily, at: PondPoint(x: 0.5, y: 0.5))
    pond.setHaptics(false)
    let loaded = PondModel(defaults: defaults)
    XCTAssertEqual(loaded.save.garden.count, 4)
    XCTAssertEqual(loaded.save.pearls, 4)
    XCTAssertFalse(loaded.save.haptics)
    XCTAssertEqual(loaded.save.garden.last?.point, PondPoint(x: 0.5, y: 0.5))
    loaded.reset()
    let reset = PondModel(defaults: defaults)
    XCTAssertEqual(reset.save.fish.count, 2)
    XCTAssertEqual(reset.save.garden.count, 3)
    XCTAssertEqual(reset.save.pearls, 12)
  }

  func testPlacementPreviewDoesNotSpendAndRechecksAtConfirmation() {
    let pond = model()
    let target = PondPoint(x: 0.5, y: 0.5)
    XCTAssertNil(pond.placementIssue(.stone, at: target))
    XCTAssertEqual(pond.save.pearls, 12)
    XCTAssertEqual(pond.save.garden.count, 3)
    XCTAssertNotNil(pond.placementIssue(.stone, at: pond.save.garden[0].point))
    XCTAssertTrue(pond.addFish(.kohaku))
    XCTAssertNotNil(pond.placementIssue(.stone, at: target))
    XCTAssertFalse(pond.place(.stone, at: target))
    XCTAssertEqual(pond.save.pearls, 0)
    XCTAssertEqual(pond.save.garden.count, 3)
  }

  func testCorruptAndOutOfRangeSavesFallBackSafely() throws {
    let defaults = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
    defaults.set(Data("invalid".utf8), forKey: "koi-keeper.pond.v1")
    XCTAssertEqual(PondModel(defaults: defaults).save.pearls, 12)
    var invalid = PondSave()
    invalid.pearls = -1
    defaults.set(try JSONEncoder().encode(invalid), forKey: "koi-keeper.pond.v1")
    XCTAssertEqual(PondModel(defaults: defaults).save.pearls, 12)
  }

  func testFishActuallySeekAndConsumeFood() {
    let pond = model()
    let engine = PondEngine()
    pond.feed(at: PondPoint(x: 0.6, y: 0.5))
    for _ in 0..<900 { engine.step(model: pond, delta: 1.0 / 30, reduceMotion: false) }
    XCTAssertTrue(pond.food.isEmpty)
    XCTAssertEqual(pond.save.totalMeals, 3)
    XCTAssertEqual(pond.save.pearls, 15)
    XCTAssertTrue(engine.swimmers.allSatisfy { $0.point.isInside })
  }
}
