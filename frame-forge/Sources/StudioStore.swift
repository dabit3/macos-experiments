import Foundation
import SwiftUI

@MainActor
final class StudioStore: ObservableObject {
  @Published var project = SampleAnimation.make()
  @Published var selection = 0
  @Published var history = AnimationHistory()
  @Published var color = "493446"
  @Published var brushSize = 7.0
  @Published var eraser = false
  @Published var onionSkin = true
  @Published var playing = false
  @Published var savedProjects: [AnimationProject] = []
  @Published var notice: String?
  @Published var error: String?
  @Published var exportURL: URL?
  @Published var exporting = false
  private var playback: Task<Void, Never>?
  private let documents: URL
  private let defaults: UserDefaults

  var currentFrame: AnimationFrame { project.frames[selection] }
  var previousFrame: AnimationFrame? {
    selection > 0 ? project.frames[selection - 1] : nil
  }
  var projectFolder: URL { documents.appendingPathComponent("Projects", isDirectory: true) }
  var exportFolder: URL { documents.appendingPathComponent("Exports", isDirectory: true) }

  init() {
    documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    defaults = .standard
    do {
      try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
      if let last = defaults.string(forKey: "lastProject"),
        let id = UUID(uuidString: last)
      {
        project = try JSONDecoder().decode(
          AnimationProject.self, from: Data(contentsOf: projectURL(id))
        ).validated()
      } else {
        save(announce: false)
      }
      refreshLibrary()
    } catch {
      self.error = "Could not reopen your last project: \(error.localizedDescription)"
    }
  }

  private func projectURL(_ id: UUID) -> URL {
    projectFolder.appendingPathComponent(id.uuidString).appendingPathExtension("json")
  }

  func edit(_ change: (inout AnimationProject) -> Void) {
    stop()
    history.record(project)
    change(&project)
    selection = min(selection, project.frames.count - 1)
    project.updatedAt = Date()
    save(announce: false)
  }

  func addStroke(_ stroke: InkStroke) {
    guard !stroke.points.isEmpty else { return }
    let index = selection
    edit { $0.frames[index].strokes.append(stroke) }
  }

  func addFrame() {
    guard project.frames.count < AnimationProject.maximumFrames else { return }
    let index = selection + 1
    edit { $0.frames.insert(AnimationFrame(), at: index) }
    selection = index
  }

  func duplicateFrame() {
    guard project.frames.count < AnimationProject.maximumFrames else { return }
    let index = selection
    var next = index
    edit { next = FrameEditing.duplicate(in: &$0, at: index) }
    selection = next
  }

  func deleteFrame() {
    guard project.frames.count > 1 else { return }
    let index = selection
    var next = index
    edit { next = FrameEditing.delete(in: &$0, at: index) }
    selection = next
  }

  func moveFrame(_ offset: Int) {
    let index = selection
    guard project.frames.indices.contains(index + offset) else { return }
    var next = index
    edit { next = FrameEditing.move(in: &$0, at: index, by: offset) }
    selection = next
  }

  func undo() {
    stop()
    guard let restored = history.undo(project) else { return }
    project = restored
    selection = min(selection, project.frames.count - 1)
    save(announce: false)
  }

  func redo() {
    stop()
    guard let restored = history.redo(project) else { return }
    project = restored
    selection = min(selection, project.frames.count - 1)
    save(announce: false)
  }

  func save(announce: Bool = true) {
    do {
      let valid = try project.validated()
      try JSONEncoder().encode(valid).write(to: projectURL(project.id), options: .atomic)
      defaults.set(project.id.uuidString, forKey: "lastProject")
      if announce { showNotice("Saved to your studio") }
      refreshLibrary()
    } catch { self.error = "Unable to save: \(error.localizedDescription)" }
  }

  func refreshLibrary() {
    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: projectFolder, includingPropertiesForKeys: nil
      ).filter { $0.pathExtension == "json" }
      savedProjects = urls.compactMap { url in
        guard let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode(AnimationProject.self, from: data)
        else { return nil }
        return try? decoded.validated()
      }.sorted { $0.updatedAt > $1.updatedAt }
    } catch { self.error = "Unable to read the studio: \(error.localizedDescription)" }
  }

  func open(_ project: AnimationProject) {
    stop()
    self.project = project
    selection = 0
    history = AnimationHistory()
    save(announce: false)
  }

  func select(_ index: Int) {
    stop()
    selection = index
  }

  func togglePlayback() {
    if playing {
      stop()
      return
    }
    playing = true
    playback = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        try? await Task.sleep(for: .seconds(1.0 / Double(self.project.fps)))
        guard !Task.isCancelled else { return }
        self.selection = (self.selection + 1) % self.project.frames.count
      }
    }
  }

  func stop() {
    playback?.cancel()
    playback = nil
    playing = false
  }

  func showNotice(_ text: String) {
    notice = text
    Task {
      try? await Task.sleep(for: .seconds(2.5))
      if notice == text { notice = nil }
    }
  }

  func exportGIF() {
    stop()
    exporting = true
    let snapshot = project
    Task {
      do {
        let url = exportFolder.appendingPathComponent(
          "FrameForge-\(snapshot.id.uuidString.prefix(8)).gif")
        try GIFExporter.export(snapshot, to: url)
        exportURL = url
      } catch { self.error = "Export failed: \(error.localizedDescription)" }
      exporting = false
    }
  }
}
