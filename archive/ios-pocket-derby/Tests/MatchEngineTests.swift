@testable import PocketDerby
import XCTest

final class MatchEngineTests: XCTestCase {
    private func playing() -> MatchEngine {
        var game = MatchEngine()
        game.start()
        for _ in 0 ..< 270 {
            game.step(1.0 / 120)
        }
        return game
    }

    func testSteeringPreservesHeadingAndMomentum() {
        var game = playing()
        game.opponent.position = Vector(x: 400, y: 140)
        game.steering = Vector(x: 0, y: 1)
        game.step(1.0 / 120)
        XCTAssertGreaterThan(game.player.heading, 0)
        XCTAssertLessThan(game.player.heading, 0.1)
        for _ in 0 ..< 90 {
            game.step(1.0 / 120)
        }
        XCTAssertGreaterThan(game.player.position.y, 30)
        game.steering = .zero
        let before = game.player.position
        game.step(1.0 / 120)
        XCTAssertGreaterThan((game.player.position - before).length, 0)
    }

    func testGoalRequiresBallToCrossInsideOpeningAndResetsOnce() {
        var game = playing()
        game.ball = Vector(x: 473, y: 0)
        game.ballVelocity = Vector(x: 240, y: 0)
        game.step(1.0 / 120)
        XCTAssertEqual(game.playerGoals, 1)
        XCTAssertEqual(game.phase, .goal)
        for _ in 0 ..< 500 {
            game.step(1.0 / 120)
        }
        XCTAssertEqual(game.playerGoals, 1)
        XCTAssertEqual(game.phase, .playing)
        XCTAssertLessThan(abs(game.ball.x), 100)
    }

    func testBallOutsideGoalBouncesOffEndWall() {
        var game = playing()
        game.ball = Vector(x: 420, y: 120)
        game.ballVelocity = Vector(x: 250, y: 0)
        for _ in 0 ..< 8 {
            game.step(1.0 / 120)
        }
        XCTAssertEqual(game.playerGoals, 0)
        XCTAssertLessThan(game.ballVelocity.x, 0)
    }

    func testCarTransfersMomentumToBall() {
        var game = playing()
        game.player.position = Vector(x: -39, y: 0)
        game.player.velocity = Vector(x: 200, y: 0)
        game.steering = Vector(x: 1, y: 0)
        game.step(1.0 / 120)
        XCTAssertGreaterThan(game.ballVelocity.x, 240)
        XCTAssertGreaterThan(game.impactSerial, 0)
    }

    func testPauseFreezesClockPhysicsAndBoost() {
        var game = playing()
        game.paused = true
        let remaining = game.remaining
        let car = game.player
        game.steering = Vector(x: 1, y: 0)
        game.burst()
        for _ in 0 ..< 300 {
            game.step(1.0 / 120)
        }
        XCTAssertEqual(game.remaining, remaining)
        XCTAssertEqual(game.player.position, car.position)
        XCTAssertEqual(game.player.boost, car.boost)
    }

    func testBoostDepletesAndRechargesWithoutExceedingBounds() {
        var game = playing()
        game.steering = Vector(x: 0, y: 1)
        game.burst()
        for _ in 0 ..< 90 {
            game.step(1.0 / 120)
        }
        XCTAssertLessThan(game.player.boost, 0.8)
        game.clearInput()
        for _ in 0 ..< 650 {
            game.step(1.0 / 120)
        }
        XCTAssertLessThanOrEqual(game.player.boost, 1)
        XCTAssertGreaterThanOrEqual(game.player.boost, 0)
    }

    func testClockEndsMatchAndCannotScoreAfterFullTime() {
        var game = playing()
        game.remaining = 0.005
        game.ball = Vector(x: 473, y: 0)
        game.ballVelocity = Vector(x: 300, y: 0)
        game.step(1.0 / 120)
        XCTAssertEqual(game.phase, .finished)
        XCTAssertEqual(game.playerGoals, 0)
        XCTAssertEqual(game.remaining, 0)
    }

    func testOpponentActivelyContestsBall() {
        var game = playing()
        let start = game.opponent.position
        for _ in 0 ..< 180 {
            game.step(1.0 / 120)
        }
        XCTAssertGreaterThan((game.opponent.position - start).length, 90)
        XCTAssertTrue(game.ball.x < 0 || game.ballVelocity.x < 0)
    }

    func testRecordRoundTripKeepsBestAndLastResult() throws {
        var record = MatchRecord()
        record.record(blue: 1, orange: 4)
        XCTAssertEqual(record.bestDifference, -3)
        record.record(blue: 4, orange: 1)
        record.record(blue: 0, orange: 0)
        let decoded = try JSONDecoder().decode(MatchRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(decoded.bestDifference, 3)
        XCTAssertEqual(decoded.wins, 1)
        XCTAssertEqual(decoded.played, 3)
        XCTAssertEqual(decoded.lastBlue, 0)
    }

    func testRoundedCornerDeflectsBallBackIntoPlay() {
        var game = playing()
        game.player.position = Vector(x: -200, y: -100)
        game.opponent.position = Vector(x: 100, y: -100)
        game.ball = Vector(x: 408, y: 140)
        game.ballVelocity = Vector(x: 230, y: 200)
        for _ in 0 ..< 12 {
            game.step(1.0 / 120)
        }
        XCTAssertLessThan(game.ballVelocity.x, 0)
        XCTAssertLessThan(game.ballVelocity.y, 0)
        XCTAssertEqual(game.playerGoals + game.opponentGoals, 0)
    }

    func testCPUEscapesPinnedCornerWithoutResettingBall() {
        var game = playing()
        game.ball = Vector(x: 421, y: 157)
        game.opponent.position = Vector(x: 415, y: 118)
        game.opponent.heading = .pi / 2
        var leftCorner = false
        for _ in 0 ..< 1440 {
            game.step(1.0 / 120)
            if game.ball.x < 335 || game.ball.y < 80 {
                leftCorner = true
            }
        }
        XCTAssertTrue(leftCorner, "CPU must reapproach and release a pinned corner ball")
    }

    func testBrakeClearsTargetAndDissipatesMomentum() {
        var game = playing()
        game.player.velocity = Vector(x: 210, y: 0)
        game.driveTarget = Vector(x: 300, y: 0)
        game.brake()
        for _ in 0 ..< 60 {
            game.step(1.0 / 120)
        }
        XCTAssertNil(game.driveTarget)
        XCTAssertLessThan(game.player.velocity.length, 2)
        XCTAssertLessThan(game.player.position.x, -200)
    }
}
