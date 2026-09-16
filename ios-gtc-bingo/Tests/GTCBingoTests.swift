import XCTest

@testable import GTCBingoCore

final class GTCBingoTests: XCTestCase {
  func testDeckIsLargeUniqueAndContainsRequestedExamples() {
    XCTAssertGreaterThanOrEqual(BingoDeck.tropes.count, 60)
    XCTAssertEqual(Set(BingoDeck.tropes).count, BingoDeck.tropes.count)
    for trope in [
      "Leather jacket", "The more you buy, the more you save",
      "A new chip is held up to the light", "Dinosaur-sized wafer",
      "Trillion-parameter something", "Demo lag joke",
    ] {
      XCTAssertTrue(BingoDeck.tropes.contains(trope))
    }
  }

  func testCardHasUniqueCellsAndFreeCenter() {
    let card = BingoCard(seed: 42)
    XCTAssertEqual(card.cells.count, 25)
    XCTAssertEqual(Set(card.cells).count, 25)
    XCTAssertEqual(card.cells[12], "GPU FREE SPACE")
    XCTAssertEqual(card.marked, [12])
  }

  func testSeededCardsAreDeterministic() {
    XCTAssertEqual(BingoCard(seed: 42), BingoCard(seed: 42))
    XCTAssertNotEqual(BingoCard(seed: 42), BingoCard(seed: 43))
  }

  func testThereAreTwelveLines() {
    XCTAssertEqual(BingoCard.lines.count, 12)
    XCTAssertEqual(Set(BingoCard.lines.flatMap { $0 }).count, 25)
  }

  func testBingoDetectsRowsColumnsAndDiagonals() {
    for line in BingoCard.lines {
      var card = BingoCard(seed: 7)
      for index in line where index != 12 { card.toggle(index) }
      XCTAssertTrue(card.hasBingo, "Expected bingo for \(line)")
    }
  }

  func testCenterCannotBeUnmarked() {
    var card = BingoCard(seed: 1)
    card.toggle(12)
    XCTAssertTrue(card.marked.contains(12))
  }

  func testWouldCompleteLine() {
    var card = BingoCard(seed: 1)
    for index in [0, 1, 2, 3] { card.toggle(index) }
    XCTAssertTrue(card.wouldCompleteLine(byMarking: 4))
    XCTAssertFalse(card.wouldCompleteLine(byMarking: 5))
  }

  func testScoreboardRejectsBlankAndCapsPlayers() {
    var state = GameState()
    XCTAssertFalse(state.addPlayer(name: "  "))
    for index in 2...6 { XCTAssertTrue(state.addPlayer(name: "Player \(index)")) }
    XCTAssertFalse(state.addPlayer(name: "Overflow"))
    XCTAssertEqual(state.players.count, GameState.maxPlayers)
  }

  func testPlayerNavigationWraps() {
    var state = GameState()
    _ = state.addPlayer(name: "Player 2")
    state.previousPlayer()
    XCTAssertEqual(state.current.name, "Player 2")
    state.nextPlayer()
    XCTAssertEqual(state.current.name, "Player 1")
  }

  func testNewRoundFreshCardsAndRoundIncrement() {
    var state = GameState()
    _ = state.addPlayer(name: "Player 2")
    let oldSeeds = state.players.map(\.card.seed)
    state.newRound(seed: 100)
    XCTAssertEqual(state.totalRounds, 2)
    XCTAssertNotEqual(oldSeeds, state.players.map(\.card.seed))
    XCTAssertEqual(state.currentIndex, 0)
  }

  func testLeaderboardOrdersWinsThenName() {
    var state = GameState()
    _ = state.addPlayer(name: "Ada")
    _ = state.addPlayer(name: "Zed")
    state.players[0].wins = 2
    state.players[1].wins = 2
    state.players[2].wins = 1
    XCTAssertEqual(state.leaderboard.map(\.name), ["Ada", "Player 1", "Zed"])
  }

  func testGameStateCodableRoundTrip() throws {
    var state = GameState()
    _ = state.addPlayer(name: "Ada")
    state.players[0].wins = 3
    let data = try JSONEncoder().encode(state)
    XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
  }
}
