import AVFoundation
import Combine
import SwiftUI

@MainActor
final class InstrumentModel: ObservableObject {
  @Published private(set) var pattern: Pattern
  @Published private(set) var saved: [Pattern] = []
  @Published var selected = Drum.kick
  @Published private(set) var playing = false
  @Published private(set) var activeStep = -1
  @Published private(set) var history: [Pattern] = []
  @Published var error: String?
  @Published var notice = "READY WHEN YOU ARE"
  @Published var flashed: Drum?
  @Published var exportURL: URL?

  private let audio: InstrumentAudio
  private let storage: URL
  private var clock: AnyCancellable?
  private var interruption: AnyCancellable?

  init() {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    storage = documents.appendingPathComponent("groovebox-library.json")
    var initial = Pattern.presets[0]
    var bank: [Pattern] = []
    var loadError: String?
    if FileManager.default.fileExists(atPath: storage.path) {
      do {
        let state = try LibraryState.read(from: storage)
        initial = state.current
        bank = state.saved
      } catch {
        loadError = "The saved library could not be read. A factory pattern is ready to play."
        let backup = documents.appendingPathComponent("groovebox-library-recovery.json")
        try? FileManager.default.copyItem(at: storage, to: backup)
      }
    }
    pattern = initial
    saved = bank
    audio = InstrumentAudio(pattern: initial)
    error = loadError
    clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
      .sink { [weak self] _ in
        guard let self else { return }
        self.activeStep = self.audio.step
      }
    interruption = NotificationCenter.default.publisher(
      for: AVAudioSession.interruptionNotification
    ).sink { [weak self] _ in
      Task { @MainActor in
        self?.stop()
        self?.notice = "AUDIO PAUSED · TAP PLAY TO RESUME"
      }
    }
  }

  func edit(_ change: (inout Pattern) -> Void) {
    let before = pattern
    var next = before
    change(&next)
    guard next.isValid && next != before else { return }
    history.append(before)
    if history.count > 50 { history.removeFirst() }
    pattern = next
    audio.update(pattern)
    persist()
  }

  func toggleStep(_ index: Int) {
    edit { $0.steps[selected.rawValue][index].toggle() }
  }

  func undo() {
    guard let prior = history.popLast() else { return }
    pattern = prior
    audio.update(pattern)
    persist()
    notice = "LAST CHANGE UNDONE"
  }

  func togglePlayback() {
    if playing {
      stop()
      return
    }
    do {
      try audio.start()
      playing = true
      notice = "SEQUENCER RUNNING"
    } catch { self.error = "Audio could not start: \(error.localizedDescription)" }
  }

  func stop() {
    audio.stop()
    playing = false
    activeStep = -1
    notice = "TRANSPORT STOPPED"
  }

  func hit(_ drum: Drum) {
    do {
      try audio.hit(drum)
      flashed = drum
      Task {
        try? await Task.sleep(for: .milliseconds(140))
        if flashed == drum { flashed = nil }
      }
    } catch { self.error = "The pad could not play: \(error.localizedDescription)" }
  }

  func load(_ next: Pattern) {
    stop()
    edit { $0 = next }
    notice = "LOADED · \(next.name.uppercased())"
  }

  func save(name: String) {
    let cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    guard !cleaned.isEmpty else { return }
    edit { $0.name = cleaned }
    var copy = pattern
    copy.id = UUID()
    saved.append(copy)
    persist()
    notice = "SAVED TO YOUR PATTERNS"
  }

  func delete(_ id: UUID) {
    saved.removeAll { $0.id == id }
    persist()
  }

  func clear() {
    edit { $0.steps = Array(repeating: Array(repeating: false, count: 16), count: 4) }
    notice = "EMPTY CANVAS · UNDO TO RESTORE"
  }

  func export() {
    let url = storage.deletingLastPathComponent().appendingPathComponent("Groovebox-loop.wav")
    do {
      try WaveExport.wav(WaveExport.samples(pattern: pattern)).write(to: url, options: .atomic)
      exportURL = url
      notice = "RENDERED · 2 BARS + TAIL"
    } catch { self.error = "Export failed: \(error.localizedDescription)" }
  }

  private func persist() {
    do { try LibraryState(current: pattern, saved: saved).write(to: storage) } catch {
      self.error = "Your changes could not be saved: \(error.localizedDescription)"
    }
  }
}
