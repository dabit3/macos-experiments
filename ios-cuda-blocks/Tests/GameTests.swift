import XCTest

@testable import CudaBlocksCore

final class TetrominoTests: XCTestCase {
  func testEveryKernelHasFourCellsInEveryRotation() {
    for k in Kernel.allCases {
      for r in 0..<4 {
        XCTAssertEqual(k.cells(rotation: r).count, 4, "\(k) r\(r)")
        XCTAssertEqual(Set(k.cells(rotation: r)).count, 4, "\(k) r\(r) has duplicates")
      }
    }
  }

  func testRotationCycleReturnsToStart() {
    for k in Kernel.allCases {
      XCTAssertEqual(k.cells(rotation: 4), k.cells(rotation: 0))
    }
  }

  func testOKernelDoesNotMoveWhenRotated() {
    XCTAssertEqual(Set(Kernel.o.cells(rotation: 1)), Set(Kernel.o.cells(rotation: 0)))
  }

  func testIKernelVerticalRotation() {
    let cells = Set(Kernel.i.cells(rotation: 1))
    XCTAssertEqual(cells, [Cell(0, 2), Cell(1, 2), Cell(2, 2), Cell(3, 2)])
  }
}

final class BoardTests: XCTestCase {
  func testBoardDimensions() {
    let b = Board()
    XCTAssertEqual(Board.width, 10)
    XCTAssertEqual(Board.height, 20)
    XCTAssertEqual(b.totalRows, 22)
  }

  func testFitsRejectsOutOfBoundsAndOverlap() {
    var b = Board()
    XCTAssertFalse(b.fits(Piece(kernel: .o, origin: Cell(0, -2))))
    XCTAssertFalse(b.fits(Piece(kernel: .o, origin: Cell(21, 3))))
    let p = Piece(kernel: .o, origin: Cell(20, 3))
    XCTAssertTrue(b.fits(p))
    b.lock(p)
    XCTAssertFalse(b.fits(p))
  }

  func testClearRowsDropsStack() {
    var b = Board()
    for c in 0..<Board.width { b[Cell(21, c)] = .i }
    b[Cell(20, 0)] = .t
    XCTAssertEqual(b.fullRows(), [21])
    XCTAssertEqual(b.clear(rows: [21]), 1)
    XCTAssertEqual(b[Cell(21, 0)], .t)
    XCTAssertNil(b[Cell(20, 0)])
    XCTAssertEqual(b.occupiedCount, 1)
  }

  func testToppedOut() {
    var b = Board()
    XCTAssertFalse(b.isToppedOut)
    b[Cell(1, 4)] = .z
    XCTAssertTrue(b.isToppedOut)
  }
}

final class RandomizerTests: XCTestCase {
  func testSevenBagYieldsEachKernelOncePerBag() {
    var bag = KernelBag(seed: 42)
    for _ in 0..<5 {
      var seen = Set<Kernel>()
      for _ in 0..<7 { seen.insert(bag.next()) }
      XCTAssertEqual(seen.count, 7)
    }
  }

  func testSeedIsDeterministic() {
    var a = KernelBag(seed: 7)
    var b = KernelBag(seed: 7)
    for _ in 0..<30 { XCTAssertEqual(a.next(), b.next()) }
  }
}

final class EngineTests: XCTestCase {
  /// Fills row `row` completely except at `gap` columns.
  private func fill(_ engine: inout GameEngine, row: Int, except gaps: Set<Int>) {
    var s = engine.state
    for c in 0..<Board.width where !gaps.contains(c) { s.board[Cell(row, c)] = .l }
    engine = GameEngine(resuming: s)
  }

  private func engine(with kernel: Kernel, queue: [Kernel] = [.o, .o, .o, .o, .o]) -> GameEngine {
    var s = GameState(seed: 1)
    s.queue = queue
    s.current = Piece(kernel: kernel, rotation: 0, origin: Cell(0, 3))
    return GameEngine(resuming: s)
  }

  func testSpawnsWithPreviewQueue() {
    let e = GameEngine(seed: 3)
    XCTAssertNotNil(e.current)
    XCTAssertEqual(e.state.queue.count, GameEngine.previewCount)
    XCTAssertFalse(e.isOver)
  }

  func testMoveAndWallBlock() {
    var e = engine(with: .o)
    XCTAssertEqual(e.move(-1), [.moved])
    for _ in 0..<10 { _ = e.move(-1) }
    XCTAssertEqual(e.move(-1), [.blocked])
    XCTAssertEqual(e.current?.cells.map(\.col).min(), 0)
  }

  func testGhostMatchesHardDrop() {
    var e = engine(with: .t)
    let ghost = e.ghost
    let events = e.hardDrop()
    XCTAssertEqual(events.first, .hardDropped(rows: 20))
    XCTAssertTrue(events.contains(.locked(kernel: .t)))
    XCTAssertEqual(ghost?.cells.map { e.board[$0] }.compactMap { $0 }.count, 4)
  }

  func testHardDropAwardsTwoPerRow() {
    var e = engine(with: .o)
    _ = e.hardDrop()
    XCTAssertEqual(e.state.score, 40)
  }

  func testSingleClearDispatchesWarp() {
    var e = engine(with: .i)
    fill(&e, row: 21, except: [3, 4, 5, 6])
    fill(&e, row: 20, except: Set(1..<Board.width))
    let events = e.hardDrop()
    guard
      case .warpsDispatched(let rows, let count, let tSpin, let points)? =
        events.first(where: {
          if case .warpsDispatched = $0 { return true }
          return false
        })
    else { return XCTFail("no clear") }
    XCTAssertEqual(rows, [21])
    XCTAssertEqual(count, 1)
    XCTAssertNil(tSpin)
    XCTAssertEqual(points, 100)
    XCTAssertEqual(e.state.lines, 1)
    XCTAssertEqual(e.state.multiplier, 1)
  }

  func testTensorCoreDoublesMultiplier() {
    var e = engine(with: .i)
    for row in 18...21 { fill(&e, row: row, except: [0]) }
    _ = e.rotate()  // vertical I at col ~5
    var s = e.state
    s.current = Piece(kernel: .i, rotation: 1, origin: Cell(0, -2))  // vertical bar in col 0
    e = GameEngine(resuming: s)
    XCTAssertTrue(e.board.fits(e.current!))
    let events = e.hardDrop()
    XCTAssertTrue(events.contains(.tensorCore(multiplier: 2)))
    XCTAssertEqual(e.state.multiplier, 2)
    XCTAssertEqual(e.state.tensorCores, 1)
    XCTAssertEqual(e.state.lines, 4)
    XCTAssertTrue(events.contains(.perfectClear))
    // 800 base * level 1 * multiplier 2 + perfect clear 2000 + hard drop 2*rows
    XCTAssertGreaterThanOrEqual(e.state.score, 800 * 2 + 2000)
  }

  func testNonTensorClearHalvesMultiplier() {
    var s = GameState(seed: 1)
    s.multiplier = 8
    s.queue = [.o, .o, .o, .o, .o]
    s.current = Piece(kernel: .i, rotation: 0, origin: Cell(0, 3))
    var e = GameEngine(resuming: s)
    fill(&e, row: 21, except: [3, 4, 5, 6])
    _ = e.hardDrop()
    XCTAssertEqual(e.state.multiplier, 4)
  }

  func testHoldSwapsOncePerPiece() {
    var e = engine(with: .t, queue: [.i, .o, .s, .z, .j])
    XCTAssertEqual(e.holdPiece(), [.held])
    XCTAssertEqual(e.state.hold, .t)
    XCTAssertEqual(e.current?.kernel, .i)
    XCTAssertEqual(e.holdPiece(), [.blocked])
    _ = e.hardDrop()
    XCTAssertTrue(e.state.canHold)
    _ = e.holdPiece()
    XCTAssertEqual(e.current?.kernel, .t)
  }

  func testLevelUpEveryTenLines() {
    var s = GameState(seed: 1)
    s.lines = 9
    s.queue = [.o, .o, .o, .o, .o]
    s.current = Piece(kernel: .i, rotation: 0, origin: Cell(0, 3))
    var e = GameEngine(resuming: s)
    fill(&e, row: 21, except: [3, 4, 5, 6])
    let events = e.hardDrop()
    XCTAssertTrue(events.contains(.levelUp(level: 2)))
    XCTAssertLessThan(GameEngine(resuming: e.state).gravityInterval, 1.0)
  }

  func testGravityAdvancesAndLocks() {
    var e = engine(with: .o)
    let start = e.current!.origin.row
    _ = e.advance(by: e.gravityInterval + 0.001)
    XCTAssertEqual(e.current!.origin.row, start + 1)
    // Drive to the floor and through lock delay.
    for _ in 0..<40 { _ = e.advance(by: 1.0) }
    XCTAssertGreaterThan(e.state.piecesPlaced, 0)
  }

  func testSoftDropScoresOnePerRow() {
    var e = engine(with: .o)
    XCTAssertEqual(e.softDropStep(), [.softDropped])
    XCTAssertEqual(e.state.score, 1)
  }

  func testTSpinDetection() {
    // T-slot: row 21 gap at col 4; row 20 gaps at 3,4,5; overhang at (19,5).
    var e = engine(with: .t)
    fill(&e, row: 21, except: [4])
    fill(&e, row: 20, except: [3, 4, 5])
    var s = e.state
    s.board[Cell(19, 5)] = .l
    s.current = Piece(kernel: .t, rotation: 0, origin: Cell(19, 3))
    e = GameEngine(resuming: s)
    XCTAssertTrue(e.board.fits(e.current!))
    // Two clockwise rotations point the T down into the slot; the last move is a rotation.
    _ = e.rotate()
    _ = e.rotate()
    XCTAssertEqual(e.current?.rotation, 2)
    let events = e.hardDrop()
    let clear = events.first {
      if case .warpsDispatched = $0 { return true }
      return false
    }
    guard case .warpsDispatched(_, let count, let tSpin, let points)? = clear else {
      return XCTFail("expected clear, got \(events)")
    }
    XCTAssertEqual(count, 2)
    XCTAssertEqual(tSpin, .full)
    XCTAssertEqual(points, 1200)
    XCTAssertEqual(e.state.tSpins, 1)
  }

  func testGameOverWhenStackReachesBuffer() {
    var e = engine(with: .o)
    var s = e.state
    for row in 2..<22 { for c in 0..<Board.width where c != 9 { s.board[Cell(row, c)] = .j } }
    e = GameEngine(resuming: s)
    let events = e.hardDrop()
    XCTAssertTrue(events.contains(.gameOver))
    XCTAssertTrue(e.isOver)
  }

  func testStateRoundTripsThroughCodable() throws {
    var e = GameEngine(seed: 99)
    _ = e.move(1)
    _ = e.rotate()
    let data = try JSONEncoder().encode(e.state)
    let restored = try JSONDecoder().decode(GameState.self, from: data)
    XCTAssertEqual(restored, e.state)
  }
}

final class LeaderboardTests: XCTestCase {
  func testSubmitRanksAndCaps() {
    var lb = Leaderboard()
    for i in 1...12 {
      lb.submit(LeaderboardEntry(name: "K\(i)", score: i * 100, lines: i, level: 1, tensorCores: 0))
    }
    XCTAssertEqual(lb.entries.count, Leaderboard.capacity)
    XCTAssertEqual(lb.best, 1200)
    XCTAssertFalse(lb.qualifies(score: 100))
    XCTAssertTrue(lb.qualifies(score: 350))
    let rank = lb.submit(
      LeaderboardEntry(name: "X", score: 1150, lines: 0, level: 1, tensorCores: 0))
    XCTAssertEqual(rank, 2)
  }

  func testZeroScoreNeverQualifies() {
    XCTAssertFalse(Leaderboard().qualifies(score: 0))
  }

  func testEncodeDecode() throws {
    var lb = Leaderboard()
    lb.submit(LeaderboardEntry(name: "SM", score: 500, lines: 5, level: 1, tensorCores: 1))
    let data = try lb.encoded()
    XCTAssertEqual(Leaderboard.decode(data), lb)
  }

  func testFormatting() {
    XCTAssertEqual(ScoreFormat.compact(12345), "12,345")
    XCTAssertEqual(ScoreFormat.clock(level: 1), "1.00 GHz")
    XCTAssertEqual(ScoreFormat.clock(level: 5), "1.60 GHz")
  }
}
