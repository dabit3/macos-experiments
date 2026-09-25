import AVFoundation
import Combine
import SwiftUI
import UIKit

struct SavedState: Codable {
  var routines: [Routine]
  var history: [WorkoutRecord]
  var session: Session?
  var muted: Bool
}

@MainActor
final class CoachStore: ObservableObject {
  @Published var routines: [Routine] = Routine.examples
  @Published var history: [WorkoutRecord] = []
  @Published var session: Session?
  @Published var muted = false
  @Published var now = Date()
  @Published var saveError: String?
  private let defaults: UserDefaults
  private var timer: AnyCancellable?
  private let cues = CuePlayer()

  init(defaults: UserDefaults = .standard, ticking: Bool = true) {
    self.defaults = defaults
    if let data = defaults.data(forKey: "cadence.state.v1") {
      do {
        let state = try JSONDecoder().decode(SavedState.self, from: data)
        routines = state.routines
        history = state.history
        session = state.session
        muted = state.muted
      } catch {
        saveError = "Saved data couldn’t be read. Your original data is still on this device."
      }
    }
    if ticking {
      tick()
      timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
        .sink { [weak self] _ in self?.tick() }
    }
  }

  func save() {
    do {
      let state = SavedState(routines: routines, history: history, session: session, muted: muted)
      defaults.set(try JSONEncoder().encode(state), forKey: "cadence.state.v1")
    } catch {
      saveError = "Your changes couldn’t be saved. Please try again."
    }
  }
  func upsert(_ routine: Routine) {
    guard routine.isValid else { return }
    var clean = routine
    clean.name = String(clean.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    clean.isExample = false
    if let index = routines.firstIndex(where: { $0.id == routine.id }) {
      routines[index] = clean
    } else {
      routines.append(clean)
    }
    save()
  }
  func delete(_ routine: Routine) {
    routines.removeAll { $0.id == routine.id }
    save()
  }
  func start(_ routine: Routine) {
    guard routine.isValid else { return }
    now = Date()
    session = Session(routine: routine, now: now)
    cue()
    save()
  }
  func togglePause() {
    now = Date()
    if session?.paused == true { session?.resume(at: now) } else { session?.pause(at: now) }
    finishIfNeeded()
    save()
  }
  func skip() {
    now = Date()
    session?.skip(at: now)
    cue()
    finishIfNeeded()
    save()
  }
  func end() {
    now = Date()
    session?.end(at: now)
    finishIfNeeded()
    save()
  }
  func closeSession() {
    session = nil
    save()
  }
  func toggleMute() {
    muted.toggle()
    save()
  }
  func tick() {
    now = Date()
    let oldIndex = session?.index
    session?.synchronize(at: now)
    if session?.index != oldIndex {
      if UIApplication.shared.applicationState == .active { cue() }
      finishIfNeeded()
      save()
    }
  }
  private func finishIfNeeded() {
    guard let session, session.finished, !history.contains(where: { $0.id == session.id }) else {
      return
    }
    history.insert(session.record, at: 0)
  }
  private func cue() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    if !muted { cues.play(rest: session?.phase.kind == .rest) }
  }
}

@MainActor
final class CuePlayer {
  private var player: AVAudioPlayer?
  func play(rest: Bool) {
    let sampleRate = 22_050
    let count = sampleRate / 4
    let frequency = rest ? 440.0 : 880.0
    var pcm = Data()
    for i in 0..<count {
      let envelope = min(1, Double(i) / 160) * max(0, 1 - Double(i) / Double(count))
      var sample = Int16(
        sin(Double(i) * 2 * .pi * frequency / Double(sampleRate)) * 12_000 * envelope
      ).littleEndian
      withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
    }
    var wav = Data()
    func text(_ value: String) { wav.append(contentsOf: value.utf8) }
    func number<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
    }
    text("RIFF")
    number(UInt32(36 + pcm.count))
    text("WAVEfmt ")
    number(UInt32(16))
    number(UInt16(1))
    number(UInt16(1))
    number(UInt32(sampleRate))
    number(UInt32(sampleRate * 2))
    number(UInt16(2))
    number(UInt16(16))
    text("data")
    number(UInt32(pcm.count))
    wav.append(pcm)
    do {
      try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
      player = try AVAudioPlayer(data: wav)
      player?.play()
    } catch {
      // Visual phase labels remain available when audio is unavailable.
    }
  }
}
