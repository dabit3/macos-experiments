import Foundation

@main
enum TrailModelTests {
  static func main() throws {
    var count = 0
    func check(_ condition: @autoclosure () -> Bool, _ name: String) {
      guard condition() else { fatalError("FAIL: \(name)") }
      count += 1
      print("PASS: \(name)")
    }
    let a = TrailPoint(latitude: 0, longitude: 0, elevation: 0)
    let b = TrailPoint(latitude: 0, longitude: 1, elevation: 600)
    check(abs(a.distance(to: b) - 111.1949266) < 0.001, "Haversine reference: equator degree")
    check(a.distance(to: a) == 0, "Zero distance")
    check(abs(a.distance(to: b) - b.distance(to: a)) < 0.0001, "Distance symmetry")
    let line = Trail(
      id: "line", name: "Line", region: "", landscape: "", difficulty: "", description: "",
      points: [a, b, a])
    check(line.ascent == 600, "Ascent excludes descent")
    check(abs(line.durationHours - (line.distance / 4 + 1)) < 0.001, "Naismith-style duration")
    check(line.point(at: -1) == a && line.point(at: 2) == a, "Interpolation clamps endpoints")
    check(
      abs(line.point(at: 0.25).longitude - 0.5) < 0.0001, "Distance-based midpoint interpolation")
    check(abs(line.point(at: 0.25).elevation - 300) < 0.001, "Elevation interpolation")
    for trail in Trails.all {
      check(trail.distance > 3 && trail.distance < 20, "\(trail.name) plausible distance")
      check(trail.ascent > 0 && trail.ascent < 1000, "\(trail.name) plausible gain")
      check(trail.points.first == trail.points.last, "\(trail.name) closed loop")
      check(
        zip(trail.distances, trail.distances.dropFirst()).allSatisfy { $0 < $1 },
        "\(trail.name) monotonic distance")
    }
    var trip = Trip.fresh(for: Trails.all[0])
    check(!trip.addWaypoint(name: " \n", fraction: 0.5), "Reject blank waypoint")
    check(!trip.addWaypoint(name: "Invalid", fraction: .nan), "Reject nonfinite fraction")
    check(
      !trip.addWaypoint(name: String(repeating: "x", count: 61), fraction: 0.5),
      "Reject excessive waypoint length")
    check(trip.addWaypoint(name: " Summit ", fraction: 0.8), "Accept named waypoint")
    check(trip.addWaypoint(name: "Lunch", fraction: 0.3), "Accept second waypoint")
    check(
      trip.waypoints.map(\.name) == ["Trailhead", "Lunch", "Summit"],
      "Waypoints sorted along route, names trimmed")
    check(
      trip.addWaypoint(name: "Finish", fraction: 2) && trip.waypoints.last?.fraction == 1,
      "Clamp waypoint position")
    check(!trip.addGear(name: "  "), "Reject empty gear")
    check(
      trip.addGear(name: " Field journal ") && trip.gear.last?.name == "Field journal",
      "Trim added gear")
    trip.gear[0].packed = true
    var archive = ExpeditionArchive()
    archive.drafts[trip.trailID] = trip
    archive.save(trip)
    trip.name = "Morning expedition"
    archive.save(trip)
    check(
      archive.saved.count == 1 && archive.saved[0].name == trip.name,
      "Saving same ID updates rather than duplicates")
    let folder = FileManager.default.homeDirectoryForCurrentUser.appending(
      path: ".trailhead-tests-\(UUID())")
    let url = folder.appending(path: "archive.json")
    defer { try? FileManager.default.removeItem(at: folder) }
    try archive.write(to: url)
    let decoded = try ExpeditionArchive.read(from: url)
    check(
      decoded == archive,
      "Atomic persistence roundtrip preserves drafts, stops, checklist and saved trips")
    var invalid = archive
    invalid.selectedTrailID = "missing"
    try invalid.write(to: url)
    do {
      _ = try ExpeditionArchive.read(from: url)
      fatalError("FAIL: invalid archive accepted")
    } catch { check(true, "Reject unknown route archive") }
    try Data("not json".utf8).write(to: url)
    do {
      _ = try ExpeditionArchive.read(from: url)
      fatalError("FAIL: corrupt archive accepted")
    } catch { check(true, "Reject malformed archive") }
    print("\(count) model checks passed.")
  }
}
