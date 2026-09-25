import XCTest

@testable import BentoCircuit

final class BentoCircuitTests: XCTestCase {
  func testTwelveAuthoredLunchesAreConnectedSeparatedAndExactlySolvable() {
    XCTAssertEqual(LunchBook.all.count, 12)
    for lunch in LunchBook.all {
      XCTAssertEqual(lunch.pieces.flatMap(\.cells).count, lunch.width * lunch.height, lunch.title)
      var game = PackingGame(lunch: lunch)
      for piece in lunch.pieces {
        var visited: Set<Cell> = []
        var frontier = [piece.cells[0]]
        while let cell = frontier.popLast() {
          if !visited.insert(cell).inserted { continue }
          let neighbors = [
            Cell(x: cell.x - 1, y: cell.y), Cell(x: cell.x + 1, y: cell.y),
            Cell(x: cell.x, y: cell.y - 1), Cell(x: cell.x, y: cell.y + 1),
          ]
          frontier += neighbors.filter { piece.cells.contains($0) && !visited.contains($0) }
        }
        XCTAssertEqual(visited.count, piece.cells.count, "\(lunch.title) piece \(piece.id)")
        XCTAssertNil(
          game.place(piece, at: Placement(anchor: piece.solution, turns: 0), lunch: lunch),
          lunch.title)
      }
      XCTAssertTrue(game.isComplete(lunch))
      XCTAssertTrue(game.isValid(for: lunch))
      XCTAssertEqual(game.stars(lunch), 3)
      XCTAssertFalse(game.isFailed(lunch))
    }
  }

  func testRotationPreservesAreaAndReturnsAfterFourTurns() {
    for piece in LunchBook.all.flatMap(\.pieces) {
      XCTAssertEqual(piece.rotated(0), piece.rotated(4))
      XCTAssertEqual(piece.rotated(-1), piece.rotated(3))
      for turns in 0..<4 {
        XCTAssertEqual(Set(piece.rotated(turns)).count, piece.cells.count)
        XCTAssertEqual(piece.rotated(turns).map(\.x).min(), 0)
        XCTAssertEqual(piece.rotated(turns).map(\.y).min(), 0)
      }
    }
  }

  func testClockwiseRotationChangesLShape() {
    let piece = LunchBook.all[0].pieces[0]
    XCTAssertEqual(
      Set(piece.rotated(1)), Set([Cell(x: 0, y: 0), Cell(x: 1, y: 0), Cell(x: 1, y: 1)]))
  }

  func testMarkedCellPlacementHandlesEmptyBoundingCornerAndRotation() {
    let piece = LunchBook.all[0].pieces[1]
    XCTAssertEqual(piece.anchor(placingMarkedCellAt: Cell(x: 1, y: 1), turns: 0), Cell(x: 0, y: 1))
    for turns in 0..<4 {
      let marked = piece.rotated(turns)[0]
      let target = Cell(x: 3, y: 2)
      let anchor = piece.anchor(placingMarkedCellAt: target, turns: turns)
      XCTAssertEqual(Cell(x: anchor.x + marked.x, y: anchor.y + marked.y), target)
    }
  }

  func testInvalidPlacementsDoNotSpendMoves() {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let savory = lunch.pieces[0]
    XCTAssertNotNil(
      game.place(savory, at: Placement(anchor: Cell(x: -1, y: 0), turns: 0), lunch: lunch))
    XCTAssertNotNil(
      game.place(savory, at: Placement(anchor: Cell(x: 0, y: 3), turns: 0), lunch: lunch))
    XCTAssertNotNil(
      game.place(savory, at: Placement(anchor: Cell(x: 2, y: 0), turns: 0), lunch: lunch))
    XCTAssertNotNil(
      game.place(savory, at: Placement(anchor: Cell(x: 1, y: 0), turns: 0), lunch: lunch))
    XCTAssertEqual(game.moves, 0)
    XCTAssertTrue(game.history.isEmpty)
  }

  func testSweetCannotEnterSavoryCompartment() {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let fruit = lunch.pieces.first { $0.ingredient.isSweet }!
    XCTAssertNotNil(
      game.place(fruit, at: Placement(anchor: Cell(x: 0, y: 0), turns: 0), lunch: lunch))
    XCTAssertEqual(game.moves, 0)
  }

  func testOverlapRejectedButPieceCanMoveOverItsOwnCells() {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let piece = lunch.pieces[0]
    XCTAssertNil(game.place(piece, at: Placement(anchor: Cell(x: 0, y: 0), turns: 0), lunch: lunch))
    XCTAssertNotNil(
      game.place(lunch.pieces[1], at: Placement(anchor: Cell(x: 0, y: 0), turns: 0), lunch: lunch))
    XCTAssertNil(game.place(piece, at: Placement(anchor: Cell(x: 0, y: 1), turns: 0), lunch: lunch))
    XCTAssertEqual(game.moves, 2)
    game.undo()
    XCTAssertEqual(game.moves, 1)
    XCTAssertEqual(game.placements[piece.id]?.anchor, Cell(x: 0, y: 0))
  }

  func testEquivalentPlacementDoesNotConsumeAMove() {
    let lunch = LunchBook.all[1]
    var game = PackingGame(lunch: lunch)
    let square = lunch.pieces[0]
    XCTAssertNil(game.place(square, at: Placement(anchor: square.solution, turns: 0), lunch: lunch))
    XCTAssertNotNil(
      game.place(square, at: Placement(anchor: square.solution, turns: 1), lunch: lunch))
    XCTAssertEqual(game.moves, 1)
  }

  func testBudgetFailureAndUndoRecovery() {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let piece = lunch.pieces[0]
    for move in 0..<lunch.moveLimit {
      XCTAssertNil(
        game.place(piece, at: Placement(anchor: Cell(x: 0, y: move % 2), turns: 0), lunch: lunch))
    }
    XCTAssertTrue(game.isFailed(lunch))
    XCTAssertNotNil(
      game.place(piece, at: Placement(anchor: Cell(x: 0, y: 0), turns: 0), lunch: lunch))
    game.undo()
    XCTAssertFalse(game.isFailed(lunch))
    XCTAssertEqual(game.moves, lunch.moveLimit - 1)
  }

  func testGuideAndExtraMovesAffectRating() {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let piece = lunch.pieces[0]
    XCTAssertEqual(game.stars(lunch), 0)
    XCTAssertNil(game.place(piece, at: Placement(anchor: Cell(x: 0, y: 1), turns: 0), lunch: lunch))
    for item in lunch.pieces {
      XCTAssertNil(game.place(item, at: Placement(anchor: item.solution, turns: 0), lunch: lunch))
    }
    XCTAssertEqual(game.stars(lunch), 2)
    game.usedGuide = true
    XCTAssertEqual(game.stars(lunch), 1)
  }

  func testDailySeedIsStableAndUsesUTCDate() {
    let date = Date(timeIntervalSince1970: 1_789_171_200)
    let daily = LunchBook.daily(on: date)
    let again = LunchBook.daily(on: date.addingTimeInterval(60))
    XCTAssertEqual(daily.id, again.id)
    XCTAssertEqual(daily.pieces, again.pieces)
    XCTAssertEqual(daily.initialTurns, again.initialTurns)
    XCTAssertNotEqual(daily.id, LunchBook.daily(on: date.addingTimeInterval(86400)).id)
    XCTAssertTrue(daily.isDaily)
  }

  func testSavedGameRoundTripIncludesUndoAndGuide() throws {
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    XCTAssertNil(
      game.place(lunch.pieces[0], at: Placement(anchor: Cell(x: 0, y: 0), turns: 0), lunch: lunch))
    game.usedGuide = true
    let data = try JSONEncoder().encode(game)
    var restored = try JSONDecoder().decode(PackingGame.self, from: data)
    XCTAssertTrue(restored.isValid(for: lunch))
    XCTAssertTrue(restored.usedGuide)
    XCTAssertEqual(restored.placements, game.placements)
    restored.undo()
    XCTAssertTrue(restored.placements.isEmpty)
    XCTAssertEqual(restored.moves, 0)
  }

  @MainActor func testProgressAndSettingsSurviveRelaunch() {
    let suite = "BentoCircuitTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let lunch = LunchBook.all[0]
    var game = PackingGame(lunch: lunch)
    let store = LunchStore(defaults: defaults)
    store.sound = true
    store.haptics = false
    for piece in lunch.pieces {
      XCTAssertNil(game.place(piece, at: Placement(anchor: piece.solution, turns: 0), lunch: lunch))
    }
    store.finish(game, lunch: lunch)
    game.usedGuide = true
    store.finish(game, lunch: lunch)
    let restored = LunchStore(defaults: defaults)
    XCTAssertEqual(restored.best[lunch.id], 3)
    XCTAssertEqual(restored.nextIndex, 1)
    XCTAssertTrue(restored.sound)
    XCTAssertFalse(restored.haptics)
  }
}
