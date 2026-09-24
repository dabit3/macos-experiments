import AVFoundation
import SwiftUI

@MainActor
final class TapeStore: ObservableObject {
  @Published private(set) var archive: TapeArchive
  @Published var selectedDrum: Drum = .kick
  @Published var isPlaying = false
  @Published var currentStep = -1
  @Published var level: Float = 0
  @Published var errorMessage: String?
  @Published var notice: String?
  private let repository: TapeRepository
  let audio = TapeAudio()
  private var noticeTask: Task<Void, Never>?
  private var tapTimes: [Date] = []

  var pattern: Pattern { archive.current }

  init(repository: TapeRepository? = nil) {
    let directory = URL.applicationSupportDirectory.appendingPathComponent("TapeDeck")
    self.repository =
      repository ?? TapeRepository(url: directory.appendingPathComponent("tapes.json"))
    do {
      archive = try self.repository.load()
    } catch {
      archive = TapeArchive()
      errorMessage = "Your tape file could not be read. The original file is still on this device."
    }
  }

  func edit(_ change: (inout Pattern) -> Void) {
    var updated = pattern
    change(&updated)
    archive.current = updated.normalized()
    audio.control.update(pattern: pattern)
    persist()
  }

  func toggleStep(_ step: Int) {
    edit { $0.steps[selectedDrum.rawValue][step].toggle() }
    UISelectionFeedbackGenerator().selectionChanged()
  }

  func toggleTransport() {
    if isPlaying {
      stop()
    } else {
      do {
        try audio.start(pattern: pattern)
        isPlaying = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
      } catch {
        errorMessage =
          "No audio output is available. Connect an audio device, then try Play again. You can still edit and save your tapes."
      }
    }
  }

  func stop() {
    audio.stop()
    isPlaying = false
    currentStep = -1
    level = 0
  }

  func tick() {
    guard isPlaying else { return }
    let (step, peak) = audio.control.meter()
    currentStep = step
    level = max(peak, level * 0.72)
  }

  func load(_ pattern: Pattern) {
    let wasPlaying = isPlaying
    stop()
    archive.current = pattern.normalized()
    persist()
    if wasPlaying { toggleTransport() }
    announce("Loaded · \(pattern.name)")
  }

  func save(name: String) {
    let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    guard !title.isEmpty else { return }
    archive.current.name = title
    archive.tapes.insert(SavedTape(pattern: pattern), at: 0)
    persist()
    announce("Saved · \(title)")
  }

  func delete(id: UUID) {
    archive.tapes.removeAll { $0.id == id }
    persist()
  }

  func clearTrack() {
    edit { $0.steps[selectedDrum.rawValue] = Array(repeating: false, count: 16) }
    announce("\(selectedDrum.name) cleared")
  }

  func nudgeTempo(_ delta: Double) {
    edit { $0.tempo += delta }
  }

  func nudgeSwing(_ delta: Double) {
    edit { $0.swing = (($0.swing + delta) * 100).rounded() / 100 }
  }

  /// Averages the last few taps into a tempo. Returns false if more taps are needed.
  @discardableResult
  func tapTempo(at time: Date = .now) -> Bool {
    if let last = tapTimes.last, time.timeIntervalSince(last) > 2 { tapTimes.removeAll() }
    tapTimes.append(time)
    tapTimes = tapTimes.suffix(5)
    guard tapTimes.count >= 2 else { return false }
    let interval = tapTimes.last!.timeIntervalSince(tapTimes.first!) / Double(tapTimes.count - 1)
    edit { $0.tempo = 60 / interval }
    return true
  }

  func announce(_ message: String) {
    noticeTask?.cancel()
    notice = message
    noticeTask = Task {
      try? await Task.sleep(for: .seconds(2.5))
      guard !Task.isCancelled else { return }
      notice = nil
    }
  }

  private func persist() {
    do {
      try repository.save(archive)
    } catch {
      errorMessage =
        "This change could not be saved to your device. Please free some space and try again."
    }
  }
}
