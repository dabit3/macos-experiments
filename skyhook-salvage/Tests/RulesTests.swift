import XCTest

@testable import SkyhookSalvage

final class RulesTests: XCTestCase {
  func testCatchWindowReflectsCargoWidth() {
    XCTAssertTrue(DockRules.canCatch(hookX: 127, cargo: .trunk))
    XCTAssertFalse(DockRules.canCatch(hookX: 128, cargo: .trunk))
    XCTAssertTrue(DockRules.canCatch(hookX: 133, cargo: .piano))
    XCTAssertFalse(DockRules.canCatch(hookX: 134.1, cargo: .piano))
  }

  func testSupportRequiresMeaningfulOverlap() {
    let stack = [StackedCargo(id: 0, kind: .clock, x: 250)]
    XCTAssertTrue(DockRules.hasSupport(x: 290, kind: .piano, stack: stack))
    XCTAssertFalse(DockRules.hasSupport(x: 310, kind: .piano, stack: stack))
    XCTAssertTrue(DockRules.hasSupport(x: 310, kind: .piano, stack: []))
    XCTAssertFalse(DockRules.hasSupport(x: 390, kind: .trunk, stack: []))
  }

  func testWeightedBalanceAndCounterweight() {
    let heavyRight = [StackedCargo(id: 0, kind: .piano, x: 338)]
    XCTAssertFalse(DockRules.isStable(heavyRight))
    let counterbalanced = heavyRight + [StackedCargo(id: 1, kind: .piano, x: 178)]
    XCTAssertTrue(DockRules.isStable(counterbalanced))
    XCTAssertEqual(DockRules.balance(counterbalanced), 0, accuracy: 0.001)
    let lightRight = [StackedCargo(id: 0, kind: .plant, x: 338)]
    XCTAssertTrue(DockRules.isStable(lightRight))
  }

  func testPrecisionRewardsCenteredLanding() {
    XCTAssertEqual(DockRules.points(x: 258, kind: .piano, stack: []), 300)
    XCTAssertEqual(DockRules.points(x: 278, kind: .piano, stack: []), 260)
    let stack = [StackedCargo(id: 0, kind: .trunk, x: 270)]
    XCTAssertEqual(DockRules.points(x: 270, kind: .clock, stack: stack), 260)
  }
}

final class GameModelTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!

  override func setUp() {
    suite = "SkyhookSalvageTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suite)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suite)
    defaults = nil
  }

  func testCompleteContractPersistsBestAndUnlock() {
    let game = GameModel(defaults: defaults)
    game.start()
    for index in 0..<4 {
      game.clock = 0
      game.act()
      XCTAssertEqual(game.phase, .lowering)
      game.tick(0.61)
      XCTAssertEqual(game.phase, .hoisting)
      game.tick(1.11)
      XCTAssertEqual(game.phase, .release)
      game.clock = 0
      game.act()
      game.tick(0.71)
      XCTAssertEqual(game.stack.count, index + 1)
      game.tick(1.11)
    }
    XCTAssertEqual(game.phase, .finished)
    XCTAssertTrue(game.won)
    XCTAssertGreaterThan(game.score, 1000)
    let relaunched = GameModel(defaults: defaults)
    XCTAssertEqual(relaunched.best, game.score)
    XCTAssertEqual(relaunched.unlocked, 1)
    XCTAssertEqual(relaunched.completed, 1)
  }

  func testThreeMissesFailAndRestartClearsState() {
    let game = GameModel(defaults: defaults)
    game.start()
    for _ in 0..<3 {
      game.clock = .pi / (2 * game.contract.swing)
      game.trim = 1
      game.act()
      game.tick(0.61)
    }
    XCTAssertEqual(game.phase, .finished)
    XCTAssertFalse(game.won)
    XCTAssertEqual(game.losses, 3)
    game.start()
    XCTAssertEqual(game.phase, .pickup)
    XCTAssertEqual(game.score, 0)
    XCTAssertEqual(game.losses, 0)
    XCTAssertTrue(game.stack.isEmpty)
  }

  func testPauseFreezesClockAndBlocksActions() {
    let game = GameModel(defaults: defaults)
    game.start()
    game.paused = true
    game.tick(40)
    game.act()
    XCTAssertEqual(game.timeLeft, 90)
    XCTAssertEqual(game.clock, 0)
    XCTAssertEqual(game.phase, .pickup)
    game.paused = false
    game.tick(91)
    XCTAssertEqual(game.phase, .finished)
    XCTAssertFalse(game.won)
  }

  func testPracticeIgnoresMissLimitAndClockWithoutSavingBest() {
    let game = GameModel(defaults: defaults)
    game.start(practice: true)
    for _ in 0..<5 {
      game.clock = .pi / (2 * game.contract.swing)
      game.trim = 1
      game.act()
      game.tick(0.61)
    }
    XCTAssertEqual(game.losses, 5)
    XCTAssertEqual(game.phase, .pickup)
    game.tick(1000)
    XCTAssertEqual(game.timeLeft, 90)
    XCTAssertEqual(GameModel(defaults: defaults).best, 0)
  }

  func testRepeatedTapCannotSkipHoistingAndTrimIsBounded() {
    let game = GameModel(defaults: defaults)
    game.start()
    game.act()
    game.act()
    XCTAssertEqual(game.phase, .lowering)
    game.shift(100)
    XCTAssertEqual(game.trim, 1)
    game.shift(-100)
    XCTAssertEqual(game.trim, -1)
  }

  func testLandingGuideUsesTheSameDriftAsRelease() {
    let game = GameModel(defaults: defaults)
    game.start()
    game.act()
    game.tick(0.61)
    game.tick(1.11)
    game.clock = 0
    XCTAssertEqual(game.projectedX, 262.224, accuracy: 0.001)
    XCTAssertTrue(game.onTarget)
    game.act()
    game.tick(0.71)
    XCTAssertEqual(game.stack.first?.x ?? 0, 262.224, accuracy: 0.001)
  }

  func testLandingGuideRejectsUnsupportedPlacement() {
    let game = GameModel(defaults: defaults)
    game.start()
    game.stack = [StackedCargo(id: 0, kind: .clock, x: 258)]
    game.phase = .release
    game.trim = 1
    XCTAssertFalse(game.onTarget)
    game.trim = 0
    XCTAssertTrue(game.onTarget)
  }
}
