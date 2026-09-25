import Foundation

/// Dependency-free test harness so the game rules run on Linux (swiftc) and macOS alike.
struct TestFailure: Error { let message: String }

var passed = 0
var failed = 0
var failures: [String] = []

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
  if condition {
    passed += 1
  } else {
    failed += 1
    failures.append("\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(message)")
  }
}

func ok<E>(_ result: Result<Void, E>) -> Bool {
  if case .success = result { return true }
  return false
}

func err<E>(_ result: Result<Void, E>) -> E? {
  if case .failure(let e) = result { return e }
  return nil
}

func test(_ name: String, _ body: () throws -> Void) {
  let before = failed
  do {
    try body()
  } catch {
    failed += 1
    failures.append("\(name): threw \(error)")
  }
  print(failed == before ? "PASS \(name)" : "FAIL \(name)")
}

/// Reels while the line is comfortable, lets the fish run when it is hot.
func fight(_ session: inout FishingSession, maxSeconds: Double = 240) -> FishingPhase {
  var elapsed = 0.0
  while session.phase == .fighting && elapsed < maxSeconds {
    session.setReeling(session.lineTension < 0.7)
    session.update(dt: 1.0 / 30.0)
    elapsed += 1.0 / 30.0
  }
  return session.phase
}

/// Steps the simulation at 60 Hz for `seconds`.
func advance(_ session: inout FishingSession, _ seconds: Double) {
  var left = seconds
  while left > 0 {
    let dt = min(1.0 / 60.0, left)
    session.update(dt: dt)
    left -= dt
  }
}

func castAndSoak(_ session: inout FishingSession, power: Double = 0.55) {
  session.beginCast()
  advance(&session, power * 1.1)
  session.releaseCast()
  var guardCount = 0
  while session.phase == .flying && guardCount < 400 {
    session.update(dt: 1.0 / 60.0)
    guardCount += 1
  }
}

@main
struct CoreTests {
  static func main() {
    test("leveling thresholds increase and round-trip") {
      var previous = -1
      for level in 1...Leveling.maxLevel {
        let xp = Leveling.xpRequired(forLevel: level)
        check(xp > previous, "xp for level \(level) should grow")
        check(Leveling.level(forXP: xp) == level, "level(forXP:) round trip at \(level)")
        previous = xp
      }
      check(Leveling.level(forXP: 0) == 1, "fresh angler is level 1")
      check(Leveling.progress(forXP: 0) == 0, "no progress at zero xp")
      check(Leveling.progress(forXP: 149) > 0.9, "almost level 2 at 149 xp")
    }

    test("species lengths and grades are consistent") {
      for species in SpeciesCatalog.all {
        let short = species.lengthFor(weightLb: species.minWeightLb)
        let long = species.lengthFor(weightLb: species.maxWeightLb)
        check(abs(short - species.minLengthIn) < 0.001, "\(species.name) min length")
        check(abs(long - species.maxLengthIn) < 0.001, "\(species.name) max length")
        check(
          species.grade(weightLb: species.maxWeightLb) == .unique, "\(species.name) max is unique")
        check(
          species.grade(weightLb: species.trophyWeightLb) == .trophy,
          "\(species.name) trophy threshold")
        check(species.grade(weightLb: species.minWeightLb) == .young, "\(species.name) min is young")
        check(species.activity(atHour: species.peakHours.first ?? 6) == 1, "peak activity is 1")
        check(species.activity(atHour: 13) >= 0.25, "activity floor")
      }
      check(SpeciesCatalog.all.count == Set(SpeciesCatalog.all.map(\.id)).count, "unique ids")
      check(SpeciesCatalog.all.count == 80, "80 species in the catalog")
      let stocked = Set(WaterwayCatalog.all.flatMap(\.speciesIDs))
      for species in SpeciesCatalog.all {
        check(stocked.contains(species.id), "\(species.name) swims somewhere")
        check(!species.preferredTackle.isEmpty, "\(species.name) takes some tackle")
      }
    }

    test("waterways reference known species and offer licenses") {
      for waterway in WaterwayCatalog.all {
        check(!waterway.species.isEmpty, "\(waterway.name) has species")
        check(waterway.licenses.count == 6, "\(waterway.name) has six license options")
        check(waterway.licenses[0].price < waterway.licenses[3].price, "advanced costs more")
        for id in waterway.mustReleaseBasic {
          check(waterway.speciesIDs.contains(id), "must-release species lives there")
        }
      }
      check(WaterwayCatalog.all.first?.requiredLevel == 1, "first waterway open at level 1")
      check(WaterwayCatalog.all.count == 30, "30 waterways in the catalog")
      check(
        WaterwayCatalog.all.count == Set(WaterwayCatalog.all.map(\.id)).count,
        "unique waterway ids")
      let levels = WaterwayCatalog.all.map(\.requiredLevel)
      check(levels == levels.sorted(), "waterways listed in unlock order")
      check(levels.allSatisfy { $0 <= Leveling.maxLevel }, "every waterway unlocks by max level")
      for waterway in WaterwayCatalog.all {
        check(
          Set(waterway.speciesIDs).count == waterway.speciesIDs.count,
          "\(waterway.name) lists each species once")
        check(abs(waterway.latitude) <= 90 && abs(waterway.longitude) <= 180, "\(waterway.name) on the globe")
      }
    }

    test("starter rig geometry") {
      let rig = RigSetup.starter
      check(rig.lineLengthFt == 330, "110 yd of line on the spool")
      check(rig.maxCastFt > 60 && rig.maxCastFt < rig.lineLengthFt, "cast range \(rig.maxCastFt)")
      check(abs(rig.breakingStrainLb - 6.6) < 0.001, "mono line is the weakest link")
      check(rig.tackleKind == .spoon, "starter spoon")
      var heavy = rig
      heavy.lureID = "lure.spoon1"
      check(heavy.maxCastFt < rig.maxCastFt * 1.6, "overweight lure limited by rod")
      for item in TackleCatalog.all {
        check(!item.specLine.isEmpty, "spec line for \(item.name)")
      }
    }

    test("shop purchases, equipping and bait consumption") {
      var profile = PlayerProfile.newAngler()
      let spinner = TackleCatalog.find("lure.spinner4")
      let titan = TackleCatalog.find("rod.titan")
      check(err(profile.buy(titan)) == .levelTooLow, "level gate")
      check(ok(profile.buy(spinner)), "buy spinner")
      check(err(profile.buy(spinner)) == .alreadyOwned, "lures are one-off")
      check(profile.credits == 400 - spinner.price, "credits deducted")
      check(profile.isMissionComplete(MissionCatalog.all.first { $0.id == "gearUp" }!), "gear up")
      profile.credits = 10
      check(
        err(profile.buy(TackleCatalog.find("rod.floatlight"))) == .insufficientCredits,
        "insufficient credits")
      check(ok(profile.equip(spinner)), "equip owned lure")
      check(profile.rig.lureID == spinner.id, "rig updated")
      check(err(profile.equip(TackleCatalog.find("rod.argo"))) == .notOwned, "not owned")
      profile.add("term.float", quantity: 1)
      check(err(profile.equip(TackleCatalog.find("term.float"))) == .wrongSlot, "no slot")

      profile.rig.lureID = "bait.redworm"
      profile.inventory = [InventoryEntry(itemID: "bait.redworm", quantity: 1),
                           InventoryEntry(itemID: "lure.spoon5", quantity: 1)]
      profile.useBaitIfNeeded()
      check(!profile.owns("bait.redworm"), "last worm used")
      check(profile.rig.lureID == "lure.spoon5", "fell back to a lure")
    }

    test("travel needs level, license and credits") {
      var profile = PlayerProfile.newAngler()
      let missouri = WaterwayCatalog.find("muddyForkRiver")
      check(err(profile.canTravel(to: missouri)) == .levelTooLow, "level 4 needed")
      profile.xp = Leveling.xpRequired(forLevel: 4)
      check(err(profile.canTravel(to: missouri)) == .noLicense, "license needed")
      check(profile.buyLicense(missouri.licenses[0], for: missouri), "buy 1 day basic")
      check(profile.license(for: missouri.id)?.daysRemaining == 1, "one day")
      profile.credits = 10
      check(err(profile.canTravel(to: missouri)) == .insufficientCredits, "travel fee")
      profile.credits = 500
      check(ok(profile.travel(to: missouri)), "travel")
      check(profile.currentWaterwayID == missouri.id, "moved")
      check(profile.credits == 500 - missouri.travelFee, "fee paid")
      profile.endDay()
      check(profile.license(for: missouri.id) == nil, "license expired")
      check(profile.gameDay == 2, "day advanced")
    }

    test("casting flies to the target and can be retrieved") {
      var session = FishingSession(
        rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 7)
      check(session.phase == .ready, "starts ready")
      session.beginCast()
      check(session.phase == .charging, "charging")
      advance(&session, 0.55)
      check(session.castPower > 0.45 && session.castPower < 0.55, "power ramps \(session.castPower)")
      advance(&session, 1.0)
      check(abs(session.castPower - 0.6) < 0.02, "power ping-pongs back \(session.castPower)")
      session.releaseCast()
      check(session.phase == .flying, "flying")
      check(session.drainEvents().contains(where: {
        if case .cast = $0 { return true } else { return false }
      }), "cast event")
      var steps = 0
      while session.phase == .flying && steps < 600 {
        session.update(dt: 1.0 / 60.0)
        steps += 1
      }
      check(session.phase == .soaking, "landed in the water")
      check(abs(session.lureDistanceFt - session.castTargetFt) < 0.01, "at target")
      check(session.casts == 1, "cast counted")
      session.setReeling(true)
      var guardCount = 0
      while session.phase == .soaking && guardCount < 6000 {
        session.update(dt: 1.0 / 30.0)
        guardCount += 1
        if session.phase == .bite { session.update(dt: 2) }
      }
      check(session.phase == .ready, "retrieved back to shore or day ran on")
    }

    test("fish bite within a couple of minutes and a small fish can be landed") {
      var landedSeeds = 0
      var bites = 0
      for seed in 1...12 {
        var session = FishingSession(
          rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: UInt64(seed),
          startMinute: 7 * 60)
        castAndSoak(&session)
        var elapsed = 0.0
        session.setReeling(true)
        while (session.phase == .soaking || session.phase == .ready) && elapsed < 180 {
          session.update(dt: 1.0 / 30.0)
          elapsed += 1.0 / 30.0
          if session.phase == .ready {
            session.setReeling(false)
            castAndSoak(&session, power: 0.9)
            session.setReeling(true)
          }
        }
        if session.phase == .bite {
          bites += 1
          check(session.biteTimeLeft > 0, "bite window open")
          session.strike()
          if session.phase == .fighting {
            check(session.fish != nil, "fish on")
            let outcome = fight(&session)
            if outcome == .landed {
              landedSeeds += 1
              check(session.landedCatch != nil, "catch record")
              check(session.landedCatch!.weightLb >= session.landedCatch!.species.minWeightLb,
                    "weight in range")
            }
          }
        }
      }
      check(bites >= 8, "most seeds bite within three minutes (\(bites)/12)")
      check(landedSeeds >= 4, "a fair share of fights end in a landing (\(landedSeeds)/12)")
    }

    test("constant reeling against a heavy fish snaps the line") {
      var session = FishingSession(
        rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 3)
      session.hookForTesting(speciesID: "largemouthBass", weightLb: 14, distanceFt: 120)
      session.setReeling(true)
      var elapsed = 0.0
      while session.phase == .fighting && elapsed < 30 {
        session.update(dt: 1.0 / 30.0)
        elapsed += 1.0 / 30.0
      }
      check(session.phase == .lineSnapped, "snapped, got \(session.phase)")
      check(session.lineDurability < 1, "line took damage")
      check(session.drainEvents().contains(.lineSnapped), "snap event")
      session.acknowledgeOutcome()
      check(session.phase == .ready && session.fish == nil, "back to ready")
    }

    test("slack line lets the fish escape") {
      var session = FishingSession(
        rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 3)
      session.hookForTesting(speciesID: "goldenShiner", weightLb: 0.1, distanceFt: 80)
      session.setReeling(false)
      var elapsed = 0.0
      while session.phase == .fighting && elapsed < 20 {
        session.update(dt: 1.0 / 30.0)
        elapsed += 1.0 / 30.0
      }
      check(session.phase == .fishEscaped, "escaped, got \(session.phase)")
    }

    test("a hooked bluegill is landed with sensible reeling") {
      var session = FishingSession(
        rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 11)
      session.hookForTesting(speciesID: "bluegill", weightLb: 0.8, distanceFt: 90)
      let outcome = fight(&session)
      check(outcome == .landed, "landed, got \(outcome)")
      check(session.landedCatch?.grade == .common, "common grade")
      check(session.fightTime > 3, "fight lasted a few seconds (\(session.fightTime))")
      check(session.tensionZone != .red, "not in the red when landed")
    }

    test("ignoring a bite steals the bait") {
      var rig = RigSetup.starter
      rig.lureID = "bait.redworm"
      var session = FishingSession(
        rig: rig, waterway: WaterwayCatalog.find("lonePineLake"), seed: 5, startMinute: 7 * 60)
      castAndSoak(&session)
      var elapsed = 0.0
      while session.phase == .soaking && elapsed < 240 {
        session.update(dt: 1.0 / 30.0)
        elapsed += 1.0 / 30.0
      }
      check(session.phase == .bite, "worms attract a bite")
      advance(&session, FishingSession.strikeWindow + 0.2)
      check(session.phase == .soaking, "back to soaking")
      check(session.lastBiteWasStolen, "bait stolen flag")
      check(session.drainEvents().contains(.baitStolen), "bait stolen event")
    }

    test("the day ends at eleven at night") {
      var session = FishingSession(
        rig: .starter, waterway: WaterwayCatalog.find("lonePineLake"), seed: 1,
        startMinute: 22 * 60 + 30)
      check(session.clockLabel == "10:30 PM", "clock label \(session.clockLabel)")
      session.skipHour()
      check(session.phase == .dayOver, "day over")
      check(session.drainEvents().contains(.dayOver), "day over event")
      check(session.dayProgress == 1, "progress complete")
    }

    test("catches feed xp, keepnet, missions and the shop") {
      var profile = PlayerProfile.newAngler()
      let bluegill = SpeciesCatalog.find("bluegill")
      for index in 0..<3 {
        let record = CatchRecord(
          speciesID: bluegill.id, waterwayID: "lonePineLake", weightLb: 0.5 + Double(index) * 0.2,
          lengthIn: 7, grade: .common, gameDay: 1, gameMinute: 400, date: Date(), kept: true)
        profile.record(record)
      }
      check(profile.keepnet.count == 3, "three kept")
      check(profile.xp > 0, "earned xp")
      check(profile.stats.totalCatches == 3, "stats")
      let tight = MissionCatalog.all.first { $0.id == "tightLines" }!
      let parade = MissionCatalog.all.first { $0.id == "panfishParade" }!
      check(profile.isMissionComplete(tight), "first fish mission")
      check(profile.isMissionComplete(parade), "three bluegill mission")
      let creditsBefore = profile.credits
      check(profile.claimMission(tight), "claim")
      check(!profile.claimMission(tight), "no double claim")
      check(profile.credits == creditsBefore + tight.rewardCredits, "reward paid")
      let value = profile.keepnetValue
      check(value > 0, "keepnet worth something")
      let earned = profile.sellKeepnet()
      check(earned == value && profile.keepnet.isEmpty, "sold everything")
      check(profile.missionState("fullNet")?.progress == 3, "sold fish counted")

      let released = CatchRecord(
        speciesID: "spottedBass", waterwayID: "lonePineLake", weightLb: 2, lengthIn: 14,
        grade: .common, gameDay: 1, gameMinute: 500, date: Date(), kept: false)
      check(profile.mustRelease(SpeciesCatalog.find("spottedBass")), "basic license rule")
      profile.record(released)
      check(profile.stats.totalReleased == 1, "released counted")
      check(profile.keepnet.isEmpty, "released fish not kept")
    }

    test("profile survives a Codable round trip") {
      var profile = PlayerProfile.newAngler(name: "Tester")
      profile.xp = 1234
      profile.record(
        CatchRecord(
          speciesID: "walleye", waterwayID: "lonePineLake", weightLb: 3.2, lengthIn: 19,
          grade: .common, gameDay: 1, gameMinute: 600, date: Date(timeIntervalSince1970: 0),
          kept: true))
      let data = try JSONEncoder().encode(profile)
      let decoded = try JSONDecoder().decode(PlayerProfile.self, from: data)
      check(decoded == profile, "round trip equal")
      check(decoded.level == profile.level, "level derived")
    }

    test("seeded random is deterministic and bounded") {
      var a = SeededRandom(seed: 99)
      var b = SeededRandom(seed: 99)
      for _ in 0..<50 {
        let x = a.unit()
        check(x == b.unit(), "same sequence")
        check(x >= 0 && x < 1, "unit range")
      }
      check(a.weighted([("x", 0), ("y", 5)]) == "y", "zero weights never chosen")
      check(a.pick([Int]()) == nil, "empty pick")
    }

    print("\n\(passed) checks passed, \(failed) failed")
    for failure in failures { print("  - \(failure)") }
    exit(failed == 0 ? 0 : 1)
  }
}
