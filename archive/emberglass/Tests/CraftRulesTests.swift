import XCTest

@testable import Emberglass

final class CraftRulesTests: XCTestCase {
  func testContourTangentsStaySmoothAtShoulderAndFlatAtExtrema() {
    let radii = Commission.tide.radii
    let tangents = CraftRules.contourTangents(radii)
    XCTAssertEqual(tangents.count, radii.count)
    XCTAssertEqual(tangents[1], 0)
    XCTAssertEqual(tangents[5], 0)
    XCTAssertGreaterThan(tangents[3], 0)
    XCTAssertLessThan(tangents[3], 0.21)
    XCTAssertEqual(CraftRules.contourTangents([]), [])
    XCTAssertEqual(CraftRules.contourTangents([0.5]), [0])
  }

  func testHeatingAndCoolingAreBoundedAndTimeBased() {
    XCTAssertEqual(
      CraftRules.heatStep(temperature: 0.4, holding: true, delta: 1), 0.58, accuracy: 0.001)
    XCTAssertEqual(
      CraftRules.heatStep(temperature: 0.4, holding: false, delta: 1), 0.30, accuracy: 0.001)
    XCTAssertEqual(CraftRules.heatStep(temperature: 0.99, holding: true, delta: 1), 1)
    XCTAssertEqual(CraftRules.heatStep(temperature: 0.01, holding: false, delta: 1), 0)
  }

  func testPrecisionRewardsWindowAndPenalizesDistance() {
    XCTAssertEqual(CraftRules.proximity(0.55, target: 0.5, tolerance: 0.1), 1)
    XCTAssertEqual(CraftRules.proximity(0.75, target: 0.5, tolerance: 0.1), 0.5, accuracy: 0.001)
    XCTAssertEqual(CraftRules.proximity(1, target: 0.4, tolerance: 0.1), 0)
  }

  func testMovingTargetsRemainReachable() {
    let times = stride(from: 0.0, through: 14.0, by: 0.1)
    for time in times {
      XCTAssertTrue((0.38...0.70).contains(CraftRules.heatWindow(at: time)))
      XCTAssertTrue((0.26...0.74).contains(CraftRules.balanceWindow(at: time)))
    }
    XCTAssertNotEqual(CraftRules.heatWindow(at: 0), CraftRules.heatWindow(at: 3))
  }

  func testShapeRequiresCoverageEvenForAnIdenticalProfile() {
    let profile = Commission.tide.radii
    XCTAssertEqual(CraftRules.shapeScore(profile: profile, touched: [], target: profile), 0)
    XCTAssertEqual(
      CraftRules.shapeScore(profile: profile, touched: [0, 1, 2, 3], target: profile), 0.5)
    XCTAssertEqual(CraftRules.shapeScore(profile: profile, touched: Set(0..<8), target: profile), 1)
    XCTAssertEqual(CraftRules.shapeScore(profile: [], touched: [], target: profile), 0)
  }

  func testShapePenalizesInaccurateContours() {
    let target = Commission.tide.radii
    let inaccurate = target.map { $0 - 0.14 }
    XCTAssertEqual(
      CraftRules.shapeScore(profile: inaccurate, touched: Set(0..<8), target: target), 0.5,
      accuracy: 0.001
    )
  }

  func testScoringRequiresMoreThanTwoPassiveStages() {
    XCTAssertEqual(CraftRules.total(heat: 1, spin: 1, shape: 1), 100)
    XCTAssertEqual(CraftRules.total(heat: 0, spin: 0, shape: 0), 0)
    XCTAssertLessThan(CraftRules.total(heat: 0.2, spin: 0.75, shape: 0), 55)
    XCTAssertEqual(CraftRules.grade(score: 54), "STUDY")
    XCTAssertEqual(CraftRules.grade(score: 55), "COLLECTIBLE")
    XCTAssertEqual(CraftRules.grade(score: 75), "EXQUISITE")
    XCTAssertEqual(CraftRules.grade(score: 90), "MASTERWORK")
  }

  func testArchiveUnlocksOnSuccessAndKeepsBestBeyondHistoryLimit() throws {
    var archive = ProgressArchive()
    archive.record(piece(score: 90, commission: .tide))
    XCTAssertEqual(archive.unlocked, 1)
    archive.record(piece(score: 30, commission: .bloom))
    XCTAssertEqual(archive.unlocked, 1)
    archive.record(piece(score: 75, commission: .bloom))
    XCTAssertEqual(archive.unlocked, 2)
    for _ in 0..<30 { archive.record(piece(score: 20, commission: .tide)) }
    XCTAssertEqual(archive.pieces.count, 24)
    XCTAssertEqual(archive.best, 90)
    let encoded = try JSONEncoder().encode(archive)
    let decoded = try JSONDecoder().decode(ProgressArchive.self, from: encoded)
    XCTAssertEqual(decoded.best, 90)
    XCTAssertEqual(decoded.unlocked, 2)
    XCTAssertEqual(decoded.pieces.count, 24)
  }

  @MainActor
  func testPauseTutorialAndRetryState() throws {
    let name = "emberglass.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let studio = Studio(defaults: defaults)
    studio.start()
    studio.tick(delta: 0.1)
    XCTAssertEqual(studio.elapsed, 0)
    studio.dismissTutorial()
    studio.holding = true
    studio.tick(delta: 0.1)
    XCTAssertGreaterThan(studio.temperature, 0.46)
    studio.suspend()
    let time = studio.elapsed
    studio.tick(delta: 0.1)
    XCTAssertEqual(studio.elapsed, time)
    XCTAssertFalse(studio.holding)
    studio.start()
    XCTAssertFalse(studio.paused)
    XCTAssertEqual(studio.elapsed, 0)
    XCTAssertFalse(studio.tutorial)
  }

  @MainActor
  func testCompleteSuccessfulRunPersistsOnce() throws {
    let name = "emberglass.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let studio = Studio(defaults: defaults)
    studio.start()
    studio.dismissTutorial()
    while studio.stage == .heat {
      studio.holding = studio.temperature < studio.heatTarget
      studio.tick(delta: 0.1)
    }
    studio.dismissTutorial()
    while studio.stage == .spin {
      studio.rotation = studio.spinTarget
      studio.tick(delta: 0.1)
    }
    studio.dismissTutorial()
    for index in 0..<8 { studio.trace(index: index, radius: Commission.tide.radii[index]) }
    studio.finish()
    let result = try XCTUnwrap(studio.result)
    XCTAssertGreaterThanOrEqual(result.score, 90)
    XCTAssertEqual(studio.stage, .result)
    studio.finish()
    XCTAssertEqual(studio.archive.pieces.count, 1)
    let restored = Studio(defaults: defaults)
    XCTAssertEqual(restored.archive.best, result.score)
    XCTAssertEqual(restored.archive.unlocked, 1)
    XCTAssertEqual(restored.archive.pieces.first?.id, result.id)
  }

  private func piece(score: Int, commission: Commission) -> GalleryPiece {
    GalleryPiece(
      commission: commission, score: score, heat: 80, spin: 70, shape: 90, profile: commission.radii
    )
  }
}
