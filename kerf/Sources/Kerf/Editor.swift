import AppKit
import KerfCore
import SwiftUI
import UniformTypeIdentifiers

enum EditorTool: String, CaseIterable {
  case select = "Select"
  case rectangle = "Rectangle"
  case circle = "Circle"
  case polyline = "Polyline"
  var symbol: String {
    switch self {
    case .select: "cursorarrow"
    case .rectangle: "rectangle"
    case .circle: "circle"
    case .polyline: "point.topleft.down.to.point.bottomright.curvepath"
    }
  }
}

@MainActor final class Editor: ObservableObject {
  @Published var design: Design
  @Published var selected: UUID?
  @Published var tool: EditorTool = .select
  @Published var snap = true
  @Published var preview = false
  @Published var zoom: Double = 1
  @Published var status = "Ready for your next idea."
  @Published var notice: String?
  @Published var history = History()
  @Published var documentURL: URL?
  var dragOriginal: Design?
  let autosaveURL: URL
  var part: Part? { design.parts.first { $0.id == selected } }
  var overlaps: Set<UUID> { Set(design.overlapPairs.flatMap { [$0.0, $0.1] }) }
  var issueCount: Int { design.outOfBounds.count + design.overlapPairs.count }

  init() {
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Kerf", isDirectory: true)
    autosaveURL = directory.appendingPathComponent("Autosave.kerf")
    var initial = Design.sample
    var failure: String?
    if FileManager.default.fileExists(atPath: autosaveURL.path) {
      do {
        initial = try JSONDecoder().decode(Design.self, from: Data(contentsOf: autosaveURL))
          .validated()
      } catch { failure = "Could not restore autosave: \(error.localizedDescription)" }
    }
    design = initial
    selected = initial.parts.first?.id
    notice = failure
  }

  func commit(_ change: (inout Design) -> Void, message: String) {
    var next = design
    change(&next)
    do { _ = try next.validated() } catch {
      notice = error.localizedDescription
      return
    }
    guard next != design else { return }
    history.record(design)
    design = next
    status = message
    persist()
  }

  func editPart(_ change: (inout Part) -> Void) {
    guard let id = selected else { return }
    commit(
      { design in
        if let index = design.parts.firstIndex(where: { $0.id == id }) {
          change(&design.parts[index])
        }
      }, message: "Part updated · millimetres")
  }

  func persist() {
    do {
      try FileManager.default.createDirectory(
        at: autosaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(design).write(to: autosaveURL, options: .atomic)
    } catch { notice = "Autosave failed: \(error.localizedDescription)" }
  }

  func undo() {
    guard let old = history.undo(design) else { return }
    design = old
    repairSelection()
    status = "Undid last edit"
    persist()
  }

  func redo() {
    guard let next = history.redo(design) else { return }
    design = next
    repairSelection()
    status = "Redid last edit"
    persist()
  }

  func repairSelection() {
    if !design.parts.contains(where: { $0.id == selected }) { selected = design.parts.first?.id }
  }

  func duplicate() {
    guard var copy = part else { return }
    copy.id = UUID()
    copy.name += " copy"
    copy.x += 12
    copy.y += 12
    commit({ $0.parts.append(copy) }, message: "Duplicated · move the copy to clear its overlap")
    selected = copy.id
  }

  func delete() {
    guard let selected else { return }
    commit({ $0.parts.removeAll { $0.id == selected } }, message: "Part deleted")
    self.selected = nil
  }

  func add(_ kind: ShapeKind) {
    let new = Part(
      name: kind == .circle ? "New coaster" : "New panel", kind: kind, x: 120, y: 120, width: 60,
      height: 60)
    commit({ $0.parts.append(new) }, message: "Added \(kind.rawValue)")
    selected = new.id
    tool = .select
  }

  func reset() {
    commit({ $0 = .sample }, message: "Sample restored · Undo to recover your design")
    selected = design.parts.first?.id
    documentURL = nil
    zoom = 1
  }

  func snapped(_ value: Double) -> Double {
    snap ? (value / 5).rounded() * 5 : (value * 10).rounded() / 10
  }

  func beginDrag() { dragOriginal = design }

  func endDrag() {
    if let original = dragOriginal, original != design {
      do { _ = try design.validated() } catch {
        design = original
        notice = error.localizedDescription
        dragOriginal = nil
        return
      }
      history.record(original)
      persist()
      status = "Geometry updated"
    }
    dragOriginal = nil
  }

  func moveSelected(dx: Double, dy: Double) {
    editPart {
      $0.x += dx
      $0.y += dy
    }
  }

  func placeInFreeSpace() {
    guard let p = part else { return }
    let gap = max(5, design.kerf + 1)
    let maxX = design.sheetWidth - p.width - gap
    let maxY = design.sheetHeight - p.height - gap
    guard maxX >= gap, maxY >= gap else {
      notice = "This part is larger than the usable sheet."
      return
    }
    for y in stride(from: gap, through: maxY, by: 5) {
      for x in stride(from: gap, through: maxX, by: 5) {
        var candidate = p
        candidate.x = x
        candidate.y = y
        let collides = design.parts.contains {
          $0.id != p.id && $0.operation == .cut && Design.overlaps(candidate, $0, clearance: gap)
        }
        if !collides {
          editPart {
            $0.x = x
            $0.y = y
          }
          status = "Placed in free space · 5 mm clearance"
          return
        }
      }
    }
    notice = "No free position found. Try a larger sheet or a smaller part. Nothing was moved."
  }

  func save() {
    let panel = NSSavePanel()
    panel.title = "Save Kerf design"
    panel.nameFieldStringValue = documentURL?.lastPathComponent ?? "Alpine.kerf"
    panel.allowedContentTypes = [UTType(filenameExtension: "kerf") ?? .json]
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(design).write(to: url, options: .atomic)
      documentURL = url
      status = "Saved \(url.lastPathComponent)"
    } catch { notice = "Save failed: \(error.localizedDescription)" }
  }

  func open() {
    let panel = NSOpenPanel()
    panel.title = "Open Kerf design"
    panel.allowedContentTypes = [UTType(filenameExtension: "kerf") ?? .json, .json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let next = try JSONDecoder().decode(Design.self, from: Data(contentsOf: url)).validated()
      commit({ $0 = next }, message: "Opened \(url.lastPathComponent)")
      documentURL = url
      selected = design.parts.first?.id
      zoom = 1
    } catch { notice = "Could not open design: \(error.localizedDescription)" }
  }

  func exportSVG() {
    guard issueCount == 0 else {
      notice =
        "Resolve \(issueCount) fabrication warning(s) before export. Cut parts must not overlap or extend beyond the sheet. Engraving can overlay a cut part."
      return
    }
    let panel = NSSavePanel()
    panel.title = "Export fabrication SVG"
    panel.nameFieldStringValue = "Alpine-sheet.svg"
    panel.allowedContentTypes = [.svg]
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try design.svg().write(to: url, atomically: true, encoding: .utf8)
      status =
        "Exported \(url.lastPathComponent) · \(Int(design.sheetWidth)) × \(Int(design.sheetHeight)) mm"
    } catch { notice = "Export failed: \(error.localizedDescription)" }
  }
}
