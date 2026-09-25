import AVFoundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class Editor: ObservableObject {
  @Published var project = Project()
  @Published var selected: UUID?
  @Published var thumbnails: [String: NSImage] = [:]
  @Published var time = 0.0
  @Published var playing = false
  @Published var busy = true
  @Published var status = "Preparing your travel library…"
  @Published var error: String?
  @Published var canUndo = false
  @Published var exportURL: URL?
  let player = AVPlayer()
  private var observer: Any?
  private var history: [Project] = []
  private var generation = 0
  private var rebuildTask: Task<Void, Never>?

  var selectedClip: Clip? { project.clips.first { $0.id == selected } }
  var selectedMedia: Media? {
    guard let clip = selectedClip else { return nil }
    return project.media.first { $0.id == clip.mediaID }
  }

  init() {
    observer = player.addPeriodicTimeObserver(
      forInterval: CMTime(value: 1, timescale: 24), queue: .main
    ) { [weak self] value in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.time = value.seconds
        self.playing = self.player.rate > 0
        if value.seconds >= self.project.duration - 0.025 && self.playing {
          self.player.pause()
          self.playing = false
        }
      }
    }
    Task { await boot() }
  }

  func boot() async {
    do {
      try Storage.prepare()
      let samples = try await SampleFactory.makeLibrary(in: Storage.root)
      if FileManager.default.fileExists(atPath: Storage.autosave.path) {
        do {
          project = try Storage.load(Storage.autosave)
        } catch {
          self.error =
            "Your last session could not be restored. The original file is preserved. \(error.localizedDescription)"
          project = Project(media: samples)
        }
      } else {
        project = Project(
          media: samples,
          clips: samples.map {
            Clip(mediaID: $0.id, inPoint: 0, outPoint: $0.duration)
          })
      }
      selected = project.clips.first?.id
      await loadThumbnails()
      await rebuild()
      status = "All changes saved locally"
    } catch { self.error = error.localizedDescription }
    busy = false
  }

  func loadThumbnails() async {
    for media in project.media where thumbnails[media.id] == nil {
      thumbnails[media.id] = try? await VideoEngine.thumbnail(URL(fileURLWithPath: media.path))
    }
  }

  func change(_ operation: (inout Project) throws -> Void) {
    do {
      var updated = project
      try operation(&updated)
      _ = try updated.validated()
      guard updated != project else { return }
      history.append(project)
      if history.count > 60 { history.removeFirst() }
      project = updated
      canUndo = true
      persist()
      scheduleRebuild()
    } catch { self.error = error.localizedDescription }
  }

  func persist() {
    do {
      try Storage.save(project, to: Storage.autosave)
      status = "All changes saved locally"
    } catch {
      status = "Could not autosave"
      self.error = error.localizedDescription
    }
  }

  func scheduleRebuild() {
    player.pause()
    playing = false
    rebuildTask?.cancel()
    rebuildTask = Task {
      try? await Task.sleep(nanoseconds: 160_000_000)
      if !Task.isCancelled { await rebuild() }
    }
  }

  func rebuild() async {
    generation += 1
    let revision = generation
    let position = min(time, project.duration)
    guard !project.clips.isEmpty else {
      player.replaceCurrentItem(with: nil)
      time = 0
      return
    }
    do {
      let sequence = try await VideoEngine.sequence(project)
      guard revision == generation, !Task.isCancelled else { return }
      let item = AVPlayerItem(asset: sequence.composition)
      item.videoComposition = sequence.videoComposition
      player.replaceCurrentItem(with: item)
      seek(position)
    } catch { self.error = error.localizedDescription }
  }

  func seek(_ seconds: Double) {
    let clamped = min(max(0, seconds), max(0, project.duration - 1.0 / 24))
    time = clamped
    player.seek(
      to: CMTime(seconds: clamped, preferredTimescale: 600),
      toleranceBefore: .zero, toleranceAfter: .zero)
  }

  func togglePlayback() {
    guard !project.clips.isEmpty else { return }
    if playing {
      player.pause()
      playing = false
    } else {
      if time >= project.duration - 0.08 { seek(0) }
      player.play()
      playing = true
    }
  }

  func append(_ media: Media) {
    let clip = Clip(mediaID: media.id, inPoint: 0, outPoint: media.duration)
    change { $0.clips.append(clip) }
    selected = clip.id
  }

  func undo() {
    guard let previous = history.popLast() else { return }
    project = previous
    canUndo = !history.isEmpty
    selected = project.clips.first?.id
    persist()
    scheduleRebuild()
  }

  func undoFromMenu() {
    if let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isEditable {
      if textView.undoManager?.canUndo == true { textView.undoManager?.undo() }
    } else {
      undo()
    }
  }

  func removeSelected() {
    guard let selected else { return }
    change { $0.clips.removeAll { $0.id == selected } }
    self.selected = project.clips.first?.id
  }

  func clearTimeline() {
    change { $0.clips.removeAll() }
    selected = nil
  }

  func saveAs() {
    let panel = NSSavePanel()
    panel.title = "Save Cutline project"
    panel.nameFieldStringValue = project.name
    panel.allowedContentTypes = [UTType(filenameExtension: "cutline", conformingTo: .data) ?? .data]
    panel.allowsOtherFileTypes = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try Storage.save(project, to: url)
      status = "Saved \(url.lastPathComponent)"
    } catch { self.error = error.localizedDescription }
  }

  func openProject() {
    let panel = NSOpenPanel()
    panel.title = "Open Cutline project"
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let loaded = try Storage.load(url)
      guard loaded.media.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
        throw EditorError.missingMedia
      }
      change { $0 = loaded }
      selected = project.clips.first?.id
      Task { await loadThumbnails() }
    } catch { self.error = error.localizedDescription }
  }

  func importMedia() {
    let panel = NSOpenPanel()
    panel.title = "Import local video"
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    busy = true
    status = "Optimizing local media…"
    Task {
      defer { busy = false }
      do {
        let output = Storage.root.appendingPathComponent("import-\(UUID().uuidString).mov")
        let media = try await VideoEngine.importMovie(url, to: output)
        change { $0.media.append(media) }
        await loadThumbnails()
      } catch { self.error = error.localizedDescription }
    }
  }

  func exportMovie() {
    player.pause()
    playing = false
    let panel = NSSavePanel()
    panel.title = "Export your film"
    panel.nameFieldStringValue = "\(project.name).mp4"
    panel.allowedContentTypes = [.mpeg4Movie]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    busy = true
    status = "Rendering your film…"
    let snapshot = project
    Task {
      defer { busy = false }
      let staging = url.deletingLastPathComponent().appendingPathComponent(
        ".cutline-\(UUID().uuidString).mp4")
      do {
        try await VideoEngine.export(snapshot, to: staging)
        if FileManager.default.fileExists(atPath: url.path) {
          _ = try FileManager.default.replaceItemAt(url, withItemAt: staging)
        } else {
          try FileManager.default.moveItem(at: staging, to: url)
        }
        exportURL = url
        status = "Export complete · \(url.lastPathComponent)"
      } catch {
        try? FileManager.default.removeItem(at: staging)
        self.error = error.localizedDescription
        status = "Export did not finish"
      }
    }
  }
}
