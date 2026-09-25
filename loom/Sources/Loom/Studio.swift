import AppKit
import LoomCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Studio: ObservableObject {
  @Published private(set) var project: Project
  @Published var notice = "Ready to explore"
  @Published var error: String?
  @Published var hovered: Datum?
  @Published var inspector = 0
  @Published private(set) var history: [Project] = []
  @Published private(set) var future: [Project] = []
  @Published private(set) var fileURL: URL?
  private var autosaveTask: Task<Void, Never>?

  static var autosaveURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Loom", isDirectory: true).appendingPathComponent("Autosave.loom")
  }

  init() {
    project = Self.sample("cycling")
    if FileManager.default.fileExists(atPath: Self.autosaveURL.path) {
      do {
        project = try Project.decode(Data(contentsOf: Self.autosaveURL))
        notice = "Restored your last story"
      } catch {
        notice = "Could not restore autosave; opened sample"
        self.error =
          "Your autosave could not be read. The original file is unchanged until you edit. \(error.localizedDescription)"
      }
    }
  }

  static func sample(_ name: String) -> Project {
    guard
      let url = Bundle.module.url(
        forResource: name, withExtension: "csv", subdirectory: "Resources"),
      let text = try? String(contentsOf: url, encoding: .utf8),
      let dataset = try? CSV.parse(text, name: "\(name).csv")
    else {
      preconditionFailure("Bundled CSV resource is missing or invalid")
    }
    var project = Project(dataset: dataset)
    project.measure = 2
    project.scatterX = 3
    if name == "cycling" {
      project.filterColumn = 1
      project.filterValue = "2025"
    } else {
      project.title = "A decade of\ncleaner energy."
      project.subtitle = "The steady rise of renewable electricity, 2016–2025."
      project.source = "ILLUSTRATIVE DATA  /  RENEWABLE SHARE OF ELECTRICITY"
      project.kind = .line
      project.sort = .source
      project.theme = .green
    }
    return project
  }

  var result: ChartResult { DataEngine.compute(project) }

  func binding<Value>(_ keyPath: WritableKeyPath<Project, Value>) -> Binding<Value> {
    Binding(
      get: { self.project[keyPath: keyPath] },
      set: { value in
        var next = self.project
        next[keyPath: keyPath] = value
        self.replace(next)
      })
  }

  func replace(_ next: Project) {
    guard next != project else { return }
    history.append(project)
    if history.count > 200 { history.removeFirst() }
    future = []
    project = next
    hovered = nil
    scheduleAutosave()
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    future.append(project)
    project = previous
    hovered = nil
    scheduleAutosave()
    notice = "Change undone"
  }

  func redo() {
    guard let next = future.popLast() else { return }
    history.append(project)
    project = next
    hovered = nil
    scheduleAutosave()
    notice = "Change restored"
  }

  private func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(project)
  }

  func persist() {
    do {
      try FileManager.default.createDirectory(
        at: Self.autosaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try encoded().write(to: Self.autosaveURL, options: .atomic)
    } catch {
      notice = "Autosave failed — use Save as"
      self.error = error.localizedDescription
    }
  }

  private func scheduleAutosave() {
    autosaveTask?.cancel()
    autosaveTask = Task {
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      persist()
      notice = "Autosaved on this Mac"
    }
  }

  func loadSample(_ name: String) {
    replace(Self.sample(name))
    fileURL = nil
    notice = "Sample loaded · illustrative data"
  }

  func importCSV() {
    let panel = NSOpenPanel()
    panel.title = "Import a CSV dataset"
    panel.allowedContentTypes = [.commaSeparatedText, .plainText]
    panel.allowsMultipleSelection = false
    panel.directoryURL = Bundle.module.url(forResource: "Resources", withExtension: nil)
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      guard data.count <= 5_000_000 else {
        throw LoomError.invalid("CSV files must be smaller than 5 MB.")
      }
      guard let text = String(data: data, encoding: .utf8) else {
        throw LoomError.invalid("Please save the CSV using UTF-8 encoding.")
      }
      let dataset = try CSV.parse(text, name: url.lastPathComponent)
      var next = Project(dataset: dataset)
      next.title = url.deletingPathExtension().lastPathComponent.capitalized
      next.subtitle = "A new perspective, drawn from your data."
      next.source = "SOURCE  /  \(url.lastPathComponent.uppercased())"
      replace(next)
      fileURL = nil
      notice = "Imported \(dataset.rows.count) rows · \(dataset.columns.count) columns"
    } catch { self.error = error.localizedDescription }
  }

  func openProject() {
    let panel = NSOpenPanel()
    panel.title = "Open a Loom story"
    panel.allowedContentTypes = [UTType(filenameExtension: "loom") ?? .json, .json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let next = try Project.decode(Data(contentsOf: url))
      replace(next)
      fileURL = url
      notice = "Opened \(url.lastPathComponent)"
    } catch { self.error = "Could not open this story. \(error.localizedDescription)" }
  }

  func save(asNew: Bool = false) {
    var target = fileURL
    if target == nil || asNew {
      let panel = NSSavePanel()
      panel.title = "Save your Loom story"
      panel.allowedContentTypes = [UTType(filenameExtension: "loom") ?? .json]
      panel.nameFieldStringValue = "My story.loom"
      panel.canCreateDirectories = true
      guard panel.runModal() == .OK else { return }
      target = panel.url
    }
    guard let url = target else { return }
    do {
      try encoded().write(to: url, options: .atomic)
      fileURL = url
      persist()
      notice = "Saved \(url.lastPathComponent)"
    } catch { self.error = error.localizedDescription }
  }

  func export(_ format: String) {
    let panel = NSSavePanel()
    panel.title = "Export your editorial graphic"
    panel.allowedContentTypes = [format == "PDF" ? .pdf : .png]
    panel.nameFieldStringValue = "Loom-\(project.kind.rawValue.lowercased()).\(format.lowercased())"
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try format == "PDF" ? Exporter.pdf(project) : Exporter.png(project)
      try data.write(to: url, options: .atomic)
      notice =
        "Exported \(url.lastPathComponent) · \(format == "PDF" ? "vector artwork" : "2080 × 1480 px")"
    } catch { self.error = error.localizedDescription }
  }
}
