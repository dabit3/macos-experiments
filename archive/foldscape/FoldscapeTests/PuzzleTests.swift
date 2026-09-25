import XCTest

@testable import Foldscape

struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64
  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

final class PuzzleTests: XCTestCase {
  func testBoardHitMappingKeepsCellsGapsAndEdgesSeparate() {
    let grid = BoardGeometry(side: 312)
    for row in 0..<3 {
      for column in 0..<3 {
        let x = Double(column * 106)
        let y = Double(row * 106)
        for inset in [0.0, 1, 50, 99.9] {
          XCTAssertEqual(grid.index(x: x + inset, y: y + inset), row * 3 + column)
        }
      }
    }
    XCTAssertNil(grid.index(x: 102, y: 50))
    XCTAssertNil(grid.index(x: 50, y: 102))
    XCTAssertNil(grid.index(x: -1, y: 50))
    XCTAssertNil(grid.index(x: 312, y: 50))
    XCTAssertNil(grid.index(x: .infinity, y: 50))
    XCTAssertNil(grid.index(x: .nan, y: 50))
    XCTAssertNil(BoardGeometry(side: 0).index(x: 0, y: 0))
  }

  func testAllShufflesAreSolvableNonCompleteAndHaveValidHintPaths() {
    for seed in 1...300 {
      for pace in Pace.allCases {
        var generator = SeededGenerator(state: UInt64(seed))
        let puzzle = Puzzle(pace: pace, generator: &generator)
        XCTAssertTrue(Puzzle.isSolvable(puzzle.tiles))
        XCTAssertFalse(puzzle.isComplete)
        XCTAssertTrue(puzzle.isValid)
        XCTAssertEqual(puzzle.moves, 0)
      }
    }
  }

  func testLegalMovesAndInvalidIndices() {
    var generator = SeededGenerator(state: 14)
    var puzzle = Puzzle(pace: .gentle, generator: &generator)
    let before = puzzle
    XCTAssertFalse(puzzle.move(at: -1))
    XCTAssertFalse(puzzle.move(at: 9))
    XCTAssertFalse(puzzle.move(at: puzzle.blank))
    XCTAssertEqual(puzzle, before)
    for index in puzzle.legalIndices {
      XCTAssertTrue(Puzzle.adjacent(index, puzzle.blank))
    }
    let index = puzzle.legalIndices[0]
    let blank = puzzle.blank
    let value = puzzle.tiles[index]
    XCTAssertTrue(puzzle.move(at: index))
    XCTAssertEqual(puzzle.tiles[blank], value)
    XCTAssertEqual(puzzle.tiles[index], 0)
    XCTAssertEqual(puzzle.moves, 1)
    XCTAssertTrue(puzzle.isValid)
  }

  func testHintsCompleteEveryPaceEvenAfterArbitraryMoves() {
    for seed in 1...100 {
      var generator = SeededGenerator(state: UInt64(seed))
      var puzzle = Puzzle(pace: .wandering, generator: &generator)
      for _ in 0..<30 {
        if puzzle.isComplete { break }
        let index = puzzle.legalIndices.randomElement(using: &generator)!
        XCTAssertTrue(puzzle.move(at: index))
      }
      var remaining = 100
      while !puzzle.isComplete && remaining > 0 {
        guard let index = puzzle.hintIndex else {
          XCTFail("Unfinished puzzle lost its route home")
          break
        }
        XCTAssertTrue(puzzle.move(at: index))
        remaining -= 1
      }
      XCTAssertTrue(puzzle.isComplete)
      XCTAssertTrue(puzzle.isValid)
      let moves = puzzle.moves
      XCTAssertFalse(puzzle.move(at: 7))
      XCTAssertEqual(puzzle.moves, moves)
    }
  }

  func testSolvabilityRejectsMalformedOrOddParityBoards() {
    XCTAssertFalse(Puzzle.isSolvable([2, 1, 3, 4, 5, 6, 7, 8, 0]))
    XCTAssertFalse(Puzzle.isSolvable([1, 2, 3]))
    XCTAssertFalse(Puzzle.isSolvable([1, 2, 3, 4, 5, 6, 7, 7, 0]))
    XCTAssertTrue(Puzzle.isSolvable(Puzzle.solved))
    XCTAssertFalse(Puzzle.adjacent(2, 3))
  }

  @MainActor
  func testPersistenceCompletionBestAndReset() throws {
    let suite = "FoldscapeTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = AtlasStore(defaults: defaults)
    store.begin("mosslight", pace: .gentle)
    let original = try XCTUnwrap(store.saved.puzzles["mosslight"])
    XCTAssertTrue(store.move("mosslight", at: try XCTUnwrap(original.hintIndex)))
    let resumed = AtlasStore(defaults: defaults)
    XCTAssertEqual(resumed.saved.puzzles["mosslight"], store.saved.puzzles["mosslight"])
    while let puzzle = resumed.saved.puzzles["mosslight"], !puzzle.isComplete {
      XCTAssertTrue(resumed.move("mosslight", at: try XCTUnwrap(puzzle.hintIndex)))
    }
    let record = try XCTUnwrap(resumed.saved.completions["mosslight"])
    XCTAssertEqual(record.count, 1)
    XCTAssertGreaterThan(record.bestMoves, 0)
    XCTAssertFalse(resumed.move("mosslight", at: 7))
    XCTAssertEqual(resumed.saved.completions["mosslight"]?.count, 1)
    let relaunched = AtlasStore(defaults: defaults)
    XCTAssertEqual(relaunched.saved.completions["mosslight"], record)
    relaunched.begin("mosslight", pace: .wandering)
    XCTAssertEqual(relaunched.saved.completions["mosslight"], record)
    relaunched.reset()
    XCTAssertTrue(AtlasStore(defaults: defaults).saved.completions.isEmpty)
    XCTAssertTrue(AtlasStore(defaults: defaults).saved.puzzles.isEmpty)
  }

  @MainActor
  func testCorruptStorageRecoversToUsableAtlas() throws {
    let suite = "FoldscapeTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(Data("not valid JSON".utf8), forKey: AtlasStore.storageKey)
    let store = AtlasStore(defaults: defaults)
    XCTAssertTrue(store.saved.puzzles.isEmpty)
    store.begin("terra-arch", pace: .gentle)
    XCTAssertTrue(try XCTUnwrap(store.saved.puzzles["terra-arch"]).isValid)
  }
}
