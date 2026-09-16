import AVFoundation
import Foundation
import os.lock

/// Sample-accurate synthwave renderer driven entirely by Track data.
/// All mutable render state lives behind one unfair lock; the render block
/// never allocates.
final class SynthEngine {
  enum SFX: Int {
    case perfect, great, good, miss, whiff, dlss
  }

  private let engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private var running = false
  private var musicStarted = false
  private(set) var available = false

  private var lock = os_unfair_lock()

  private struct Music {
    var playing = false
    var muted = false
    var bpm = 120.0
    var rootMidi = 45
    var chords: [[Int]] = [[]]
    var bass: [Int] = []
    var arp: [Int] = []
    var startSample: Int64 = 0
    var lag = 0.0
  }
  private var music = Music()

  private struct OneShot {
    var kind: SFX
    var start: Int64
  }
  private var shots = [OneShot?](repeating: nil, count: 24)
  private var shotCursor = 0

  private var sampleCounter: Int64 = 0
  private var sampleRate = 44100.0
  private var bassLP: Double = 0
  private var noiseState: UInt32 = 0x1234_5678

  // Audio grain-repeat for low-fps stutter.
  private var grainRing = [Float](repeating: 0, count: 4096)
  private var grainWrite = 0
  private var holdCounter = -1  // -1 = not holding, else frames into hold

  func configure(track: Track, atTime offset: Double = 0) {
    os_unfair_lock_lock(&lock)
    music.bpm = track.bpm
    music.rootMidi = track.rootMidi
    music.chords = track.chordProgression
    music.bass = track.bassPattern
    music.arp = track.arpPattern
    music.lag = 0
    music.startSample = sampleCounter + Int64(offset * sampleRate)
    shots = [OneShot?](repeating: nil, count: 24)
    bassLP = 0
    holdCounter = -1
    musicStarted = false
    os_unfair_lock_unlock(&lock)
  }

  func start() {
    guard !running else { return }
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient, options: [.mixWithOthers])
    try? session.setActive(true)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)
    else { return }
    sampleRate = format.sampleRate
    let node = AVAudioSourceNode(format: format) {
      [weak self] _, _, frameCount, abl -> OSStatus in
      guard let self else { return noErr }
      return self.render(frameCount: Int(frameCount), abl: abl)
    }
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    do {
      try engine.start()
      running = true
      available = true
    } catch {
      available = false
    }
    source = node
  }

  func play() {
    os_unfair_lock_lock(&lock)
    if !musicStarted {
      music.startSample = sampleCounter
      musicStarted = true
    }
    music.playing = true
    os_unfair_lock_unlock(&lock)
    if running { try? engine.start() }
  }

  func pause() {
    os_unfair_lock_lock(&lock)
    music.playing = false
    os_unfair_lock_unlock(&lock)
    if running { engine.pause() }
  }

  func stop() {
    if running { engine.stop() }
    running = false
    os_unfair_lock_lock(&lock)
    music.playing = false
    os_unfair_lock_unlock(&lock)
  }

  func setMuted(_ muted: Bool) {
    os_unfair_lock_lock(&lock)
    music.muted = muted
    os_unfair_lock_unlock(&lock)
  }

  func setLag(_ lag: Double) {
    os_unfair_lock_lock(&lock)
    music.lag = lag
    os_unfair_lock_unlock(&lock)
  }

  func sfx(_ kind: SFX) {
    os_unfair_lock_lock(&lock)
    shots[shotCursor] = OneShot(kind: kind, start: sampleCounter)
    shotCursor = (shotCursor + 1) % shots.count
    os_unfair_lock_unlock(&lock)
  }

  // MARK: - Render (realtime thread)

  private func midiFreq(_ m: Int) -> Double {
    440 * pow(2, Double(m - 69) / 12)
  }

  private func noise() -> Double {
    noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
    return Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
  }

  private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
    os_unfair_lock_lock(&lock)
    let m = music
    let buffers = UnsafeMutableAudioBufferListPointer(abl)
    let spb = 60.0 / m.bpm
    for frame in 0..<frameCount {
      var sample = 0.0
      let t = Double(sampleCounter - m.startSample) / sampleRate
      if m.playing && !m.muted && t >= 0 {
        sample = synthMusic(t: t, spb: spb, m: m)
      }
      if !m.muted {
        sample += synthSFX()
      }
      // Grain-hold stutter scaled by lag.
      grainRing[grainWrite] = Float(sample)
      grainWrite = (grainWrite + 1) % grainRing.count
      if m.lag > 0.45 && t >= 0 {
        let cycle = t.truncatingRemainder(dividingBy: 0.24)
        let holdLen = 0.05 + 0.10 * m.lag
        if cycle < holdLen {
          if holdCounter < 0 { holdCounter = 0 }
          let grainLen = max(64, Int(0.03 * sampleRate))
          let idx =
            (grainWrite - grainLen + (holdCounter % grainLen) + grainRing.count * 8)
            % grainRing.count
          sample = Double(grainRing[idx])
          holdCounter += 1
        } else {
          holdCounter = -1
        }
      } else {
        holdCounter = -1
      }
      sample = tanh(sample * 1.4) * 0.55
      let v = Float(sample)
      for buffer in buffers {
        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = v
      }
      sampleCounter += 1
    }
    os_unfair_lock_unlock(&lock)
    return noErr
  }

  private func synthMusic(t: Double, spb: Double, m: Music) -> Double {
    let beat = t / spb
    let bar = Int(floor(beat / 4))
    let chord = m.chords[bar % m.chords.count]
    let beatPhase = beat - floor(beat)
    let ps = beatPhase * spb  // seconds into this beat
    var out = 0.0

    // Kick: sine sweep 150->40 Hz on every beat.
    let kphase = 2 * .pi * (40 * ps + (110.0 / 40) * (1 - exp(-40 * ps)))
    let kickEnv = exp(-ps * 16)
    out += sin(kphase) * 0.9 * kickEnv

    // Snare on beats 2 and 4.
    let beatInBar = Int(floor(beat)) % 4
    if beatInBar == 1 || beatInBar == 3 {
      out += noise() * 0.30 * exp(-ps * 22)
    }

    // Hi-hat ticks on 8ths.
    let hs = t.truncatingRemainder(dividingBy: spb / 2)
    out += noise() * 0.09 * exp(-hs * 110)

    // Bass: saw through one-pole lowpass on 8ths.
    if !m.bass.isEmpty {
      let slot = Int(floor(beat * 2))
      let off = m.bass[slot % m.bass.count]
      let f = midiFreq(m.rootMidi + off)
      let nt = t - Double(slot) * spb / 2
      let saw = 2 * (f * nt - floor(f * nt)) - 1
      bassLP += (2 * .pi * 750 / sampleRate) * (saw - bassLP)
      out += bassLP * 0.34
    }

    // Pad: detuned saws per chord tone, slow attack each bar.
    let barElapsed = beat - Double(bar) * 4
    let padEnv = min(1, barElapsed / 0.5) * 0.05
    for note in chord {
      let f = midiFreq(note + 12)
      out += (2 * (f * 1.003 * t - floor(f * 1.003 * t)) - 1) * padEnv
      out += (2 * (f * 0.997 * t - floor(f * 0.997 * t)) - 1) * padEnv
    }

    // Arp: square blips on 16ths.
    if !m.arp.isEmpty {
      let slot = Int(floor(beat * 4))
      let f = midiFreq(chord[0] + m.arp[slot % m.arp.count] + 24)
      let nt = t - Double(slot) * spb / 4
      let sq: Double = (f * nt - floor(f * nt)) < 0.5 ? 1 : -1
      out += sq * 0.07 * exp(-nt * 13)
    }

    // Sidechain-ish dip while the kick breathes.
    out *= 1 - 0.42 * kickEnv
    return out
  }

  private func synthSFX() -> Double {
    var out = 0.0
    for i in shots.indices {
      guard let shot = shots[i] else { continue }
      let age = Double(sampleCounter - shot.start) / sampleRate
      if age < 0 { continue }
      switch shot.kind {
      case .perfect:
        out += blip(age: age, freq: 1320, dur: 0.14) * 0.30
      case .great:
        out += blip(age: age, freq: 990, dur: 0.12) * 0.26
      case .good:
        out += blip(age: age, freq: 660, dur: 0.10) * 0.22
      case .whiff:
        out += blip(age: age, freq: 180, dur: 0.05) * 0.15
      case .miss:
        out += noise() * 0.4 * exp(-age * 20) * (age < 0.2 ? 1 : 0)
        out += sin(2 * .pi * 80 * age) * 0.4 * exp(-age * 14)
      case .dlss:
        let dur = 0.55
        if age < dur {
          out += sin(2 * .pi * (220 * age + 700 * age * age / dur)) * 0.3 * exp(-age * 3)
        }
      }
      if age > 1.0 { shots[i] = nil }
    }
    return out
  }

  private func blip(age: Double, freq: Double, dur: Double) -> Double {
    guard age < dur else { return 0 }
    return sin(2 * .pi * freq * age) * exp(-age * 22)
  }
}
