import XCTest

@testable import VelvetRally

final class GameEngineTests: XCTestCase {
  func testServePauseAndResumePreservePhysics() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    _ = game.tick(delta: 1.0 / 60)
    game.pause()
    let ball = game.ball
    for _ in 0..<120 { XCTAssertEqual(game.tick(delta: 1.0 / 60), .none) }
    XCTAssertEqual(game.ball, ball)
    game.movePlayer(to: 0.1)
    XCTAssertEqual(game.playerX, 0.5)
    game.resume()
    _ = game.tick(delta: 1.0 / 60)
    XCTAssertNotEqual(game.ball, ball)
  }

  func testSideWallReflectsInward() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    game.ball = BallPoint(x: 0.02, y: 0.5)
    game.velocity = BallPoint(x: -0.6, y: 0.2)
    XCTAssertEqual(game.tick(delta: 1.0 / 30), .wall)
    XCTAssertGreaterThan(game.velocity.x, 0)
    XCTAssertGreaterThanOrEqual(game.ball.x, GameEngine.radius)
  }

  func testSweptPaddleCollisionReturnsBallAndCountsRally() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    game.ball = BallPoint(x: 0.53, y: 0.84)
    game.velocity = BallPoint(x: 0, y: 1.1)
    XCTAssertEqual(game.tick(delta: 1.0 / 30), .paddle)
    XCTAssertLessThan(game.velocity.y, 0)
    XCTAssertGreaterThan(game.velocity.x, 0)
    XCTAssertEqual(game.returns, 1)
    XCTAssertEqual(game.bestRally, 1)
  }

  func testPaddleMissAwardsExactlyOnePoint() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    game.ball = BallPoint(x: 0.9, y: 1.04)
    game.velocity = BallPoint(x: 0, y: 1)
    XCTAssertEqual(game.tick(delta: 1.0 / 30), .opponentPoint)
    for _ in 0..<100 { _ = game.tick(delta: 1.0 / 60) }
    XCTAssertEqual(game.opponentScore, 1)
    XCTAssertEqual(game.phase, .point)
  }

  func testClassicAndSprintFinishAtTargetAndCannotContinue() {
    for target in [3, 7] {
      var settings = MatchSettings()
      settings.target = target
      var game = GameEngine(settings: settings)
      for score in 1...target {
        game.serve()
        game.ball = BallPoint(x: 0.1, y: -0.04)
        game.velocity = BallPoint(x: 0, y: -1)
        XCTAssertEqual(game.tick(delta: 1.0 / 30), .playerPoint)
        XCTAssertEqual(game.playerScore, score)
      }
      XCTAssertEqual(game.phase, .finished)
      game.serve()
      XCTAssertEqual(game.phase, .finished)
      XCTAssertTrue(game.record().won)
    }
  }

  func testDifficultyBoundsAndInvalidInputs() {
    XCTAssertLessThan(Difficulty.easy.aiSpeed, Difficulty.club.aiSpeed)
    XCTAssertLessThan(Difficulty.club.aiSpeed, Difficulty.pro.aiSpeed)
    XCTAssertGreaterThan(Difficulty.easy.paddleWidth, Difficulty.pro.paddleWidth)
    for difficulty in Difficulty.allCases {
      var settings = MatchSettings()
      settings.difficulty = difficulty
      settings.target = -1
      var game = GameEngine(settings: settings)
      XCTAssertEqual(game.target, 7)
      game.movePlayer(to: -20)
      XCTAssertEqual(game.playerX, game.paddleWidth / 2)
      game.movePlayer(to: 20)
      XCTAssertEqual(game.playerX, 1 - game.paddleWidth / 2)
      game.movePlayer(to: .nan)
      XCTAssertTrue(game.playerX.isFinite)
      game.serve()
      let ball = game.ball
      _ = game.tick(delta: .infinity)
      _ = game.tick(delta: -1)
      XCTAssertEqual(game.ball, ball)
      _ = game.tick(delta: 300)
      XCTAssertLessThan(abs(game.ball.y - ball.y), 0.04)
    }
  }

  func testOpponentSpeedIsBoundedAndNotTeleporting() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    game.ball = BallPoint(x: 0.9, y: 0.5)
    let before = game.opponentX
    _ = game.tick(delta: 1.0 / 60)
    XCTAssertLessThanOrEqual(abs(game.opponentX - before), Difficulty.easy.aiSpeed / 60 + 0.0001)
  }

  func testOpponentCollisionAndLongRallySpeedCap() {
    var game = GameEngine(settings: MatchSettings())
    game.serve()
    for _ in 0..<100 {
      game.ball = BallPoint(x: game.opponentX, y: 0.15)
      game.velocity = BallPoint(x: 0, y: -1.1)
      XCTAssertEqual(game.tick(delta: 1.0 / 30), .paddle)
      XCTAssertGreaterThan(game.velocity.y, 0)
      XCTAssertLessThanOrEqual(hypot(game.velocity.x, game.velocity.y), 1.12 + 0.0001)
    }
    XCTAssertEqual(game.bestRally, 100)
    XCTAssertEqual(game.playerScore, 0)
    XCTAssertEqual(game.opponentScore, 0)
  }

  @MainActor
  func testSessionSavesOneCompletionAndResetStartsFresh() throws {
    let suite = "VelvetRallyTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RallyStore(defaults: defaults)
    var settings = MatchSettings()
    settings.target = 3
    settings.haptics = false
    let session = MatchSession(settings: settings)
    session.advance(at: 0, store: store)
    for point in 1...3 {
      session.engine.serve()
      session.engine.ball = BallPoint(x: 0.1, y: 1.04)
      session.engine.velocity = BallPoint(x: 0, y: 1)
      session.advance(at: Double(point) / 60, store: store)
    }
    XCTAssertEqual(session.engine.phase, .finished)
    for tick in 4...120 { session.advance(at: Double(tick) / 60, store: store) }
    XCTAssertEqual(store.records.count, 1)
    XCTAssertEqual(store.records.first?.opponentScore, 3)
    XCTAssertEqual(store.records.first?.won, false)
    session.reset()
    XCTAssertEqual(session.engine.phase, .ready)
    XCTAssertEqual(session.engine.playerScore, 0)
    XCTAssertEqual(session.engine.opponentScore, 0)
    session.advance(at: 3, store: store)
    XCTAssertEqual(store.records.count, 1)
  }

  @MainActor
  func testPersistenceSettingsRecordsAndClear() throws {
    let suite = "VelvetRallyTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RallyStore(defaults: defaults)
    store.settings.court = .clay
    store.settings.target = 3
    let record = MatchRecord(
      id: UUID(), date: Date(), playerScore: 3, opponentScore: 1,
      bestRally: 8, returns: 6, difficulty: .club, court: .clay, target: 3)
    store.add(record)
    store.add(record)
    let restored = RallyStore(defaults: defaults)
    XCTAssertEqual(restored.settings.court, .clay)
    XCTAssertEqual(restored.settings.target, 3)
    XCTAssertEqual(restored.records.count, 1)
    XCTAssertEqual(restored.records.first?.bestRally, 8)
    restored.clearRecords()
    XCTAssertTrue(RallyStore(defaults: defaults).records.isEmpty)
  }
}
