@testable import OtterRules
import XCTest

final class FlapRulesTests: XCTestCase {
    private func world(seed: UInt64 = 7) -> FlapWorld {
        FlapWorld(width: 390, height: 844, seed: seed)
    }

    func testReadyWorldHoversUntilFirstFlap() {
        var world = world()
        let start = world.otterY
        XCTAssertTrue(world.step(1).isEmpty)
        XCTAssertEqual(world.otterY, start)
        XCTAssertEqual(world.phase, .ready)
        XCTAssertTrue(world.logs.isEmpty)
        XCTAssertTrue(world.flap())
        XCTAssertEqual(world.phase, .playing)
        XCTAssertFalse(world.logs.isEmpty)
        XCTAssertGreaterThan(world.logs[0].x, world.width)
    }

    func testFlapRisesThenGravityPullsDown() {
        var world = world()
        world.flap()
        let start = world.otterY
        _ = world.step(0.1)
        XCTAssertGreaterThan(world.otterY, start)
        for _ in 0 ..< 30 {
            _ = world.step(1.0 / 60)
        }
        XCTAssertLessThan(world.velocity, 0)
        XCTAssertGreaterThanOrEqual(world.velocity, -world.config.maxFallSpeed)
    }

    func testHittingGroundEndsRun() {
        var world = world()
        world.flap()
        var events: [FlapEvent] = []
        for _ in 0 ..< 600 where world.phase != .over {
            events += world.step(1.0 / 120)
        }
        XCTAssertEqual(world.phase, .over)
        XCTAssertEqual(world.otterY, world.restingY)
        XCTAssertTrue(events.contains(.crashed))
        XCTAssertTrue(events.contains(.landed))
        XCTAssertFalse(world.flap())
    }

    func testPassingLogScoresOnce() {
        var world = world()
        world.flap()
        world.replaceLogs([Log(x: world.otterX + 10, gapCenter: world.otterY, gapHeight: 400)])
        var scores: [FlapEvent] = []
        for _ in 0 ..< 60 {
            world.place(otterY: world.logs[0].gapCenter)
            scores += world.step(1.0 / 60).filter {
                if case .scored = $0 {
                    true
                } else {
                    false
                }
            }
        }
        XCTAssertEqual(scores, [.scored(1)])
        XCTAssertEqual(world.score, 1)
    }

    func testLogCollisionStartsFall() {
        var world = world()
        world.flap()
        world.replaceLogs([Log(x: world.otterX, gapCenter: world.otterY + 300, gapHeight: 180)])
        let events = world.step(1.0 / 120)
        XCTAssertTrue(events.contains(.crashed))
        XCTAssertEqual(world.phase, .falling)
        XCTAssertFalse(world.flap())
    }

    func testCeilingClampsWithoutCrash() {
        var world = world()
        world.flap()
        world.replaceLogs([])
        world.place(otterY: world.height - 5, velocity: 900)
        let events = world.step(1.0 / 60)
        XCTAssertFalse(events.contains(.crashed))
        XCTAssertEqual(world.otterY, world.height - world.config.otterRadius)
    }

    func testGeneratedGapsStayFairAndOnScreen() {
        for seed in 1 ... 40 as ClosedRange<UInt64> {
            var world = world(seed: seed)
            world.flap()
            var previous: Double?
            for _ in 0 ..< 2400 {
                world.place(otterY: world.logs.first { !$0.scored }?.gapCenter ?? world.otterY)
                _ = world.step(1.0 / 60)
                for log in world.logs {
                    XCTAssertGreaterThan(log.gapBottom, world.config.groundHeight)
                    XCTAssertLessThan(log.gapTop, world.height - world.config.ceilingMargin + 0.001)
                    XCTAssertGreaterThanOrEqual(log.gapHeight, world.config.minimumGapHeight)
                }
                if let last = world.logs.last?.gapCenter, last != previous {
                    if let previous {
                        XCTAssertLessThanOrEqual(abs(last - previous), world.config.maxGapShift + 0.001)
                    }
                    previous = last
                }
            }
            XCTAssertEqual(world.phase, .playing, "seed \(seed) should be survivable by a perfect pilot")
            XCTAssertGreaterThan(world.score, 20)
        }
    }

    func testSameSeedProducesSameCourse() {
        var a = world(seed: 99), b = world(seed: 99)
        a.flap()
        b.flap()
        XCTAssertEqual(a.logs, b.logs)
    }

    func testMedalThresholds() {
        XCTAssertNil(Medal.award(for: 4))
        XCTAssertEqual(Medal.award(for: 5), .pebble)
        XCTAssertEqual(Medal.award(for: 10), .shell)
        XCTAssertEqual(Medal.award(for: 25), .pearl)
        XCTAssertEqual(Medal.award(for: 40), .golden)
    }
}
