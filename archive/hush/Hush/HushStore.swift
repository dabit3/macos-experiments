import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

@MainActor
final class HushStore: ObservableObject {
  @Published var preferences: Preferences {
    didSet { preferences.save(to: defaults) }
  }
  @Published var isPlaying = false
  @Published var isMuted = false
  @Published var countdown: SleepCountdown?
  @Published var timerFinished = false
  @Published var now = Date()
  @Published var fadeStarted: Date?
  @Published var message: String?
  @Published var error: String?
  private let defaults: UserDefaults
  private let audio: AudioPlayback
  private var ticker: AnyCancellable?
  private var started: Date?
  private var currentGain = 0.0

  init(defaults: UserDefaults = .standard, audio: AudioPlayback? = nil) {
    self.defaults = defaults
    self.audio = audio ?? SoundEngine()
    preferences = Preferences.load(from: defaults)
    ticker = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect().sink { [weak self] date in self?.tick(date) }
    if audio == nil {
      MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] _ in
        Task { @MainActor in self?.play() }
        return .success
      }
      MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] _ in
        Task { @MainActor in self?.pause() }
        return .success
      }
    }
  }

  var mix: Mix { preferences.mix }
  var isEdited: Bool {
    let original = (SavedScene.originals + preferences.scenes)
      .first { $0.name == preferences.sceneName }
    return original.map { $0.mix != mix } ?? false
  }
  var timerLabel: String {
    guard let countdown else { return "Sleep timer" }
    let seconds = Int(ceil(countdown.remaining(at: now)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
  var isFading: Bool {
    fadeStarted != nil || (countdown?.gain(at: now) ?? 1) < 1
  }
  var fadeProgress: Double { 1 - currentGain }

  func haptic() {
    if preferences.haptics { UISelectionFeedbackGenerator().selectionChanged() }
  }

  func setLevel(_ layer: Layer, _ value: Double) {
    preferences.mix.set(layer, to: value)
    message = nil
  }

  func play() {
    guard mix.activeCount > 0, mix.master > 0 else {
      message = "Raise a sound and the master volume to begin."
      return
    }
    do {
      audio.update(mix: mix, gain: 0)
      try audio.start()
      isPlaying = true
      isMuted = false
      fadeStarted = nil
      started = Date()
      message = nil
      timerFinished = false
      updateNowPlaying()
      haptic()
    } catch {
      self.error =
        "Reconnect your headphones or choose an audio output in Control Center, then retry."
    }
  }

  func pause() {
    audio.stop()
    isPlaying = false
    fadeStarted = nil
    started = nil
    currentGain = 0
    updateNowPlaying()
  }

  func togglePlayback() {
    if isPlaying { pause() } else { play() }
  }

  func tick(_ date: Date) {
    now = date
    if let countdown, countdown.remaining(at: date) <= 0 {
      pause()
      self.countdown = nil
      timerFinished = true
      message = "The night is yours. Timer complete."
    }
    guard isPlaying else { return }
    let entrance = min(1, max(0, date.timeIntervalSince(started ?? date) / 1.2))
    var gain = min(entrance, countdown?.gain(at: date) ?? 1)
    if let fadeStarted {
      gain = min(gain, max(0, 1 - date.timeIntervalSince(fadeStarted) / preferences.fadeSeconds))
      if gain <= 0 {
        pause()
        countdown = nil
        message = "Faded into quiet."
        return
      }
    }
    currentGain = gain
    audio.update(mix: mix, gain: isMuted ? 0 : gain)
  }

  func startTimer(seconds: Double) {
    if !isPlaying { play() }
    guard isPlaying else { return }
    fadeStarted = nil
    countdown = SleepCountdown(now: Date(), duration: seconds)
    timerFinished = false
    message = nil
    haptic()
  }

  func fadeOut() {
    guard isPlaying else { return }
    fadeStarted = Date()
    haptic()
  }

  func recall(_ scene: SavedScene) {
    preferences.mix = scene.mix
    preferences.sceneName = scene.name
    message = nil
    updateNowPlaying()
    haptic()
  }

  func saveScene(name: String) {
    let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    guard !clean.isEmpty else { return }
    preferences.scenes.insert(
      SavedScene(name: clean, note: "\(mix.activeCount) layers · made by you", mix: mix), at: 0)
    preferences.sceneName = clean
    message = "Saved to your scenes."
    updateNowPlaying()
    haptic()
  }

  func resetMix() {
    preferences.mix = Mix(levels: [0, 0, 0, 0], master: mix.master)
    preferences.sceneName = "Your quiet place"
    countdown = nil
    timerFinished = false
    pause()
    message = "A blank canvas. Bring a sound in."
  }

  private func updateNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: preferences.sceneName,
      MPMediaItemPropertyArtist: "Hush · Original soundscape",
      MPNowPlayingInfoPropertyIsLiveStream: true,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
    ]
  }
}
