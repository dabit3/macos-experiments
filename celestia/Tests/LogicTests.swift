import Foundation

@main
enum LogicTests {
  static func main() throws {
    var count = 0
    func check(_ condition: Bool, _ message: String) {
      precondition(condition, message)
      count += 1
      print("PASS \(message)")
    }
    func near(_ value: Double, _ expected: Double, tolerance: Double = 0.001) -> Bool {
      abs(value - expected) < tolerance
    }
    let j2000 = Date(timeIntervalSince1970: 946_728_000)
    check(near(Astronomy.julianDate(j2000), 2_451_545), "J2000 Julian date")
    check(
      near(Astronomy.siderealDegrees(date: j2000, longitude: 0), 280.46061837),
      "J2000 Greenwich sidereal angle")
    check(near(Astronomy.wrap(-725), 355), "Negative angle wrapping")
    let equator = ObservingSite(
      id: "test", name: "Equator", region: "", latitude: 0, longitude: 0, timeZone: "UTC")
    let meridianRA = Astronomy.siderealDegrees(date: j2000, longitude: 0) / 15
    let zenith = Astronomy.horizontal(ra: meridianRA, dec: 0, date: j2000, site: equator)
    check(near(zenith.altitude, 90), "Equatorial star at transit reaches zenith")
    let east = Astronomy.horizontal(ra: meridianRA + 6, dec: 0, date: j2000, site: equator)
    check(near(east.altitude, 0) && near(east.azimuth, 90), "Rising star is on eastern horizon")
    let west = Astronomy.horizontal(ra: meridianRA - 6, dec: 0, date: j2000, site: equator)
    check(near(west.altitude, 0) && near(west.azimuth, 270), "Setting star is on western horizon")
    let nadir = Astronomy.horizontal(ra: meridianRA + 12, dec: 0, date: j2000, site: equator)
    check(near(nadir.altitude, -90), "Opposite-meridian star is at nadir")
    let site = ObservingSite.all[0]
    let pole = Astronomy.horizontal(ra: 0, dec: 90, date: j2000, site: site)
    check(
      near(pole.altitude, site.latitude) && near(pole.azimuth, 0),
      "North pole altitude equals northern latitude")
    let south = ObservingSite.all[2]
    let southernPole = Astronomy.horizontal(ra: 0, dec: -90, date: j2000, site: south)
    check(near(southernPole.altitude, -south.latitude), "Southern pole altitude at southern site")
    let vega = Catalog.star("vega")!
    let before = Astronomy.position(vega, at: ObservingPlan.sample.date, site: site)
    let after = Astronomy.position(
      vega, at: ObservingPlan.sample.date.addingTimeInterval(21600), site: site)
    check(
      before.altitude > 60 && after.altitude < 15,
      "Vega moves from high evening sky toward horizon over six hours")
    let siderealDay = Astronomy.position(
      vega, at: ObservingPlan.sample.date.addingTimeInterval(86164.0905), site: site)
    check(
      near(siderealDay.altitude, before.altitude, tolerance: 0.01),
      "Sky repeats after one sidereal day")
    check(Set(Catalog.stars.map(\.id)).count == Catalog.stars.count, "Unique catalog IDs")
    check(
      Catalog.stars.allSatisfy { $0.ra >= 0 && $0.ra < 24 && abs($0.dec) <= 90 },
      "Catalog coordinate bounds")
    check(
      Catalog.paths.flatMap { $0 }.allSatisfy { Catalog.star($0) != nil },
      "All constellation links reference real catalog stars")
    check(
      ObservingSite.all.allSatisfy { TimeZone(identifier: $0.timeZone) != nil },
      "Every observing site has a valid time zone")
    for star in Catalog.stars {
      for location in ObservingSite.all {
        let position = Astronomy.position(star, at: ObservingPlan.sample.date, site: location)
        precondition(
          position.altitude.isFinite && abs(position.altitude) <= 90
            && (0..<360).contains(position.azimuth))
      }
    }
    check(true, "All star/site combinations yield finite bounded positions")
    var plan = ObservingPlan.sample
    plan.add("vega")
    check(plan.targets.count == 3, "Queue rejects duplicate targets")
    plan.add("not-a-star")
    check(plan.targets.count == 3, "Queue rejects unknown targets")
    plan.add("polaris")
    check(plan.targets.last == "polaris", "Queue preserves append order")
    let exported = plan.exportMarkdown()
    check(
      exported.contains("| Polaris |") && exported.contains("2026-09-11T04:00:00Z"),
      "Markdown exports target and UTC timestamp")
    check(exported.contains("21:00 PDT"), "Export converts to site's local date and daylight time")
    var archive = PlanArchive(working: plan, saved: [.sample])
    check(!archive.saveWorking(named: " \n "), "Blank plan names rejected")
    check(
      archive.saveWorking(named: "  Night study  ") && archive.working.name == "Night study",
      "Plan names trimmed")
    check(
      archive.saved.count == 1 && archive.saved[0].targets.count == 4,
      "Existing plan updates by identity")
    archive.working.id = UUID()
    check(
      archive.saveWorking(named: "Second evening") && archive.saved.count == 2,
      "New plan is saved independently")
    let data = try JSONEncoder().encode(archive)
    let decoded = try JSONDecoder().decode(PlanArchive.self, from: data)
    check(decoded == archive, "Archive JSON round-trip preserves notes/time/site/targets")
    do {
      _ = try JSONDecoder().decode(PlanArchive.self, from: Data("invalid".utf8))
      preconditionFailure("Invalid JSON must throw")
    } catch { check(true, "Corrupt archive is rejected") }
    check(
      Astronomy.compass(359) == "N" && Astronomy.compass(90) == "E", "Compass boundaries wrap north"
    )
    print("\(count) logic tests passed")
  }
}
