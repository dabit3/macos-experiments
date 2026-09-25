import XCTest

@testable import DominoDaydream

final class ChainTests: XCTestCase {
  func testEveryAuthoredBoardHasAchievableSuccessAndExactInventory() {
    for puzzle in Puzzle.all {
      let missing = puzzle.solution.filter { puzzle.fixed[$0.key] == nil }
      let result = ChainEngine.run(puzzle: puzzle, placed: missing)
      XCTAssertTrue(result.won, "\(puzzle.title): \(result.failures)")
      XCTAssertTrue(result.failures.isEmpty, "\(puzzle.title): dangling route")
      XCTAssertGreaterThanOrEqual(puzzle.targets.count, 2)
      for kind in PieceKind.allCases {
        XCTAssertEqual(missing.values.filter { $0.kind == kind }.count, puzzle.inventory[kind] ?? 0)
      }
    }
  }

  func testEmptyBoardExplainsTheMissingSocketAndDoesNotWin() {
    let puzzle = Puzzle.all[0]
    let result = ChainEngine.run(puzzle: puzzle, placed: [:])
    XCTAssertFalse(result.won)
    XCTAssertEqual(
      result.failures[Cell(x: 2, y: 5)], "The nudge reached an empty socket. Add a piece here.")
    XCTAssertEqual(result.reached.count, 0)
    XCTAssertEqual(result.chainLength, 3)
  }

  func testRotatedLineStopsAtClosedEdge() {
    let puzzle = Puzzle.all[0]
    let placed = [
      Cell(x: 2, y: 5): Piece(kind: .straight, rotation: 1),
      Cell(x: 5, y: 5): Piece(kind: .straight),
    ]
    let result = ChainEngine.run(puzzle: puzzle, placed: placed)
    XCTAssertFalse(result.won)
    XCTAssertEqual(
      result.failures[Cell(x: 2, y: 5)], "The nudge hit a closed edge. Rotate this piece.")
  }

  func testBridgeIsRequiredToSkipWater() {
    let puzzle = Puzzle.all[2]
    var placed = puzzle.solution.filter { puzzle.fixed[$0.key] == nil }
    placed[Cell(x: 1, y: 5)] = Piece(kind: .straight)
    let broken = ChainEngine.run(puzzle: puzzle, placed: placed)
    XCTAssertFalse(broken.won)
    XCTAssertEqual(
      broken.failures[Cell(x: 2, y: 5)], "The chain fell into the canal. Use a Bridge.")
    placed[Cell(x: 1, y: 5)] = Piece(kind: .bridge)
    XCTAssertTrue(ChainEngine.run(puzzle: puzzle, placed: placed).won)
  }

  func testThreeBellSplitHasDeterministicEventsAndScorePenalties() {
    let puzzle = Puzzle.all[6]
    let first = ChainEngine.run(puzzle: puzzle, placed: puzzle.solution)
    let second = ChainEngine.run(puzzle: puzzle, placed: puzzle.solution)
    XCTAssertEqual(first.events, second.events)
    XCTAssertEqual(first.reached.count, 3)
    XCTAssertEqual(first.score(hints: 0, attempts: 1) - first.score(hints: 2, attempts: 3), 200)
    XCTAssertEqual(Set(first.events.map(\.cell)).count, first.events.count)
    XCTAssertEqual(first.chainLength, puzzle.solution.values.reduce(0) { $0 + $1.ports.count + 1 })
  }

  func testFourQuarterTurnsPreservePorts() {
    for kind in PieceKind.allCases {
      let piece = Piece(kind: kind)
      XCTAssertEqual(piece.rotated.rotated.rotated.rotated, piece)
      XCTAssertEqual(Set(piece.ports).count, piece.ports.count)
    }
  }

  @MainActor
  func testInventoryUndoResetAndDraftPersistence() {
    let name = "DominoTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = GameStore(defaults: defaults)
    store.load(0)
    XCTAssertEqual(store.remaining(.straight), 2)
    store.tap(Cell(x: 2, y: 5))
    store.rotate()
    XCTAssertEqual(store.placed[Cell(x: 2, y: 5)]?.rotation, 1)
    store.undo()
    XCTAssertEqual(store.placed[Cell(x: 2, y: 5)]?.rotation, 0)
    XCTAssertEqual(store.remaining(.straight), 1)
    store.tap(Cell(x: 5, y: 5))
    XCTAssertEqual(store.remaining(.straight), 0)
    let restored = GameStore(defaults: defaults)
    restored.load(0)
    XCTAssertEqual(restored.placed, store.placed)
    restored.reset()
    XCTAssertTrue(restored.placed.isEmpty)
    restored.undo()
    XCTAssertEqual(restored.placed, store.placed)
  }

  @MainActor
  func testFixedPiecesCannotBeEditedAndHintsPersist() {
    let name = "DominoTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = GameStore(defaults: defaults)
    store.load(0)
    store.tap(Cell(x: 1, y: 5))
    XCTAssertTrue(store.placed.isEmpty)
    store.hint()
    XCTAssertEqual(store.hints, 1)
    XCTAssertEqual(store.selected, Cell(x: 2, y: 5))
    let restored = GameStore(defaults: defaults)
    restored.load(0)
    XCTAssertEqual(restored.hints, 1)
  }

  @MainActor
  func testSharePayloadRendersFullResolutionArtworkAndMatchingScore() throws {
    let puzzle = Puzzle.all[7]
    let result = ChainEngine.run(puzzle: puzzle, placed: puzzle.solution)
    let score = result.score(hints: 0, attempts: 1)
    let payload = try XCTUnwrap(
      SharePayload.make(puzzle: puzzle, pieces: puzzle.solution, result: result, score: score))
    XCTAssertEqual(payload.image.cgImage?.width, 1200)
    XCTAssertEqual(payload.image.cgImage?.height, 1720)
    XCTAssertGreaterThan(try XCTUnwrap(payload.image.pngData()).count, 50_000)
    XCTAssertTrue(payload.text.contains("\(result.chainLength) dominoes"))
    XCTAssertTrue(payload.text.contains("\(score) points"))
  }

  @MainActor
  func testSandboxAllowsOffBlueprintEditingWithoutInventoryLimit() {
    let name = "DominoTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = GameStore(defaults: defaults)
    store.load(8)
    store.choose(.turn)
    store.tap(Cell(x: 2, y: 3))
    XCTAssertEqual(store.placed[Cell(x: 2, y: 3)]?.kind, .turn)
    XCTAssertEqual(store.remaining(.turn), 99)
    XCTAssertNil(store.placed[store.puzzle.start])
  }
}
