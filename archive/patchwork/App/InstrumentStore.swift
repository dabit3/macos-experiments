import Combine
import Foundation

@MainActor
final class InstrumentStore: ObservableObject {
  @Published var patch = Patch.warm
  @Published var saved: [Patch] = []
  @Published var selectedPort: Module?
  @Published var hold = false
  @Published var telemetry = AudioTelemetry()
  @Published var notice = "Tap a key to wake the circuit."
  @Published var isError = false
  @Published var engineReady = false
  @Published var activeNote = ""
  @Published var shareURL: URL?
  @Published var undoHistory: [Patch] = []

  let audio = AudioHost()
  private var trigger: UInt64 = 0
  private var timer: Timer?
  private var lastNoteTime = Date.distantPast
  private let libraryURL: URL

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    libraryURL = documents.appendingPathComponent("Patchwork-library.json")
    if FileManager.default.fileExists(atPath: libraryURL.path) {
      do {
        let library = try JSONDecoder().decode(
          PatchLibrary.self, from: Data(contentsOf: libraryURL)
        ).validated()
        patch = library.current
        saved = library.saved
        notice = "Your last circuit is ready. Tap a key to play."
      } catch {
        notice = "Saved library could not be read. A fresh circuit is ready; save to recover."
        isError = true
      }
    }
    sync()
    timer = Timer.scheduledTimer(withTimeInterval: 1 / 20, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.telemetry = self.audio.bridge.read()
        if Date().timeIntervalSince(self.lastNoteTime) > 0.35 { self.activeNote = "" }
      }
    }
  }

  func wake() {
    do {
      try audio.start()
      engineReady = true
    } catch {
      engineReady = false
      announce(
        "Audio could not start. Tap a key to retry. \(error.localizedDescription)", error: true)
    }
  }

  func suspend() {
    hold = false
    sync()
    audio.pause()
    engineReady = false
    persist()
  }

  func sync() { audio.bridge.update(SynthControl(patch: patch, hold: hold, trigger: trigger)) }

  func announce(_ text: String, error: Bool = false) {
    notice = text
    isError = error
  }

  func checkpoint() {
    if undoHistory.last != patch { undoHistory.append(patch) }
    if undoHistory.count > 30 { undoHistory.removeFirst() }
  }

  func setParameter(_ keyPath: WritableKeyPath<Patch, Double>, _ value: Double) {
    patch[keyPath: keyPath] = value
    sync()
  }

  func finishParameter() { persist() }

  func setShape(_ shape: WaveShape) {
    checkpoint()
    patch.shape = shape
    sync()
    persist()
  }

  func port(_ module: Module, input: Bool) {
    guard input else {
      selectedPort = selectedPort == module ? nil : module
      announce(
        selectedPort == nil
          ? "Connection cancelled." : "\(module.short) selected. Tap an IN socket.")
      return
    }
    guard let source = selectedPort else {
      announce("Start at an OUT socket, then tap this IN.", error: true)
      return
    }
    do {
      var next = patch
      try next.connect(source, to: module)
      checkpoint()
      patch = next
      selectedPort = nil
      sync()
      persist()
      announce(
        "\(source.short) → \(module.short) connected. \(patch.signalPath.isEmpty ? "Keep going to OUT." : "Signal path complete.")"
      )
    } catch {
      selectedPort = nil
      announce(error.localizedDescription, error: true)
    }
  }

  func remove(_ cable: Cable) {
    checkpoint()
    patch.cables.removeAll { $0.id == cable.id }
    sync()
    persist()
    announce("\(cable.source.short) → \(cable.destination.short) removed.")
  }

  func undo() {
    guard let previous = undoHistory.popLast() else { return }
    patch = previous
    selectedPort = nil
    sync()
    persist()
    announce("Previous circuit restored.")
  }

  func load(_ next: Patch) {
    checkpoint()
    patch = next
    selectedPort = nil
    hold = false
    sync()
    persist()
    announce("\(next.name) loaded. Tap a key to play.")
  }

  func save(name: String) -> Bool {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= 40 else {
      announce("Give your patch a name between 1 and 40 characters.", error: true)
      return false
    }
    checkpoint()
    patch.name = name
    patch.subtitle = "Your own little circuit."
    if let index = saved.firstIndex(where: { $0.name == name }) {
      patch.id = saved[index].id
      saved[index] = patch
    } else {
      patch.id = UUID()
      saved.append(patch)
    }
    let success = persist()
    if success { announce("“\(name)” saved to your patch library.") }
    return success
  }

  func note(_ label: String, frequency: Double) {
    wake()
    patch.frequency = frequency
    trigger &+= 1
    activeNote = label
    lastNoteTime = Date()
    sync()
    persist()
    announce(
      patch.signalPath.isEmpty
        ? "No route to output. Connect your circuit first." : "\(label) · \(Int(frequency)) Hz")
  }

  func toggleHold() {
    wake()
    hold.toggle()
    sync()
    announce(hold ? "Hold is on. Shape the sound with the knobs." : "Hold released.")
  }

  func export() {
    guard !patch.signalPath.isEmpty else {
      announce("Connect a signal path to OUT before exporting audio.", error: true)
      return
    }
    do {
      let url = libraryURL.deletingLastPathComponent().appendingPathComponent(
        "Patchwork-render.wav")
      try audio.export(patch, to: url)
      shareURL = url
      announce("Rendered 3 seconds · 48 kHz WAV · saved in Documents.")
    } catch {
      announce("Export failed: \(error.localizedDescription)", error: true)
    }
  }

  @discardableResult
  func persist() -> Bool {
    do {
      let library = PatchLibrary(current: patch, saved: saved)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(library).write(to: libraryURL, options: .atomic)
      return true
    } catch {
      announce("Could not save this patch: \(error.localizedDescription)", error: true)
      return false
    }
  }
}
