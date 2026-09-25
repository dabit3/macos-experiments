import AppKit
import Combine
import Foundation
import NightjarCore
import UniformTypeIdentifiers

@MainActor
final class ShowStore: ObservableObject {
  @Published private(set) var show: Show
  @Published var selectedFixture = 0
  @Published var selectedCue: UUID?
  @Published var isAiming = false
  @Published var showHaze = true
  @Published var camera = StageCamera.perspective
  @Published private(set) var playing = false
  @Published private(set) var clock: CueClock?
  @Published private(set) var status = "Ready. Make a little atmosphere."
  @Published private(set) var canUndo = false
  @Published var error: String?
  @Published var currentFile: URL?
  private var history: [Show] = []
  private var lastEditKey = ""
  private var lastEditTime: TimeInterval = 0
  private var saveWork: DispatchWorkItem?
  private var timer: AnyCancellable?
  private var sourceLook: [Fixture] = []
  private var lastTick = ProcessInfo.processInfo.systemUptime
  private let autosaveURL: URL

  init() {
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Nightjar", isDirectory: true)
    autosaveURL = directory.appendingPathComponent("Autosave.nightjar")
    var initial = Show.sample
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: autosaveURL.path) {
        initial = try Show.decode(Data(contentsOf: autosaveURL))
        status = "Restored your last session."
      }
    } catch {
      self.error = "Your previous session could not be restored. \(error.localizedDescription)"
    }
    show = initial
    selectedCue = initial.cues.first?.id
    timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
      .autoconnect().sink { [weak self] _ in self?.tick() }
  }

  var fixture: Fixture { show.live.first { $0.id == selectedFixture } ?? show.live[0] }
  var cue: Cue? { show.cues.first { $0.id == selectedCue } }
  var cueIndex: Int? { show.cues.firstIndex { $0.id == selectedCue } }
  var locked: Bool { clock != nil }
  var liveIsRecorded: Bool { cue?.fixtures == show.live }
  var totalDuration: Double { show.cues.reduce(0) { $0 + $1.fade + $1.hold } }

  private func remember(_ key: String) {
    let now = ProcessInfo.processInfo.systemUptime
    if lastEditKey != key || now - lastEditTime > 0.6 {
      history.append(show)
      if history.count > 100 { history.removeFirst() }
    }
    lastEditKey = key
    lastEditTime = now
    canUndo = !history.isEmpty
  }

  private func changed(_ message: String? = nil) {
    if let message { status = message }
    saveWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.persist() }
    saveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
  }

  func persist() {
    do { try show.encoded().write(to: autosaveURL, options: .atomic) } catch {
      self.error = "Autosave failed: \(error.localizedDescription)"
    }
  }

  func editFixture(_ key: String, _ change: (inout Fixture) -> Void) {
    guard !locked, let index = show.live.firstIndex(where: { $0.id == selectedFixture }) else {
      return
    }
    remember("fixture-\(selectedFixture)-\(key)")
    change(&show.live[index])
    changed("Live look changed · record a new cue or update the selected one.")
  }

  func aim(at point: Vector3) {
    editFixture("aim") {
      $0.target = Vector3(min(6, max(-6, point.x)), 0, min(4, max(-3.5, point.z)))
    }
    isAiming = false
  }

  func renameShow(_ name: String) {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    remember("title")
    show.name = String(name.prefix(120))
    changed()
  }

  func editCue(name: String? = nil, fade: Double? = nil, hold: Double? = nil) {
    guard !locked, let index = cueIndex else { return }
    remember("cue-\(show.cues[index].id)")
    if let name, !name.isEmpty { show.cues[index].name = String(name.prefix(120)) }
    if let fade { show.cues[index].fade = min(30, max(0.2, fade)) }
    if let hold { show.cues[index].hold = min(60, max(0, hold)) }
    changed()
  }

  func selectCue(_ id: UUID) {
    guard let cue = show.cues.first(where: { $0.id == id }) else { return }
    stop()
    remember("load-\(id)")
    selectedCue = id
    show.live = cue.fixtures
    changed("On stage: \(cue.name)")
  }

  func recordCue() {
    guard !locked, show.cues.count < 100 else { return }
    remember(UUID().uuidString)
    let cue = Cue(name: "Look \(show.cues.count + 1)", fixtures: show.live)
    show.cues.append(cue)
    selectedCue = cue.id
    changed("Recorded \(cue.name). Give it a name in the cue editor.")
  }

  func updateCue() {
    guard !locked, let index = cueIndex else { return }
    remember(UUID().uuidString)
    show.cues[index].fixtures = show.live
    changed("Updated \(show.cues[index].name) with the live look.")
  }

  func moveCue(_ offset: Int) {
    guard !locked, let index = cueIndex, show.cues.indices.contains(index + offset) else { return }
    remember(UUID().uuidString)
    show.cues.swapAt(index, index + offset)
    changed("Cue moved to position \(index + offset + 1).")
  }

  func deleteCue() {
    guard !locked, let index = cueIndex else { return }
    remember(UUID().uuidString)
    show.cues.remove(at: index)
    selectedCue = show.cues.isEmpty ? nil : show.cues[min(index, show.cues.count - 1)].id
    changed("Cue removed. Undo restores it.")
  }

  func undo() {
    guard !locked, let previous = history.popLast() else { return }
    show = previous
    if !show.cues.contains(where: { $0.id == selectedCue }) { selectedCue = show.cues.first?.id }
    canUndo = !history.isEmpty
    lastEditKey = ""
    changed("Undid the last edit.")
  }

  func reset() {
    stop()
    remember(UUID().uuidString)
    show = .sample
    selectedCue = show.cues.first?.id
    currentFile = nil
    changed("Sample show restored. Your previous show is available with Undo.")
  }

  func togglePlayback() {
    if playing {
      playing = false
      status = "Paused · resume or stop to edit."
    } else if clock != nil {
      playing = true
      lastTick = ProcessInfo.processInfo.systemUptime
    } else if let index = cueIndex ?? show.cues.indices.first {
      remember(UUID().uuidString)
      startCue(at: index)
    }
  }

  private func startCue(at index: Int) {
    let cue = show.cues[index]
    selectedCue = cue.id
    sourceLook = show.live
    clock = CueClock(fade: cue.fade, hold: cue.hold)
    isAiming = false
    playing = true
    lastTick = ProcessInfo.processInfo.systemUptime
    status = "Playing · \(cue.name)"
  }

  func stop() {
    let wasActive = locked
    playing = false
    clock = nil
    if wasActive { changed("Transport stopped. The current light stays on stage.") }
  }

  private func tick() {
    guard playing, var current = clock, let index = cueIndex else { return }
    let now = ProcessInfo.processInfo.systemUptime
    current.advance(now - lastTick)
    lastTick = now
    clock = current
    show.live = Fixture.crossfade(
      from: sourceLook, to: show.cues[index].fixtures, progress: current.progress)
    if current.phase == .finished {
      if index + 1 < show.cues.count {
        startCue(at: index + 1)
      } else {
        playing = false
        clock = nil
        changed("Sequence complete · the final look stays on stage.")
      }
    }
  }

  func openShow() {
    let panel = NSOpenPanel()
    panel.title = "Open a Nightjar show"
    panel.allowedContentTypes = [.nightjarShow, .json]
    panel.allowsOtherFileTypes = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let imported = try Show.decode(Data(contentsOf: url))
      stop()
      remember(UUID().uuidString)
      show = imported
      selectedCue = imported.cues.first?.id
      currentFile = url
      changed("Opened \(url.lastPathComponent)")
    } catch {
      self.error =
        "The show was not opened. Your current show is unchanged.\n\(error.localizedDescription)"
    }
  }

  func saveShow(forcePanel: Bool = false) {
    stop()
    var destination = currentFile
    if destination == nil || forcePanel {
      let panel = NSSavePanel()
      panel.title = "Save your Nightjar show"
      panel.allowedContentTypes = [.nightjarShow]
      panel.isExtensionHidden = false
      panel.canSelectHiddenExtension = false
      panel.nameFieldStringValue = "\(show.name).nightjar"
      guard panel.runModal() == .OK, let url = panel.url else { return }
      destination = url
    }
    guard let destination else { return }
    do {
      try show.encoded().write(to: destination, options: .atomic)
      currentFile = destination
      status = "Saved \(destination.lastPathComponent)"
    } catch { self.error = "Save failed: \(error.localizedDescription)" }
  }

  func exportCueSheet() {
    let panel = NSSavePanel()
    panel.title = "Export a cue sheet"
    panel.allowedContentTypes = [.commaSeparatedText]
    panel.isExtensionHidden = false
    panel.canSelectHiddenExtension = false
    panel.nameFieldStringValue = "\(show.name) — cue sheet.csv"
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try show.cueSheet.write(to: destination, atomically: true, encoding: .utf8)
      status = "Exported \(show.cues.count) cues × 6 fixtures to \(destination.lastPathComponent)"
    } catch { self.error = "Export failed: \(error.localizedDescription)" }
  }
}

extension UTType {
  fileprivate static let nightjarShow = UTType(
    exportedAs: "studio.nightjar.show", conformingTo: .json)
}

enum StageCamera: String, CaseIterable {
  case perspective = "Audience"
  case front = "Front"
  case overhead = "Plot"
}
