import XCTest

@testable import ArchipelagoCore

final class SimulationTests: XCTestCase {
  func testConservationAcrossProductionConsumptionAndTransport() throws {
    var game = Game.initial
    try game.createRoute(source: 0, destination: 1)
    try game.assign(ferryID: 0, routeID: 0)
    try game.createRoute(source: 2, destination: 3)
    try game.assign(ferryID: 1, routeID: 1)
    for _ in 0..<5_000 {
      game.advance()
      for resource in Resource.allCases {
        XCTAssertEqual(
          game.total(resource: resource) + game.consumed[resource.rawValue],
          Game.initial.total(resource: resource) + game.produced[resource.rawValue])
      }
    }
    try game.validate()
    XCTAssertGreaterThan(game.consumed[0], 0)
    XCTAssertGreaterThan(game.delivered, 100)
  }

  func testDepartureCapacityArrivalAndReturn() throws {
    var game = Game.initial
    try game.createRoute(source: 0, destination: 1)
    game.advance(steps: 2)
    XCTAssertEqual(game.routes[0].progress, 0)
    try game.assign(ferryID: 0, routeID: 0)
    game.advance()
    XCTAssertEqual(game.routes[0].cargo, 12)
    XCTAssertEqual(game.islands[0].inventory[0], 36)
    let duration = Int(ceil(game.duration(for: game.routes[0])))
    game.advance(steps: duration - 1)
    XCTAssertTrue(game.routes[0].returning)
    XCTAssertEqual(game.delivered, 12)
    XCTAssertEqual(game.islands[1].inventory[0], 12)
    XCTAssertEqual(game.budget, 276)
    game.advance(steps: duration)
    XCTAssertFalse(game.routes[0].returning)
    XCTAssertEqual(game.routes[0].cargo, 0)
  }

  func testEditAndRemovalReturnCargoWithoutCreatingResources() throws {
    var game = Game.initial
    try game.createRoute(source: 0, destination: 1)
    try game.assign(ferryID: 0, routeID: 0)
    game.advance(steps: 3)
    try game.editRoute(id: 0, source: 0, destination: 4)
    XCTAssertEqual(game.total(resource: .grain), 48)
    XCTAssertEqual(game.routes[0].cargo, 0)
    XCTAssertEqual(game.routes[0].progress, 0)
    game.advance(steps: 3)
    game.removeRoute(id: 0)
    XCTAssertEqual(game.total(resource: .grain), 48)
    XCTAssertEqual(game.budget, 260)
    try game.validate()
  }

  func testValidationAndInsufficientBudgetAreAtomic() throws {
    var game = Game.initial
    XCTAssertThrowsError(try game.createRoute(source: 0, destination: 0))
    XCTAssertThrowsError(try game.createRoute(source: -1, destination: 1))
    try game.createRoute(source: 0, destination: 1)
    XCTAssertThrowsError(try game.createRoute(source: 0, destination: 1))
    try game.assign(ferryID: 0, routeID: 0)
    try game.createRoute(source: 2, destination: 1)
    XCTAssertThrowsError(try game.assign(ferryID: 0, routeID: 1))
    game.budget = 0
    let before = game
    XCTAssertThrowsError(try game.createRoute(source: 0, destination: 4))
    XCTAssertEqual(game, before)
  }

  func testDeterminismSaveReloadAndGoal() throws {
    var first = Game.initial
    try first.createRoute(source: 0, destination: 4)
    try first.assign(ferryID: 2, routeID: 0)
    try first.createRoute(source: 2, destination: 1)
    try first.assign(ferryID: 1, routeID: 1)
    first.advance(steps: 57)
    var second = try Game.decode(first.encoded())
    XCTAssertEqual(first, second)
    first.advance(steps: 1_000)
    for _ in 0..<1_000 { second.advance() }
    XCTAssertEqual(first, second)
    XCTAssertTrue(first.goalMet)
    XCTAssertGreaterThanOrEqual(first.lanternDelivered, 8)
  }

  func testCorruptSavesRejected() throws {
    XCTAssertThrowsError(try Game.decode(Data("{}".utf8)))
    var game = Game.initial
    game.islands[0].inventory[0] = -1
    XCTAssertThrowsError(try game.encoded())
    game = Game.initial
    game.islands[0].inventory[0] += 10
    XCTAssertThrowsError(try game.encoded())
    game = Game.initial
    game.version = 2
    XCTAssertThrowsError(try game.encoded())
  }
}
