import XCTest

@testable import LucidLanes

final class RulesTests: XCTestCase {
    func testPerfectThreeFrameGameHasTwoBonusRollsAndNinetyPoints() {
        var game = BowlingGame()
        for _ in 0..<4 { game.roll(10) }
        XCTAssertFalse(game.isComplete)
        game.roll(10)
        XCTAssertTrue(game.isComplete)
        XCTAssertEqual(game.score, 90)
        XCTAssertEqual(game.frames, [[10], [10], [10, 10, 10]])
        game.roll(5)
        XCTAssertEqual(game.score, 90)
    }

    func testSpareBonusAndOpenFrames() {
        var game = BowlingGame()
        for pins in [7, 3, 4, 2, 6, 1] { game.roll(pins) }
        XCTAssertEqual(game.score, 27)
        XCTAssertTrue(game.isComplete)
        XCTAssertEqual(game.symbols(for: 0), "7  /")
    }

    func testFinalSpareResetsRackAndAwardsOneBonus() {
        var game = BowlingGame()
        for pins in [0, 0, 0, 0, 8, 2] { game.roll(pins) }
        XCTAssertFalse(game.isComplete)
        XCTAssertTrue(game.needsFreshRack)
        game.roll(7)
        XCTAssertTrue(game.isComplete)
        XCTAssertEqual(game.score, 17)
    }

    func testFinalStrikeThenPartialBonusKeepsRemainingPins() {
        var game = BowlingGame()
        for pins in [0, 0, 0, 0, 10] { game.roll(pins) }
        XCTAssertTrue(game.needsFreshRack)
        game.roll(7)
        XCTAssertFalse(game.needsFreshRack)
        game.roll(3)
        XCTAssertEqual(game.score, 20)
        XCTAssertEqual(game.symbols(for: 2), "X  7  /")
    }

    func testFreshBonusRackCannotBeMarkedAsAnotherSpare() {
        for (rolls, symbols) in [([7, 3, 7], "7  /  7"), ([5, 5, 5], "5  /  5"), ([0, 10, 10], "–  /  X")] {
            var game = BowlingGame()
            for pins in [0, 0, 0, 0] + rolls { game.roll(pins) }
            XCTAssertTrue(game.isComplete)
            XCTAssertEqual(game.symbols(for: 2), symbols)
            XCTAssertEqual(game.score, rolls.reduce(0, +))
        }
    }

    func testRollsAreClampedToStandingPins() {
        var game = BowlingGame()
        game.roll(-3)
        game.roll(15)
        XCTAssertEqual(game.frames[0], [0, 10])
        game.roll(8)
        game.roll(9)
        XCTAssertEqual(game.frames[1], [8, 2])
    }

    func testBonusGuidanceMatchesEarnedDelivery() {
        var game = BowlingGame()
        for pins in [10, 10, 10] { game.roll(pins) }
        XCTAssertEqual(game.nextRollCaption, "Bonus roll 1 of 2")
        game.roll(10)
        XCTAssertEqual(game.nextRollCaption, "Bonus roll 2 of 2")
        var spare = BowlingGame()
        for pins in [0, 0, 0, 0, 4, 6] { spare.roll(pins) }
        XCTAssertEqual(spare.nextRollCaption, "One bonus dream")
    }

    func testMovingGateHasStableBoundedOpening() {
        let gate = Gate(y: 4, center: 0.1, width: 1, amplitude: 0.3, speed: 0.8)
        XCTAssertEqual(gate.opening(at: 0).lowerBound, -0.4, accuracy: 0.0001)
        XCTAssertEqual(gate.opening(at: 11), gate.opening(at: 11))
        for time in stride(from: 0.0, through: 20, by: 0.1) {
            let range = gate.opening(at: time)
            XCTAssertEqual(range.upperBound - range.lowerBound, 1, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(range.lowerBound, -0.7)
            XCTAssertLessThanOrEqual(range.upperBound, 0.9)
        }
    }

    func testStraightShotIsAchievableAndDeterministic() {
        let first = simulate(aim: 0, curve: 0, lane: Lane.all[0])
        let second = simulate(aim: 0, curve: 0, lane: Lane.all[0])
        XCTAssertGreaterThanOrEqual(first.pins.filter(\.down).count, 7)
        XCTAssertEqual(first.pins.filter(\.down).count, second.pins.filter(\.down).count)
        XCTAssertFalse(first.gutter)
        XCTAssertFalse(first.ball.active)
    }

    func testCurveChangesPathAndBumpersPreventGutters() {
        var left = BowlingPhysics()
        var right = BowlingPhysics()
        left.launch(aim: 0, power: 0.6, curve: -1)
        right.launch(aim: 0, power: 0.6, curve: 1)
        for step in 0..<60 {
            left.step(dt: 1.0 / 120, lane: Lane.all[0], time: Double(step) / 120)
            right.step(dt: 1.0 / 120, lane: Lane.all[0], time: Double(step) / 120)
        }
        XCTAssertLessThan(left.ball.x, 0)
        XCTAssertGreaterThan(right.ball.x, 0)
        XCTAssertEqual(left.ball.x, -right.ball.x, accuracy: 0.0001)
        XCTAssertFalse(simulate(aim: 1, curve: 1, lane: Lane.all[0]).gutter)
        XCTAssertTrue(simulate(aim: 1, curve: 1, lane: Lane.all[5]).gutter)
    }

    func testClosedArchitectureRejectsBall() {
        let blocked = Lane(
            id: 9, name: "Test", subtitle: "", advice: "",
            gates: [Gate(y: 3, center: 0.7, width: 0.3)],
            bumper: true, bronze: 10, silver: 20, gold: 30)
        let physics = simulate(aim: 0, curve: 0, lane: blocked)
        XCTAssertTrue(physics.hitGate)
        XCTAssertEqual(physics.pins.filter(\.down).count, 0)
    }

    func testAllEightMedalsHaveOrderedAchievableThresholds() {
        XCTAssertEqual(Set(Lane.all.map(\.id)).count, 8)
        for lane in Lane.all {
            XCTAssertLessThan(lane.bronze, lane.silver)
            XCTAssertLessThan(lane.silver, lane.gold)
            XCTAssertLessThanOrEqual(lane.gold, 90)
            XCTAssertEqual(lane.medal(score: lane.bronze), "BRONZE")
            XCTAssertEqual(lane.medal(score: 0), "NO MEDAL")
        }
    }

    private func simulate(aim: Double, curve: Double, lane: Lane) -> BowlingPhysics {
        var physics = BowlingPhysics()
        physics.launch(aim: aim, power: 0.65, curve: curve)
        for step in 0..<720 {
            physics.step(dt: 1.0 / 120, lane: lane, time: Double(step) / 120)
        }
        return physics
    }

    func testEveryCorridorHasANinePinOrBetterRoute() {
        for lane in Lane.all {
            var best = 0
            search: for delay in [0.0, 2.0, 4.0] {
                for aim in stride(from: -0.8, through: 0.8, by: 0.1) {
                    for curve in stride(from: -1.0, through: 1.0, by: 0.2) {
                        var physics = BowlingPhysics()
                        physics.launch(aim: aim, power: 0.65, curve: curve)
                        for step in 0..<510 {
                            physics.step(dt: 1.0 / 120, lane: lane, time: delay + Double(step) / 120)
                        }
                        best = max(best, physics.pins.filter(\.down).count)
                        if best >= 9 {
                            print("Room \(lane.id + 1): aim \(aim), curve \(curve), delay \(delay), pins \(best)")
                            break search
                        }
                    }
                }
            }
            XCTAssertGreaterThanOrEqual(best, 9, "No strong route through \(lane.name)")
        }
    }
}
