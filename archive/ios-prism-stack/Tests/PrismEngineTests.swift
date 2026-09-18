import Foundation
import Testing

@testable import PrismCore

@Test func eachBagContainsSevenDifferentPieces() {
  var game = PrismEngine(seed: 41)
  var dealt: [Jewel] = []
  for _ in 0..<70 {
    dealt.append(game.active!.jewel)
    game.spawn()
  }
  for offset in stride(from: 0, to: 70, by: 7) {
    #expect(Set(dealt[offset..<offset + 7]).count == 7)
  }
}

@Test func seededGamesAreReproducibleThroughSerialization() throws {
  var first = PrismEngine(seed: 928)
  first.move(-1)
  first.rotate()
  first.hardDrop()
  var restored = try JSONDecoder().decode(PrismEngine.self, from: JSONEncoder().encode(first))
  for _ in 0..<5 {
    first.hardDrop()
    restored.hardDrop()
  }
  #expect(first == restored)
}

@Test func collisionRejectsWallsFloorAndOccupiedCells() {
  var game = PrismEngine(seed: 1)
  #expect(!game.fits(Piece(jewel: .cyan, x: -1, y: 1)))
  #expect(!game.fits(Piece(jewel: .cyan, x: 7, y: 1)))
  #expect(!game.fits(Piece(jewel: .gold, x: 3, y: 21)))
  game.board[5][4] = 2
  #expect(!game.fits(Piece(jewel: .gold, x: 3, y: 4)))
}

@Test func rotationsReturnToOriginalAndKickOffWallsAndFloor() {
  for jewel in Jewel.allCases where jewel != .gold {
    var game = PrismEngine(seed: 1)
    game.active = Piece(jewel: jewel, y: 6)
    let initial = game.active
    for _ in 0..<4 {
      let rotated = game.rotate()
      #expect(rotated)
    }
    #expect(game.active == initial)
  }
  var game = PrismEngine(seed: 1)
  game.active = Piece(jewel: .violet, rotation: 1, x: -1, y: 10)
  let wallKick = game.rotate(clockwise: false)
  #expect(wallKick)
  #expect(game.active!.x == 0)
  game.active = Piece(jewel: .cyan, x: 3, y: 20)
  let floorKick = game.rotate()
  #expect(floorKick)
  #expect(game.fits(game.active!))
  #expect(game.active!.y == 18)
}

@Test func blockedRotationLeavesPieceUnchanged() {
  var game = PrismEngine(seed: 1)
  game.active = Piece(jewel: .violet, x: 3, y: 10)
  game.board = Array(repeating: Array(repeating: 1, count: 10), count: 22)
  for cell in game.active!.cells { game.board[cell.y][cell.x] = 0 }
  let original = game.active
  let rotated = game.rotate()
  #expect(!rotated)
  #expect(game.active == original)
}

@Test func ghostHardDropAndHoldFollowRules() {
  var game = PrismEngine(seed: 8)
  let first = game.active!.jewel
  game.hold()
  #expect(game.held == first)
  let second = game.active
  game.hold()
  #expect(game.active == second)
  let ghost = game.ghost!
  let distance = ghost.y - game.active!.y
  game.hardDrop()
  #expect(game.score == distance * 2)
  #expect(game.pieces == 1)
  #expect(game.canHold)
  for cell in ghost.cells { #expect(game.board[cell.y][cell.x] == ghost.jewel.rawValue) }
  game.hold()
  #expect(game.active!.jewel == first)
  #expect(game.active!.rotation == 0)
}

@Test func fourLineClearCompactsBoardAndAwardsBackToBack() {
  var game = PrismEngine(seed: 1)
  for attempt in 0..<2 {
    for row in 18..<22 {
      game.board[row] = Array(repeating: 2, count: 10)
      game.board[row][5] = 0
    }
    game.active = Piece(jewel: .cyan, rotation: 1, x: 3, y: 18)
    game.hardDrop()
    #expect(game.lastClear == 4)
    #expect(game.board.allSatisfy { $0.allSatisfy { $0 == 0 } })
    #expect(game.score == (attempt == 0 ? 800 : 2050))
  }
  #expect(game.lines == 8)
}

@Test func singleClearPreservesBlocksAboveAndAdvancesLevel() {
  var game = PrismEngine(seed: 1)
  game.lines = 9
  game.board[21] = Array(repeating: 3, count: 10)
  for x in 3..<7 { game.board[21][x] = 0 }
  game.board[20][0] = 5
  game.active = Piece(jewel: .cyan, x: 3, y: 20)
  game.hardDrop()
  #expect(game.lines == 10)
  #expect(game.level == 2)
  #expect(game.score == 100)
  #expect(game.board[21][0] == 5)
  #expect(game.gravityInterval < 0.85)
}

@Test func lockDelayAndResetCapPreventInfiniteStalling() {
  var game = PrismEngine(seed: 1)
  game.active = Piece(jewel: .gold, x: 3, y: 20)
  for _ in 0..<4 { game.tick(0.1) }
  #expect(game.pieces == 0)
  game.move(1)
  #expect(game.lockClock == 0)
  for index in 0..<20 { game.move(index.isMultiple(of: 2) ? -1 : 1) }
  #expect(game.lockResets == 15)
  for _ in 0..<5 { game.tick(0.1) }
  #expect(game.pieces == 1)
}

@Test func occupiedSpawnEndsGameAndRejectsFurtherInputs() {
  var game = PrismEngine(seed: 1)
  game.board[2] = Array(repeating: 1, count: 10)
  game.spawn()
  #expect(game.isOver)
  let original = game
  game.hardDrop()
  game.hold()
  game.tick(0.1)
  let moved = game.move(1)
  let rotated = game.rotate()
  #expect(!moved)
  #expect(!rotated)
  #expect(game == original)
}

@Test func randomLegalActionsNeverOverlapOrEscapeBoard() {
  for seed in 0..<40 {
    var game = PrismEngine(seed: UInt64(seed))
    var random = SeededRandom(state: UInt64(seed))
    for _ in 0..<500 where !game.isOver {
      switch random.next() % 6 {
      case 0: game.move(-1)
      case 1: game.move(1)
      case 2: game.rotate()
      case 3: game.softDrop()
      case 4: game.hold()
      default: game.hardDrop()
      }
      if !game.isOver {
        #expect(game.fits(game.active!))
        #expect(game.fits(game.ghost!))
        #expect(!game.fits(game.shifted(game.ghost!, dx: 0, dy: 1)))
      }
      #expect(game.board.count == 22)
    }
  }
}
