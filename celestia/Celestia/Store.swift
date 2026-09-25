import Combine
import Foundation

@MainActor
final class Observatory: ObservableObject {
  @Published var archive: PlanArchive { didSet { persist() } }
  @Published var selectedID = "vega"
  @Published var error: String?
  @Published var notice: String?
  @Published private var history: [PlanArchive] = []
  let fileURL: URL

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = documents.appendingPathComponent("observing-plans.json")
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        archive = try JSONDecoder().decode(PlanArchive.self, from: Data(contentsOf: fileURL))
      } catch {
        archive = .initial
        self.error =
          "The saved archive could not be read. A sample plan is open. Your original file has been preserved."
        try? FileManager.default.copyItem(
          at: fileURL,
          to: documents.appendingPathComponent("unreadable-plans-\(UUID().uuidString).json"))
      }
    } else {
      archive = .initial
    }
  }

  var plan: ObservingPlan { archive.working }
  var selected: Star { Catalog.star(selectedID) ?? Catalog.stars[0] }
  var canUndo: Bool { !history.isEmpty }

  func change(_ mutation: (inout ObservingPlan) -> Void) {
    history.append(archive)
    if history.count > 40 { history.removeFirst() }
    mutation(&archive.working)
  }

  func checkpoint() {
    history.append(archive)
    if history.count > 40 { history.removeFirst() }
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    archive = previous
    notice = "Previous change restored"
  }

  func toggleTarget(_ star: Star) {
    change { plan in
      if plan.targets.contains(star.id) {
        plan.targets.removeAll { $0 == star.id }
      } else {
        plan.add(star.id)
      }
    }
  }

  func save(named name: String) {
    checkpoint()
    if archive.saveWorking(named: name) {
      notice = "Plan saved to this iPad"
    } else {
      error = "Give your observing plan a name before saving."
    }
  }

  func open(_ plan: ObservingPlan) {
    change { $0 = plan }
    selectedID = plan.targets.first ?? "vega"
    notice = "Opened \(plan.name)"
  }

  func newPlan() {
    change {
      $0.id = UUID()
      $0.name = "Untitled evening"
      $0.targets = []
      $0.notes = ""
    }
  }

  func export() -> URL? {
    let output = fileURL.deletingLastPathComponent().appendingPathComponent(
      "Celestia-observing-plan.md")
    do {
      try plan.exportMarkdown().write(to: output, atomically: true, encoding: .utf8)
      notice = "Markdown exported to Celestia’s Documents"
      return output
    } catch {
      self.error = "Could not export your plan: \(error.localizedDescription)"
      return nil
    }
  }

  private func persist() {
    do {
      let data = try JSONEncoder().encode(archive)
      try data.write(to: fileURL, options: .atomic)
    } catch {
      self.error = "Could not save your changes: \(error.localizedDescription)"
    }
  }
}
