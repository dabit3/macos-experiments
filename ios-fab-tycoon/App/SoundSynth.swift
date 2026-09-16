import AVFoundation

final class SoundSynth {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  var enabled = true

  init() {
    engine.attach(player)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    try? AVAudioSession.sharedInstance().setActive(true)
    try? engine.start()
  }
  private func tone(
    startFrequency: Double, endFrequency: Double, duration: Double, volume: Float
  ) {
    guard enabled, engine.isRunning else { return }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(44_100 * duration))
    else { return }
    buffer.frameLength = buffer.frameCapacity
    let samples = buffer.floatChannelData![0]
    var phase = 0.0
    for i in 0..<Int(buffer.frameLength) {
      let t = Double(i) / 44_100
      let frequency = startFrequency + (endFrequency - startFrequency) * t / duration
      phase += 2 * .pi * frequency / 44_100
      samples[i] = Float(sin(phase) * exp(-t * 18)) * volume
    }
    player.scheduleBuffer(buffer)
    if !player.isPlaying { player.play() }
  }
  func tap() { tone(startFrequency: 880, endFrequency: 440, duration: 0.06, volume: 0.12) }
  func purchase() {
    tone(startFrequency: 520, endFrequency: 620, duration: 0.12, volume: 0.16)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      self.tone(startFrequency: 780, endFrequency: 900, duration: 0.16, volume: 0.12)
    }
  }
  func achievement() {
    tone(startFrequency: 660, endFrequency: 660, duration: 0.13, volume: 0.16)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
      self.tone(startFrequency: 880, endFrequency: 880, duration: 0.13, volume: 0.16)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
      self.tone(startFrequency: 1320, endFrequency: 1320, duration: 0.18, volume: 0.16)
    }
  }
  func aiWave() {
    tone(startFrequency: 180, endFrequency: 720, duration: 0.8, volume: 0.2)
  }
  func prestige() {
    tone(startFrequency: 1040, endFrequency: 520, duration: 0.22, volume: 0.2)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      self.tone(startFrequency: 520, endFrequency: 1040, duration: 0.32, volume: 0.2)
    }
  }
}
