import XCTest

@testable import Mossball

final class GolfTests: XCTestCase {
    private func emptyHole(tee: Vector = Vector(x: 180, y: 400), cup: Vector = Vector(x: 290, y: 110)) -> Hole {
        Hole(number: 1, name: "Test", subtitle: "", par: 2, tee: tee, cup: cup)
    }

    private func settle(_ simulation: inout GolfSimulation) -> [GolfEvent] {
        var events: [GolfEvent] = []
        for _ in 0..<600 {
            events.append(simulation.tick(1.0 / 60))
            if !simulation.moving { break }
        }
        return events
    }

    func testFrictionStopsAtPredictedDistance() {
        var simulation = GolfSimulation(hole: emptyHole())
        simulation.shoot(pull: Vector(x: 0, y: -60))
        _ = settle(&simulation)
        XCTAssertEqual(simulation.position.y, 220, accuracy: 3)
        XCTAssertEqual(simulation.strokes, 1)
        XCTAssertFalse(simulation.moving)
    }

    func testPowerCapAndTinyDrag() {
        var small = GolfSimulation(hole: emptyHole())
        small.shoot(pull: Vector(x: 1, y: 1))
        XCTAssertEqual(small.strokes, 0)
        var large = small
        var capped = small
        large.shoot(pull: Vector(x: 0, y: -500))
        capped.shoot(pull: Vector(x: 0, y: -135))
        XCTAssertEqual(large.velocity, capped.velocity)
    }

    func testCannotShootWhileMovingOrAfterSink() {
        var simulation = GolfSimulation(hole: Hole.course[0])
        simulation.shoot(pull: Vector(x: 0, y: -83))
        simulation.shoot(pull: Vector(x: 60, y: 0))
        XCTAssertEqual(simulation.strokes, 1)
        _ = settle(&simulation)
        XCTAssertTrue(simulation.sunk)
        simulation.shoot(pull: Vector(x: 80, y: 0))
        XCTAssertEqual(simulation.strokes, 1)
    }

    func testWallReflectsAndLosesEnergy() {
        var simulation = GolfSimulation(hole: emptyHole(tee: Vector(x: 300, y: 400)))
        simulation.shoot(pull: Vector(x: 80, y: 0))
        let speed = simulation.velocity.length
        let events = settle(&simulation)
        XCTAssertTrue(events.contains(.bounce))
        XCTAssertLessThan(simulation.position.x, 300)
        XCTAssertLessThan(simulation.velocity.length, speed)
        XCTAssertGreaterThanOrEqual(simulation.position.x, 51)
    }

    func testInteriorStonePreventsTunneling() {
        var hole = emptyHole()
        hole.walls = [Stone(x: 100, y: 300, width: 160, height: 12)]
        var simulation = GolfSimulation(hole: hole)
        simulation.shoot(pull: Vector(x: 0, y: -135))
        XCTAssertTrue(settle(&simulation).contains(.bounce))
        XCTAssertGreaterThan(simulation.position.y, 318)
    }

    func testMushroomBankReflects() {
        var hole = emptyHole()
        hole.mushrooms = [Mushroom(center: Vector(x: 180, y: 300), radius: 27)]
        var simulation = GolfSimulation(hole: hole)
        simulation.shoot(pull: Vector(x: 0, y: -75))
        XCTAssertTrue(settle(&simulation).contains(.bounce))
        XCTAssertGreaterThan(simulation.position.y, 333)
    }

    func testPondPenaltyRestoresPreviousLie() {
        var hole = emptyHole()
        hole.water = [Stone(x: 45, y: 250, width: 270, height: 65)]
        var simulation = GolfSimulation(hole: hole)
        simulation.shoot(pull: Vector(x: 0, y: -100))
        XCTAssertTrue(settle(&simulation).contains(.splash))
        XCTAssertEqual(simulation.position, hole.tee)
        XCTAssertEqual(simulation.strokes, 2)
        XCTAssertFalse(simulation.moving)
    }

    func testLilyIsSolidButPondOutsideItIsNot() {
        let hole = Hole.course[3]
        var supported = GolfSimulation(hole: hole)
        supported.position = hole.lilyCenter(at: 0)
        supported.velocity = Vector(x: 0, y: -10)
        XCTAssertNotEqual(supported.tick(1.0 / 60), .splash)
        var unsupported = GolfSimulation(hole: hole)
        unsupported.position = Vector(x: 60, y: 273)
        unsupported.velocity = Vector(x: 0, y: -10)
        XCTAssertEqual(unsupported.tick(1.0 / 60), .splash)
        XCTAssertNotEqual(hole.lilyCenter(at: 0), hole.lilyCenter(at: 2))
    }

    func testMovingGateChangesGeometry() {
        let hole = Hole.course[4]
        XCTAssertNotEqual(hole.gateStone(at: 0).x, hole.gateStone(at: 1).x)
        var simulation = GolfSimulation(hole: hole)
        simulation.position = Vector(x: 170, y: 309)
        simulation.shoot(pull: Vector(x: 0, y: -90))
        XCTAssertTrue(settle(&simulation).contains(.bounce))
    }

    func testFastBallDoesNotFallIntoCup() {
        var simulation = GolfSimulation(hole: emptyHole(cup: Vector(x: 180, y: 380)))
        simulation.shoot(pull: Vector(x: 0, y: -135))
        for _ in 0..<5 { _ = simulation.tick(1.0 / 120) }
        XCTAssertFalse(simulation.sunk)
        XCTAssertGreaterThan(simulation.velocity.length, 310)
    }

    func testPredictionMatchesActualEndpoint() {
        var simulation = GolfSimulation(hole: Hole.course[2])
        let pull = Vector(x: 67, y: -75)
        let predicted = simulation.trajectory(pull: pull)
        simulation.shoot(pull: pull)
        _ = settle(&simulation)
        XCTAssertEqual(predicted.last!.x, simulation.position.x, accuracy: 0.01)
        XCTAssertEqual(predicted.last!.y, simulation.position.y, accuracy: 0.01)
    }

    func testPreviewDistinguishesWaterFromSafeLilyCrossing() {
        var simulation = GolfSimulation(hole: Hole.course[3])
        let safe = simulation.prediction(pull: Vector(x: 0, y: -96.333))
        XCTAssertTrue(safe.sinks)
        XCTAssertFalse(safe.waterHazard)
        simulation.time = 3
        let unsafe = simulation.prediction(pull: Vector(x: 0, y: -96.333))
        XCTAssertTrue(unsafe.waterHazard)
        XCTAssertFalse(unsafe.sinks)
        XCTAssertNotEqual(unsafe.points.last, simulation.hole.tee)
    }

    func testEveryHandcraftedHoleCanBeSunkBelowItsStrokeLimit() {
        let routes: [[Vector]] = [
            [Vector(x: 0, y: -83)],
            [Vector(x: -103.416, y: -86.776), Vector(x: 39.650, y: -16.541)],
            [Vector(x: 103.416, y: -86.776), Vector(x: 9.666, y: -9.543)],
            [Vector(x: 0, y: -96.333)],
            [Vector(x: 103.416, y: -86.776), Vector(x: 9.844, y: -11.987)],
            [Vector(x: -55.667, y: -100.667)],
            [Vector(x: -49.333, y: -99.667)],
            [Vector(x: 103.416, y: -86.776), Vector(x: 0.619, y: -22)],
            [
                Vector(x: 103.923, y: -60), Vector(x: 86.776, y: -103.416),
                Vector(x: -13.673, y: 7.612),
            ],
        ]
        for (hole, route) in zip(Hole.course, routes) {
            var simulation = GolfSimulation(hole: hole)
            for pull in route {
                simulation.shoot(pull: pull)
                _ = settle(&simulation)
            }
            XCTAssertTrue(simulation.sunk, "Hole \(hole.number) must remain solvable")
            XCTAssertLessThan(simulation.strokes, 8)
        }
    }

    func testCourseHasNineDistinctPlayableBoundsAndPar28() {
        XCTAssertEqual(Hole.course.count, 9)
        XCTAssertEqual(Hole.totalPar, 28)
        XCTAssertEqual(Set(Hole.course.map(\.name)).count, 9)
        for hole in Hole.course {
            for point in [hole.tee, hole.cup] {
                XCTAssertTrue((51...309).contains(point.x))
                XCTAssertTrue((89...469).contains(point.y))
                XCTAssertFalse(hole.water.contains { $0.contains(point) })
                XCTAssertFalse(hole.walls.contains { $0.contains(point) })
            }
        }
    }

    func testRecordRequiresEveryCupForBestEligibility() {
        let full = CourseRecord(strokes: Array(repeating: 3, count: 9), completed: Array(repeating: true, count: 9))
        XCTAssertTrue(full.finished)
        XCTAssertEqual(full.total, 27)
        XCTAssertEqual(full.caption, "1 under par")
        let incomplete = CourseRecord(strokes: [2, 8], completed: [true, false])
        XCTAssertFalse(incomplete.finished)
        XCTAssertEqual(try JSONDecoder().decode(CourseRecord.self, from: JSONEncoder().encode(full)), full)
    }
}

@MainActor
final class GameStoreTests: XCTestCase {
    private func store() -> (GameStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "mossball.tests.\(UUID().uuidString)")!
        return (GameStore(defaults: defaults), defaults)
    }

    func testPracticeDoesNotSetCourseBest() {
        let (game, defaults) = store()
        game.start(practice: 0)
        game.dismissTutorial()
        game.shoot(Vector(x: 0, y: -83))
        for _ in 0..<400 { game.tick() }
        XCTAssertEqual(game.screen, .holeResult)
        XCTAssertTrue(game.simulation.sunk)
        game.nextHole()
        XCTAssertNil(defaults.object(forKey: "moss.best"))
        XCTAssertTrue(game.practice)
        XCTAssertEqual(game.simulation.strokes, 0)
    }

    func testPauseFreezesBallAndMechanisms() {
        let (game, _) = store()
        game.start(practice: 4)
        game.dismissTutorial()
        game.shoot(Vector(x: 20, y: -80))
        game.paused = true
        let position = game.simulation.position
        let time = game.simulation.time
        for _ in 0..<100 { game.tick() }
        XCTAssertEqual(game.simulation.position, position)
        XCTAssertEqual(game.simulation.time, time)
        game.paused = false
        game.tick()
        XCTAssertNotEqual(game.simulation.position, position)
    }

    func testEighthUnsuccessfulStrokeProducesFailureAndNextHole() {
        let (game, _) = store()
        game.start()
        game.dismissTutorial()
        game.simulation.strokes = 8
        for _ in 0..<100 { game.tick() }
        XCTAssertEqual(game.screen, .holeResult)
        XCTAssertFalse(game.simulation.sunk)
        game.nextHole()
        XCTAssertEqual(game.scores, [8])
        XCTAssertEqual(game.completed, [false])
        XCTAssertEqual(game.holeIndex, 1)
    }

    func testFullCourseBestAndSettingsSurviveRelaunch() {
        let (game, defaults) = store()
        game.start()
        game.dismissTutorial()
        for _ in 0..<9 {
            game.simulation.strokes = 3
            game.simulation.sunk = true
            game.nextHole()
        }
        game.sound = true
        game.gentle = false
        let restored = GameStore(defaults: defaults)
        XCTAssertEqual(game.screen, .courseResult)
        XCTAssertEqual(restored.best, 27)
        XCTAssertEqual(restored.rounds, 1)
        XCTAssertTrue(restored.sound)
        XCTAssertFalse(restored.gentle)
    }

    func testSharingRendersActualImageForMomentAndCourse() {
        let (game, _) = store()
        game.start(practice: 0)
        game.simulation.sunk = true
        game.simulation.strokes = 1
        let moment = ScorecardRenderer.hole(game: game)
        XCTAssertEqual(moment?.image.size.width, 450)
        XCTAssertEqual(moment?.image.size.height, 800)
        XCTAssertGreaterThan(moment?.image.pngData()?.count ?? 0, 10_000)
        XCTAssertTrue(moment?.text.contains("1 stroke,") ?? false)
        let record = CourseRecord(strokes: Array(repeating: 3, count: 9), completed: Array(repeating: true, count: 9))
        let course = ScorecardRenderer.course(record: record)
        XCTAssertGreaterThan(course?.image.pngData()?.count ?? 0, 10_000)
        XCTAssertTrue(course?.text.contains("27 strokes") ?? false)
    }
}
