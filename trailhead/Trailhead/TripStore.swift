import SwiftUI

@MainActor
final class TripStore: ObservableObject {
  @Published var archive = ExpeditionArchive()
  @Published var error: String?
  @Published var notice: String?
  @Published var previous: ExpeditionArchive?
  private let url: URL

  var trail: Trail { Trails.find(archive.selectedTrailID) }
  var trip: Trip { archive.drafts[trail.id] ?? Trip.fresh(for: trail) }
  var isSaved: Bool { archive.saved.contains(trip) }

  init() {
    url = URL.documentsDirectory.appending(path: "trailhead-trips.json")
    do {
      if FileManager.default.fileExists(atPath: url.path) {
        archive = try ExpeditionArchive.read(from: url)
      }
    } catch {
      self.error =
        "Your trip archive could not be read. A recovery copy was kept; a new field journal is ready."
      let backup = url.deletingPathExtension().appendingPathExtension(
        "recovery-\(Int(Date().timeIntervalSince1970)).json")
      try? FileManager.default.copyItem(at: url, to: backup)
    }
    for trail in Trails.all where archive.drafts[trail.id] == nil {
      archive.drafts[trail.id] = Trip.fresh(for: trail)
    }
  }

  func persist() {
    do { try archive.write(to: url) } catch {
      self.error = "Could not save to this device. Please try again. \(error.localizedDescription)"
    }
  }

  func edit(_ action: (inout Trip) -> Void) {
    previous = archive
    var value = trip
    action(&value)
    archive.drafts[trail.id] = value
    notice = nil
    persist()
  }

  func select(_ trail: Trail) {
    previous = archive
    archive.selectedTrailID = trail.id
    notice = nil
    persist()
  }

  func save() {
    previous = archive
    archive.save(trip)
    persist()
    notice = "Trip saved to your field journal"
  }

  func reopen(_ trip: Trip) {
    previous = archive
    archive.selectedTrailID = trip.trailID
    archive.drafts[trip.trailID] = trip
    persist()
    notice = "Saved expedition reopened"
  }

  func reset() {
    previous = archive
    archive.drafts[trail.id] = Trip.fresh(for: trail)
    persist()
    notice = "Fresh plan ready. Undo restores your edits."
  }

  func undo() {
    guard let previous else { return }
    archive = previous
    self.previous = nil
    persist()
    notice = "Last change undone"
  }
}
