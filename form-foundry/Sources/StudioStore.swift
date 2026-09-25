import Foundation
import SwiftUI

@MainActor
final class StudioStore: ObservableObject {
  @Published private(set) var project = Project.sample
  @Published var selectedID: UUID?
  @Published private(set) var history = History()
  @Published var snap = true
  @Published var status = "Ready to shape your next idea."
  @Published var error: String?
  @Published var savedProjects: [URL] = []
  @Published var exportURL: URL?
  @Published var exportVertexCount = 0
  @Published var exportFaceCount = 0
  let documents: URL

  var selected: Solid? { project.solids.first { $0.id == selectedID } }
  var volume: Double { project.solids.reduce(0) { $0 + $1.volume } / 1000 }
  var workspaceURL: URL { documents.appendingPathComponent("Workspace.json") }
  var library: URL { documents.appendingPathComponent("Projects", isDirectory: true) }
  var exports: URL { documents.appendingPathComponent("Exports", isDirectory: true) }

  init() {
    documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    do {
      try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: workspaceURL.path) {
        project = try ProjectIO.decode(Data(contentsOf: workspaceURL))
        status = "Workspace restored."
      }
    } catch {
      self.error =
        "Your workspace could not be read. The bundled example is available. \(error.localizedDescription)"
    }
    selectedID = project.solids.first?.id
    refreshLibrary()
  }

  func commit(_ next: Project, message: String) {
    guard next.isValid else {
      error =
        "Use dimensions from 1–500 mm, X/Z from −500–500 mm, elevation from 0–500 mm and rotation from −360–360°. Limit: 100 solids."
      return
    }
    guard next != project else { return }
    history.record(project)
    project = next
    status = message
    persist()
  }

  func edit(_ change: (inout Solid) -> Void) {
    guard let index = project.solids.firstIndex(where: { $0.id == selectedID }) else { return }
    var next = project
    change(&next.solids[index])
    commit(next, message: "\(next.solids[index].name) updated.")
  }

  func setNumber(_ value: Double, key: WritableKeyPath<Solid, Double>, position: Bool = false) {
    let resolved = position && snap ? (value / 5).rounded() * 5 : value
    edit { $0[keyPath: key] = resolved }
  }

  func add(_ profile: Profile) {
    var next = project
    let solid = Solid(
      name: profile == .rectangle
        ? "Block \(next.solids.count + 1)" : "Round \(next.solids.count + 1)",
      profile: profile, width: 40, depth: 40, height: 30,
      x: 25, y: 8, z: -20, finish: .vermilion
    )
    next.solids.append(solid)
    commit(next, message: "\(profile.label) profile extruded.")
    if project.solids.contains(where: { $0.id == solid.id }) { selectedID = solid.id }
  }

  func duplicate() {
    guard var copy = selected else { return }
    copy.id = UUID()
    copy.name += " copy"
    copy.x += 15
    copy.z += 15
    var next = project
    next.solids.append(copy)
    commit(next, message: "Solid duplicated.")
    if project.solids.contains(where: { $0.id == copy.id }) { selectedID = copy.id }
  }

  func delete() {
    guard let selectedID else { return }
    var next = project
    next.solids.removeAll { $0.id == selectedID }
    commit(next, message: "Solid deleted. Undo to bring it back.")
    self.selectedID = project.solids.first?.id
  }

  func undo() {
    guard let previous = history.undo(project) else { return }
    project = previous
    reconcileSelection()
    status = "Last change undone."
    persist()
  }

  func redo() {
    guard let next = history.redo(project) else { return }
    project = next
    reconcileSelection()
    status = "Change restored."
    persist()
  }

  func reconcileSelection() {
    if !project.solids.contains(where: { $0.id == selectedID }) {
      selectedID = project.solids.first?.id
    }
  }

  func newProject() {
    commit(
      Project(title: "Untitled form", solids: []),
      message: "A clean workplane. Start with a profile.")
    selectedID = nil
  }

  func reset() {
    commit(.sample, message: "Desk organizer sample restored.")
    selectedID = project.solids.first?.id
  }

  func persist() {
    do { try ProjectIO.write(project, to: workspaceURL) } catch {
      self.error = "Could not save workspace: \(error.localizedDescription)"
    }
  }

  func save(named name: String) {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
      error = "Give your project a name before saving."
      return
    }
    var next = project
    next.title = String(title.prefix(80))
    commit(next, message: "Project named.")
    let safeName = next.title.map { $0.isLetter || $0.isNumber || $0 == " " ? $0 : "-" }
    let url = library.appendingPathComponent(String(safeName) + ".json")
    do {
      try ProjectIO.write(project, to: url)
      persist()
      status = "Saved “\(project.title)” to the project library."
      refreshLibrary()
    } catch { self.error = "Could not save project: \(error.localizedDescription)" }
  }

  func open(_ url: URL) {
    do {
      let decoded = try ProjectIO.decode(Data(contentsOf: url))
      commit(decoded, message: "Opened “\(decoded.title)”.")
      selectedID = project.solids.first?.id
    } catch { self.error = "This project could not be opened: \(error.localizedDescription)" }
  }

  func refreshLibrary() {
    do {
      savedProjects = try FileManager.default.contentsOfDirectory(
        at: library, includingPropertiesForKeys: nil
      ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch { self.error = "Could not read project library: \(error.localizedDescription)" }
  }

  func export() {
    guard !project.solids.isEmpty else {
      error = "Add a solid before exporting a mesh."
      return
    }
    do {
      let url = exports.appendingPathComponent("FormFoundry.obj")
      try Mesh.obj(project: project).write(to: url, atomically: true, encoding: .utf8)
      exportVertexCount = project.solids.reduce(0) { $0 + Mesh.make(for: $1).vertices.count }
      exportFaceCount = project.solids.reduce(0) { $0 + Mesh.make(for: $1).triangles.count }
      exportURL = url
      status = "OBJ exported to Files / Form Foundry / Exports."
    } catch { self.error = "Mesh export failed: \(error.localizedDescription)" }
  }
}
