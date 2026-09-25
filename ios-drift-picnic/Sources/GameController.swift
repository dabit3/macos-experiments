import AVFoundation
import Combine
import QuartzCore
import SwiftUI
import UIKit

enum GamePhase {
  case title, countdown, racing, paused, results
}

@MainActor
final class GameController: NSObject, ObservableObject {
  @Published var phase = GamePhase.title
  @Published var mode = RaceMode.picnic
  @Published var showGuide = false
  @Published var countdown = 3
  @Published var sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
  @Published var bestLap = UserDefaults.standard.double(forKey: "bestLap")
  @Published var bestCup = UserDefaults.standard.double(forKey: "bestCup")
  @Published var bestTrial = UserDefaults.standard.double(forKey: "bestTrial")
  @Published var wins = UserDefaults.standard.integer(forKey: "wins")
  /// Just-in-time control coaching shown during the first race only.
  @Published var hint = ""
  /// Seconds shaved off the mode record by the race just finished; zero when no record fell.
  @Published var improvement = 0.0
  @Published var previousRecord = 0.0
  let world = PicnicWorld()
  var race = RaceEngine()
  var reducedMotion = false
  var learnedControls: Bool { UserDefaults.standard.bool(forKey: "learnedControls") }
  private var link: CADisplayLink?
  private var previousTime = 0.0
  private var countdownTime = 0.0
  private var uiTime = 0.0
  private var showcaseTime = 0.0
  private var coachStage = UserDefaults.standard.bool(forKey: "coached") ? 99 : 0
  private var pausedPhase = GamePhase.racing
  private let audio = PicnicAudio()
  private let haptics = UIImpactFeedbackGenerator(style: .soft)

  override init() {
    super.init()
    race.steering = 0
    world.update(race: race, racing: false, reducedMotion: true)
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    self.link = link
  }

  func begin() {
    if !learnedControls {
      showGuide = true
    } else {
      start()
    }
  }

  func start() {
    UserDefaults.standard.set(true, forKey: "learnedControls")
    showGuide = false
    race = RaceEngine(mode: mode)
    countdown = 3
    countdownTime = 0
    hint = ""
    improvement = 0
    previousRecord = mode == .picnic ? bestCup : bestTrial
    phase = .countdown
    world.update(race: race, racing: true, reducedMotion: reducedMotion)
    cue(.start)
  }

  func pause() {
    guard phase == .racing || phase == .countdown else { return }
    pausedPhase = phase
    phase = .paused
    race.steering = 0
    race.releaseDrift()
  }

  func resume() {
    previousTime = 0
    phase = pausedPhase
  }

  func home() {
    phase = .title
    showGuide = false
    race.steering = 0
    race.releaseDrift()
    race = RaceEngine(mode: .picnic)
    world.update(race: race, racing: false, reducedMotion: reducedMotion, showcase: showcaseTime)
  }

  func toggleSound() {
    sound.toggle()
    UserDefaults.standard.set(sound, forKey: "sound")
    if sound { cue(.pickup) }
  }

  func steer(_ value: Double) {
    guard phase == .racing else { return }
    race.steering = value
  }

  func drift() {
    guard phase == .racing else { return }
    if race.drifting {
      let old = race.driftBoosts
      race.releaseDrift()
      if race.driftBoosts > old { cue(.boost) }
    } else {
      race.drifting = true
      haptics.impactOccurred(intensity: 0.5)
    }
    objectWillChange.send()
  }

  func item() {
    guard phase == .racing, race.hasItem else { return }
    race.useItem()
    cue(.boost)
    objectWillChange.send()
  }

  private func cue(_ cue: PicnicAudio.Cue) {
    if sound { audio.play(cue) }
    haptics.impactOccurred(intensity: 0.7)
  }

  @objc private func tick(_ display: CADisplayLink) {
    let delta = previousTime == 0 ? 1.0 / 60 : min(display.timestamp - previousTime, 1.0 / 30)
    previousTime = display.timestamp
    if phase == .countdown {
      countdownTime += delta
      let next = max(0, 3 - Int(countdownTime))
      if next != countdown {
        countdown = next
        cue(.start)
      }
      if countdownTime >= 3.3 {
        phase = .racing
        race.notify("LET’S PICNIC!")
      }
    }
    if phase == .racing {
      let pickups = race.itemsCollected
      let laps = race.player.tracker.laps
      race.step(delta)
      if race.itemsCollected > pickups { cue(.pickup) }
      if race.player.tracker.laps > laps { lapCompleted() }
      coach()
      if race.finished { finish() }
    }
    if phase == .racing || phase == .countdown {
      world.update(race: race, racing: true, reducedMotion: reducedMotion)
    } else if phase == .title {
      // Attract mode: the field circles the picnic on its own while the camera orbits.
      if race.finished { race = RaceEngine(mode: .picnic) }
      race.step(delta)
      if !reducedMotion { showcaseTime += delta }
      world.update(race: race, racing: false, reducedMotion: reducedMotion, showcase: showcaseTime)
    }
    uiTime += delta
    if uiTime > 1.0 / 15 {
      if phase == .racing { objectWillChange.send() }
      uiTime = 0
    }
  }

  private func lapCompleted() {
    cue(.start)
    haptics.impactOccurred(intensity: 1)
    guard let lap = race.player.lapTimes.last else { return }
    let laps = race.player.tracker.laps
    var message = (laps == 2 ? "FINAL LAP  " : "LAP \(laps)  ") + raceTime(lap)
    if bestLap > 0 {
      message += String(format: "  %+.2f", lap - bestLap)
    }
    race.notify(message)
  }

  private func coach() {
    switch coachStage {
    case 0 where race.elapsed > 0.6:
      hint = "HOLD THE ARROWS TO STEER"
      if race.steering != 0 || race.elapsed > 8 { coachStage = 1 }
    case 1 where race.elapsed > 5:
      hint = "TAP DRIFT GOING INTO A BEND"
      if race.drifting { coachStage = 2 }
    case 2:
      hint =
        race.player.driftCharge >= 0.65 ? "TAP DRIFT AGAIN TO BOOST!" : "KEEP TURNING TO CHARGE"
      if !race.drifting {
        coachStage = race.driftBoosts > 0 ? 3 : 1
        if coachStage == 3 { hint = "" }
      }
    case 3 where race.hasItem:
      hint = "TAP THE LEMONADE FOR A BURST"
      coachStage = 4
    case 4 where !race.hasItem:
      hint = ""
      coachStage = 99
      UserDefaults.standard.set(true, forKey: "coached")
    default: break
    }
  }

  private func finish() {
    phase = .results
    race.steering = 0
    hint = ""
    let record = mode == .picnic ? bestCup : bestTrial
    if record > 0 && race.elapsed < record { improvement = record - race.elapsed }
    let fastest = race.player.lapTimes.min() ?? 0
    if bestLap == 0 || fastest < bestLap {
      bestLap = fastest
      UserDefaults.standard.set(bestLap, forKey: "bestLap")
    }
    if mode == .picnic {
      if bestCup == 0 || race.elapsed < bestCup {
        bestCup = race.elapsed
        UserDefaults.standard.set(bestCup, forKey: "bestCup")
      }
      if race.position == 1 {
        wins += 1
        UserDefaults.standard.set(wins, forKey: "wins")
      }
    } else if bestTrial == 0 || race.elapsed < bestTrial {
      bestTrial = race.elapsed
      UserDefaults.standard.set(bestTrial, forKey: "bestTrial")
    }
    cue(.finish)
  }
}

final class PicnicAudio {
  enum Cue { case start, pickup, boost, finish }
  private var player: AVAudioPlayer?

  func play(_ cue: Cue) {
    let frequencies: [Double]
    switch cue {
    case .start: frequencies = [523, 659]
    case .pickup: frequencies = [784, 1047, 1319]
    case .boost: frequencies = [392, 523, 784]
    case .finish: frequencies = [523, 659, 784, 1047]
    }
    let sampleRate = 22050
    let samplesPerNote = 1900
    var pcm = Data()
    // Square-wave chip voice with a flat gate envelope: the classic console jingle timbre.
    for frequency in frequencies {
      for index in 0..<samplesPerNote {
        let t = Double(index) / Double(sampleRate)
        let gate = index < samplesPerNote - 300 ? 1.0 : Double(samplesPerNote - index) / 300
        let wave = sin(2 * .pi * frequency * t) >= 0 ? 1.0 : -1.0
        var sample = Int16(wave * gate * 3200).littleEndian
        withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
      }
    }
    var data = Data()
    func text(_ string: String) { data.append(contentsOf: string.utf8) }
    func number<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
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
    data.append(pcm)
    try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    player = try? AVAudioPlayer(data: data)
    player?.volume = 0.4
    player?.play()
  }
}
