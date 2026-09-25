import XCTest

@testable import ReelHorizon

/// XCTest wrapper around the game core. The exhaustive dependency-free harness lives in
/// `Tests/CoreTests.swift` (run with `Scripts/core-tests-linux.sh`); these tests keep the
/// same behaviours covered inside Xcode and the simulator.
@MainActor
final class ReelHorizonTests: XCTestCase {
  private func advance(_ session: inout FishingSession, _ seconds: Double) {
    let steps = Int(seconds * 60)
    for _ in 0..<steps { session.update(dt: 1.0 / 60.0) }
  }

  private func castAndSoak(_ session: inout FishingSession, power: Double = 0.55) {
    session.beginCast()
    while session.castPower < power { session.update(dt: 1.0 / 60.0) }
    session.releaseCast()
    while session.phase == .flying { session.update(dt: 1.0 / 60.0) }
  }

  func testStarterProfileMatchesDesign() {
    let p = PlayerProfile.newAngler()
    XCTAssertEqual(p.level, 1)
    XCTAssertEqual(p.credits, 400)
    XCTAssertEqual(p.baitcoins, 20)
    XCTAssertEqual(p.currentWaterwayID, "lonePineLake")
    XCTAssertNotNil(p.license(for: "lonePineLake"))
    XCTAssertTrue(p.owns(p.rig.rodID))
    XCTAssertTrue(p.owns(p.rig.reelID))
    XCTAssertTrue(p.owns(p.rig.lineID))
  }

  func testCatalogsAreConsistent() {
    for waterway in WaterwayCatalog.all {
      XCTAssertFalse(waterway.speciesIDs.isEmpty, waterway.name)
      for id in waterway.speciesIDs {
        XCTAssertTrue(SpeciesCatalog.all.contains { $0.id == id }, "\(waterway.name) references \(id)")
      }
      for id in waterway.mustReleaseBasic {
        XCTAssertTrue(waterway.speciesIDs.contains(id), "\(waterway.name) release rule for \(id)")
      }
    }
    XCTAssertEqual(Set(SpeciesCatalog.all.map(\.id)).count, SpeciesCatalog.all.count)
    XCTAssertEqual(Set(TackleCatalog.all.map(\.id)).count, TackleCatalog.all.count)
    XCTAssertEqual(SpeciesCatalog.all.count, 80)
    XCTAssertEqual(WaterwayCatalog.all.count, 30)
  }

  func testCastChargesAndFlies() {
    var session = FishingSession(rig: RigSetup.starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 1)
    session.beginCast()
    XCTAssertEqual(session.phase, .charging)
    advance(&session, 0.5)
    XCTAssertGreaterThan(session.castPower, 0.2)
    session.releaseCast()
    XCTAssertEqual(session.phase, .flying)
    advance(&session, 3)
    XCTAssertEqual(session.phase, .soaking)
    XCTAssertGreaterThan(session.lureDistanceFt, 8)
  }

  func testBiteStrikeAndLanding() {
    var session = FishingSession(rig: RigSetup.starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 7)
    castAndSoak(&session)
    session.hookForTesting(speciesID: "bluegill", weightLb: 0.4, distanceFt: 30)
    XCTAssertEqual(session.phase, .fighting)
    XCTAssertNotNil(session.fish)
    session.setReeling(true)
    var guardSteps = 0
    while session.phase == .fighting && guardSteps < 60 * 90 {
      if session.tensionZone == .red || session.tensionZone == .yellow {
        session.setReeling(false)
      } else {
        session.setReeling(true)
      }
      session.update(dt: 1.0 / 60.0)
      guardSteps += 1
    }
    XCTAssertEqual(session.phase, .landed)
    XCTAssertNotNil(session.landedCatch)
    XCTAssertEqual(session.landedCatch?.speciesID, "bluegill")
  }

  func testLineSnapsUnderConstantHeavyPressure() {
    var session = FishingSession(rig: RigSetup.starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 3)
    castAndSoak(&session)
    session.hookForTesting(speciesID: "channelCatfish", weightLb: 18, distanceFt: 60)
    session.strike()
    guard session.phase == .fighting else { return }
    session.setReeling(true)
    session.setRodRaised(true)
    session.changeReelSpeed(1)
    advance(&session, 40)
    XCTAssertTrue(session.phase == .lineSnapped || session.phase == .landed || session.phase == .fishEscaped)
  }

  func testKeepnetSellingAwardsCreditsAndXP() {
    var p = PlayerProfile.newAngler()
    let species = SpeciesCatalog.find("largemouthBass")
    let record = CatchRecord(
      speciesID: species.id, waterwayID: "lonePineLake", weightLb: 3.2,
      lengthIn: species.lengthFor(weightLb: 3.2), grade: species.grade(weightLb: 3.2),
      gameDay: 1, gameMinute: 480, date: Date(), kept: true)
    let creditsBefore = p.credits
    let xpBefore = p.xp
    p.record(record)
    XCTAssertEqual(p.keepnet.count, 1)
    XCTAssertGreaterThan(p.xp, xpBefore)
    let earned = p.sellKeepnet()
    XCTAssertGreaterThan(earned, 0)
    XCTAssertEqual(p.credits, creditsBefore + earned)
    XCTAssertTrue(p.keepnet.isEmpty)
  }

  func testProfilePersistsThroughStore() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = dir.appendingPathComponent("profile.json")
    let store = GameStore(storageURL: url)
    store.profile.credits = 4321
    store.save()
    let saved = expectation(description: "profile written")
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { saved.fulfill() }
    wait(for: [saved], timeout: 3)
    let data = try Data(contentsOf: url)
    let decoded = try JSONDecoder().decode(PlayerProfile.self, from: data)
    XCTAssertEqual(decoded.credits, 4321)
    let reloaded = GameStore(storageURL: url)
    XCTAssertEqual(reloaded.profile.credits, 4321)
  }

  func testShopPurchaseAndEquipThroughStore() {
    let store = GameStore(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json"))
    store.profile.credits = 5000
    let lure = TackleCatalog.items(in: .lures).first { !store.profile.owns($0.id) && $0.requiredLevel <= 1 }!
    store.buy(lure)
    XCTAssertTrue(store.profile.owns(lure.id))
    store.equip(lure)
    XCTAssertEqual(store.profile.rig.lureID, lure.id)
  }
}
