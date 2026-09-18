import XCTest

@testable import GoldenDropRules

final class GameRulesTests: XCTestCase {
  func testBoardsHaveDistinctPlayableGeometry() {
    XCTAssertEqual(Board.all.count, 6)
    for board in Board.all {
      XCTAssertGreaterThan(board.pegs.filter { $0.kind == .gold }.count, 7)
      XCTAssertTrue(board.pegs.contains { $0.kind == .green })
      for peg in board.pegs {
        XCTAssertTrue((35...355).contains(peg.position.x), board.name)
        XCTAssertTrue((110...470).contains(peg.position.y), board.name)
        for other in board.pegs where other.id != peg.id {
          XCTAssertGreaterThan(
            hypot(peg.position.x - other.position.x, peg.position.y - other.position.y), 20,
            board.name)
        }
      }
    }
  }

  func testLaunchConsumesOnlyOneBallAndClampsAim() {
    var game = GameRules(board: Board.all[0])
    game.aim(at: .init(x: 9999, y: 0))
    XCTAssertEqual(game.angle, 1.2)
    game.launch()
    game.launch()
    XCTAssertEqual(game.balls, 13)
    XCTAssertEqual(game.phase, .flying)
    XCTAssertGreaterThan(game.velocity.x, 0)
  }

  func testHitScoresOnceAndGreenGiftsBall() {
    let board = Board(
      id: 9, name: "Test", subtitle: "", symbol: "",
      pegs: [
        Peg(id: 0, position: .init(x: 195, y: 180), kind: .green),
        Peg(id: 1, position: .init(x: 310, y: 260), kind: .gold),
      ], balls: 3)
    var game = GameRules(board: board)
    game.launch()
    game.ball = .init(x: 195, y: 165)
    game.velocity = .init(x: 0, y: 150)
    game.step(1.0 / 120)
    XCTAssertEqual(game.balls, 3)
    XCTAssertEqual(game.score, 150)
    game.ball = .init(x: 195, y: 165)
    game.velocity = .init(x: 0, y: 150)
    game.step(1.0 / 120)
    XCTAssertEqual(game.score, 150)
    XCTAssertEqual(game.balls, 3)
  }

  func testCatchReturnsBallAndMissEndsRun() {
    var game = GameRules(board: Board.all[0])
    game.balls = 1
    game.launch()
    game.ball = .init(x: game.bucketX, y: 515)
    game.step(1.0 / 120)
    XCTAssertEqual(game.balls, 1)
    XCTAssertEqual(game.score, 500)
    XCTAssertEqual(game.phase, .aiming)
    game.launch()
    game.ball = .init(x: 21, y: 515)
    game.step(1.0 / 120)
    XCTAssertEqual(game.phase, .lost)
  }

  func testShotRemovesHitsAndAwardsCombo() {
    var game = GameRules(board: Board.all[0])
    game.launch()
    game.pegs[0].hit = true
    game.pegs[1].hit = true
    game.shotHits = 2
    game.shotScore = 120
    game.score = 120
    game.finishShot(catchBall: false)
    XCTAssertEqual(game.pegs.count, game.board.pegs.count - 2)
    XCTAssertEqual(game.score, 240)
    XCTAssertEqual(game.phase, .aiming)
  }

  func testFinalHitSlowsThenWinsAndAwardsSavedBalls() {
    let board = Board(
      id: 9, name: "Finale", subtitle: "", symbol: "",
      pegs: [
        Peg(id: 0, position: .init(x: 195, y: 180), kind: .gold)
      ], balls: 10)
    var game = GameRules(board: board)
    game.launch()
    game.ball = .init(x: 195, y: 165)
    game.velocity = .init(x: 0, y: 150)
    game.step(1.0 / 120)
    XCTAssertNotNil(game.finaleRemaining)
    XCTAssertEqual(game.phase, .flying)
    for _ in 0..<250 { game.step(1.0 / 120) }
    XCTAssertEqual(game.phase, .won)
    XCTAssertEqual(game.stars, 3)
    XCTAssertGreaterThanOrEqual(game.score, 11500)
    let finalScore = game.score
    game.step(10)
    XCTAssertEqual(game.score, finalScore)
  }

  func testMultiPegWinningShotReceivesComboExactlyOnce() {
    let board = Board(
      id: 9, name: "Final combo", subtitle: "", symbol: "",
      pegs: [
        Peg(id: 0, position: .init(x: 195, y: 180), kind: .blue),
        Peg(id: 1, position: .init(x: 300, y: 250), kind: .gold),
      ], balls: 10)
    var game = GameRules(board: board)
    game.launch()
    for point in [Vector(x: 195, y: 165), Vector(x: 300, y: 235)] {
      game.ball = point
      game.velocity = .init(x: 0, y: 150)
      game.step(1.0 / 120)
    }
    XCTAssertEqual(game.shotHits, 2)
    XCTAssertEqual(game.shotScore, 520)
    for _ in 0..<250 { game.step(1.0 / 120) }
    XCTAssertEqual(game.phase, .won)
    XCTAssertEqual(game.score, 520 * 2 + 2500 + 9 * 1000)
    for _ in 0..<250 { game.step(1.0 / 120) }
    XCTAssertEqual(game.score, 12540)
  }

  func testEveryShotSettlesWithoutInvalidPhysics() {
    for board in Board.all {
      for angle in stride(from: -1.2, through: 1.2, by: 0.12) {
        var game = GameRules(board: board)
        game.angle = angle
        game.launch()
        for _ in 0..<2200 {
          game.step(1.0 / 120)
          XCTAssertTrue(game.ball.x.isFinite && game.ball.y.isFinite)
          if game.phase != .flying { break }
        }
        XCTAssertNotEqual(game.phase, .flying, "\(board.name), \(angle)")
      }
    }
  }

  func testEveryBoardCanBeClearedUnderNormalRules() {
    for board in Board.all {
      var game = GameRules(board: board)
      var shots = 0
      while game.phase == .aiming && shots < 25 {
        var best: GameRules?
        var bestValue = -Double.infinity
        for angle in stride(from: -1.2, through: 1.2, by: 0.04) {
          var trial = game
          trial.angle = angle
          trial.launch()
          for _ in 0..<2200 {
            trial.step(1.0 / 120)
            if trial.phase != .flying { break }
          }
          let value =
            Double(game.remainingGold - trial.remainingGold) * 10000 + Double(trial.balls) * 200
            + Double(trial.score - game.score)
          if value > bestValue {
            bestValue = value
            best = trial
          }
        }
        guard let result = best else {
          XCTFail("No shot")
          break
        }
        game = result
        shots += 1
      }
      XCTAssertEqual(
        game.phase, .won,
        "\(board.name) still has \(game.remainingGold) targets after \(shots) shots")
    }
  }
}
