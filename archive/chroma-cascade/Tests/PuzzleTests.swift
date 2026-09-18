import XCTest

@testable import ChromaCascade

final class PuzzleTests: XCTestCase {
  func testTransfersContiguousTopStackAndHonorsCapacity() throws {
    var puzzle = Puzzle(vessels: [[0, 1, 1, 1], [1, 1, 1], []])
    XCTAssertEqual(try puzzle.pour(from: 0, to: 1), 1)
    XCTAssertEqual(puzzle.vessels, [[0, 1, 1], [1, 1, 1, 1], []])
    XCTAssertEqual(try puzzle.pour(from: 0, to: 2), 2)
    XCTAssertEqual(puzzle.vessels, [[0], [1, 1, 1, 1], [1, 1]])
    XCTAssertEqual(puzzle.moves, 2)
  }

  func testIllegalMovesDoNotMutateHistoryOrBoard() {
    let original = Puzzle(vessels: [[0, 1], [0, 0, 0, 0], [2], []])
    for move in [(0, 0), (0, 1), (0, 2), (3, 0), (-1, 0), (0, 99)] {
      var puzzle = original
      XCTAssertThrowsError(try puzzle.pour(from: move.0, to: move.1))
      XCTAssertEqual(puzzle, original)
    }
  }

  func testSolvedRequiresFullSingleColorVessels() {
    XCTAssertTrue(Puzzle(vessels: [[0, 0, 0, 0], [], [1, 1, 1, 1]]).isSolved)
    XCTAssertFalse(Puzzle(vessels: [[0, 0], [0, 0], []]).isSolved)
    XCTAssertFalse(Puzzle(vessels: [[0, 0, 1, 1], []]).isSolved)
  }

  func testUndoRestoresExactBoardAndMoveCount() throws {
    var puzzle = Puzzle(vessels: Study.all[0].vessels)
    let original = puzzle
    try puzzle.pour(from: 0, to: 2)
    try puzzle.pour(from: 1, to: 0)
    puzzle.undo()
    XCTAssertEqual(puzzle.moves, 1)
    puzzle.undo()
    XCTAssertEqual(puzzle, original)
    puzzle.undo()
    XCTAssertEqual(puzzle, original)
  }

  func testAllTwelveStudiesHaveVerifiedLegalSolutions() throws {
    XCTAssertEqual(Study.all.count, 12)
    XCTAssertEqual(Set(Study.all.map(\.vessels)).count, 12)
    for study in Study.all {
      var puzzle = Puzzle(vessels: study.vessels)
      XCTAssertFalse(puzzle.isSolved, "Study \(study.number) must start unsolved")
      XCTAssertTrue(puzzle.isValid(for: study))
      for move in study.solution {
        try puzzle.pour(from: move.source, to: move.destination)
        XCTAssertTrue(puzzle.isValid(for: study))
      }
      XCTAssertTrue(puzzle.isSolved, "Study \(study.number) must be solvable")
    }
  }

  @MainActor
  func testPersistenceUndoRestartAndBestScore() throws {
    let suite = "chroma-tests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = CollectionStore(defaults: defaults)
    store.setSymbols(true)
    store.setHaptics(false)
    for move in Study.all[0].solution {
      try store.pour(0, from: move.source, to: move.destination)
    }
    store.open(3)
    let loaded = CollectionStore(defaults: defaults)
    XCTAssertTrue(loaded.puzzle(0).isSolved)
    XCTAssertEqual(loaded.saved.bestMoves[0], 3)
    XCTAssertEqual(loaded.saved.currentLevel, 3)
    XCTAssertTrue(loaded.saved.symbols)
    XCTAssertFalse(loaded.saved.haptics)
    loaded.undo(0)
    XCTAssertFalse(loaded.puzzle(0).isSolved)
    XCTAssertEqual(loaded.puzzle(0).moves, 2)
    loaded.restart(0)
    XCTAssertEqual(loaded.puzzle(0), Puzzle(vessels: Study.all[0].vessels))
    XCTAssertEqual(loaded.saved.bestMoves[0], 3)
    loaded.resetCollection()
    let reset = CollectionStore(defaults: defaults)
    XCTAssertTrue(reset.saved.bestMoves.isEmpty)
    XCTAssertTrue(reset.saved.puzzles.isEmpty)
    XCTAssertTrue(reset.saved.symbols)
  }

  @MainActor
  func testInvalidSavedDataFallsBackSafely() throws {
    let suite = "chroma-corrupt-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("invalid".utf8), forKey: "chroma.cascade.collection.v1")
    XCTAssertEqual(CollectionStore(defaults: defaults).saved.currentLevel, 0)
    var invalid = SavedCollection()
    invalid.currentLevel = 100
    defaults.set(try JSONEncoder().encode(invalid), forKey: "chroma.cascade.collection.v1")
    XCTAssertEqual(CollectionStore(defaults: defaults).saved.currentLevel, 0)
  }
}
