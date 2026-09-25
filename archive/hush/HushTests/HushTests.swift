import XCTest

@testable import Hush

final class HushTests: XCTestCase {
  func testGainBoundsAndCorruptPersistedLevels() {
    var mix = Mix()
    mix.set(.rain, to: -10)
    mix.set(.ocean, to: 5)
    mix.set(.wind, to: .nan)
    XCTAssertEqual(mix.levels, [0, 1, 0, 0])
    XCTAssertEqual(
      Mix(levels: [2, -.infinity], master: -2).sanitized(), Mix(levels: [1, 0, 0, 0], master: 0))
  }

  func testTimerFadeBoundaryAndExpiredClock() {
    let now = Date(timeIntervalSince1970: 1000)
    let timer = SleepCountdown(now: now, duration: 30)
    XCTAssertEqual(timer.gain(at: now.addingTimeInterval(19)), 1)
    XCTAssertEqual(timer.gain(at: now.addingTimeInterval(25)), 0.5)
    XCTAssertEqual(timer.gain(at: now.addingTimeInterval(30)), 0)
    XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(90)), 0)
    let short = SleepCountdown(now: now, duration: -1, fade: 10)
    XCTAssertEqual(short.duration, 1)
    XCTAssertEqual(short.gain(at: now), 1)
  }

  func testPreferencesRoundTripAndCorruptDataFallback() throws {
    let suite = "hush.tests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    var prefs = Preferences()
    prefs.mix = Mix(levels: [0.2, 0.7, 0.1, 0], master: 0.5)
    prefs.sceneName = "My shore"
    prefs.scenes = [SavedScene(name: "My shore", note: "Mine", mix: prefs.mix)]
    prefs.fadeSeconds = 15
    prefs.haptics = false
    prefs.save(to: defaults)
    let restored = Preferences.load(from: defaults)
    XCTAssertEqual(restored.mix, prefs.mix)
    XCTAssertEqual(restored.scenes, prefs.scenes)
    XCTAssertEqual(restored.sceneName, "My shore")
    XCTAssertEqual(restored.fadeSeconds, 15)
    XCTAssertFalse(restored.haptics)
    defaults.set(Data([0, 1, 2]), forKey: "hush.preferences")
    XCTAssertEqual(Preferences.load(from: defaults).mix, Mix())
  }

  func testAllSoundsAreDeterministicAudibleBoundedAndDistinct() {
    var signatures: [Double] = []
    for layer in Layer.allCases {
      let signal = Synthesis.samples(for: layer, seconds: 1)
      XCTAssertEqual(signal.count, 22_050)
      XCTAssertEqual(signal, Synthesis.samples(for: layer, seconds: 1))
      XCTAssertTrue(signal.allSatisfy { $0.isFinite && abs($0) <= 0.681 })
      let rms = sqrt(signal.reduce(0.0) { $0 + Double($1 * $1) } / Double(signal.count))
      XCTAssertGreaterThan(rms, 0.015, "\(layer) is too quiet")
      XCTAssertLessThan(rms, 0.4)
      signatures.append(rms)
    }
    XCTAssertEqual(Set(signatures).count, 4)
  }

  @MainActor
  func testSceneSaveRecallRenameAndResetPersistence() throws {
    let suite = "hush.store.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = HushStore(defaults: defaults)
    store.setLevel(.rain, 0.3)
    store.saveScene(name: "  My night  ")
    let scene = try XCTUnwrap(store.preferences.scenes.first)
    XCTAssertEqual(scene.name, "My night")
    store.resetMix()
    XCTAssertEqual(store.mix.activeCount, 0)
    XCTAssertEqual(store.preferences.scenes.count, 1)
    store.recall(scene)
    XCTAssertEqual(store.mix.level(.rain), 0.3)
    store.saveScene(name: "   ")
    XCTAssertEqual(store.preferences.scenes.count, 1)
    let restored = HushStore(defaults: defaults)
    XCTAssertEqual(restored.preferences.sceneName, "My night")
    XCTAssertFalse(restored.isPlaying)
    XCTAssertNil(restored.countdown)
  }

  @MainActor
  func testPlaybackMuteTimerCompletionAndManualFade() throws {
    let suite = "hush.control.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = TestAudio()
    let store = HushStore(defaults: defaults, audio: audio)
    store.play()
    store.tick(Date().addingTimeInterval(2))
    XCTAssertTrue(store.isPlaying)
    XCTAssertEqual(audio.gain, 1)
    store.isMuted = true
    store.tick(Date().addingTimeInterval(3))
    XCTAssertEqual(audio.gain, 0)
    store.isMuted = false
    store.startTimer(seconds: 30)
    let deadline = try XCTUnwrap(store.countdown).end
    store.tick(deadline.addingTimeInterval(-5))
    XCTAssertEqual(audio.gain, 0.5, accuracy: 0.001)
    store.tick(deadline)
    XCTAssertFalse(store.isPlaying)
    XCTAssertTrue(store.timerFinished)
    XCTAssertNil(store.countdown)
    XCTAssertFalse(audio.running)
    store.play()
    XCTAssertFalse(store.timerFinished)
    store.preferences.fadeSeconds = 3
    store.fadeOut()
    store.tick(try XCTUnwrap(store.fadeStarted).addingTimeInterval(4))
    XCTAssertFalse(store.isPlaying)
    store.resetMix()
    store.play()
    XCTAssertFalse(store.isPlaying)
    XCTAssertNotNil(store.message)
  }

  @MainActor
  func testEditingRetainsSceneIdentityAndReportsAudioFailure() throws {
    let suite = "hush.errors.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = TestAudio()
    audio.shouldFail = true
    let store = HushStore(defaults: defaults, audio: audio)
    store.setLevel(.rain, 0.2)
    XCTAssertEqual(store.preferences.sceneName, "Moonlit shore")
    XCTAssertTrue(store.isEdited)
    store.play()
    XCTAssertNotNil(store.error)
    XCTAssertFalse(store.isPlaying)
  }
}

@MainActor
private final class TestAudio: AudioPlayback {
  enum Failure: Error { case unavailable }
  var gain = 0.0
  var running = false
  var shouldFail = false
  func start() throws {
    if shouldFail { throw Failure.unavailable }
    running = true
  }
  func update(mix: Mix, gain: Double) { self.gain = gain }
  func stop() { running = false }
}
