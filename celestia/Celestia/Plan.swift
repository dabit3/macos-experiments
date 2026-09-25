import Foundation

struct ObservingPlan: Identifiable, Codable, Equatable {
  var id: UUID
  var name: String
  var siteID: String
  var date: Date
  var targets: [String]
  var notes: String

  static let sample = ObservingPlan(
    id: UUID(uuidString: "8629448E-2718-487D-83D0-07DF684C8F00")!,
    name: "Desert summer triangle", siteID: "joshua",
    date: Date(timeIntervalSince1970: 1_789_099_200),
    targets: ["vega", "deneb", "altair"],
    notes:
      "Let your eyes adapt for 20 minutes. Begin with Vega, then trace the Swan down the Milky Way. Bring binoculars and a red light."
  )

  var site: ObservingSite {
    ObservingSite.all.first { $0.id == siteID } ?? ObservingSite.all[0]
  }

  var resolvedTargets: [Star] { targets.compactMap(Catalog.star) }

  mutating func add(_ id: String) {
    guard Catalog.star(id) != nil, !targets.contains(id) else { return }
    targets.append(id)
  }

  func exportMarkdown() -> String {
    let dateString = Astronomy.formatted(date, site: site, pattern: "yyyy-MM-dd HH:mm zzz")
    let utcString = ISO8601DateFormatter().string(from: date)
    let rows = resolvedTargets.map { star in
      let position = Astronomy.position(star, at: date, site: site)
      return
        "| \(star.name) | \(star.constellation) | \(String(format: "%.4f", star.ra)) | \(String(format: "%.4f", star.dec)) | \(String(format: "%.1f", position.altitude))° | \(String(format: "%.1f", position.azimuth))° |"
    }.joined(separator: "\n")
    return """
      # \(name)

      \(site.name) — \(site.region)
      Latitude \(site.latitude)°, longitude \(site.longitude)° (east positive)
      Local: \(dateString) · UTC: \(utcString)

      | Target | Constellation | RA (hours, J2000) | Dec (degrees, J2000) | Altitude | Azimuth |
      | --- | --- | --- | --- | --- | --- |
      \(rows)

      ## Field notes
      \(notes.isEmpty ? "No field notes yet." : notes)

      ## Conventions
      Geometric center-of-star positions, using J2000 coordinates without precession,
      nutation, proper motion or refraction. Azimuth increases eastward from north.
      Visibility means geometric altitude above 0°, not darkness, weather or terrain.
      Bright-star sample catalog; not a complete planetarium or telescope pointing tool.
      Exported by Celestia.
      """
  }
}

struct PlanArchive: Codable, Equatable {
  var working: ObservingPlan
  var saved: [ObservingPlan]
  static let initial = PlanArchive(working: .sample, saved: [.sample])

  mutating func saveWorking(named name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    working.name = String(trimmed.prefix(80))
    if let index = saved.firstIndex(where: { $0.id == working.id }) {
      saved[index] = working
    } else {
      saved.insert(working, at: 0)
    }
    return true
  }
}
