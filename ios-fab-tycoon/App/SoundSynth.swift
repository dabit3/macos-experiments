import AVFoundation

final class SoundSynth {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  init() {
    engine.attach(player)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    try? engine.start()
  }
  private func tone(_ frequency: Double, duration: Double, volume: Float) {
    guard engine.isRunning else { return }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(44_100 * duration))
    else { return }
    buffer.frameLength = buffer.frameCapacity
    let samples = buffer.floatChannelData![0]
    for i in 0..<Int(buffer.frameLength) {
      let t = Double(i) / 44_100
      samples[i] = Float(sin(2 * .pi * frequency * t) * exp(-t * 18)) * volume
    }
    player.scheduleBuffer(buffer)
    if !player.isPlaying { player.play() }
  }
  func tap() { tone(660, duration: 0.05, volume: 0.12) }
  func purchase() {
    tone(520, duration: 0.12, volume: 0.16)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      self.tone(780, duration: 0.16, volume: 0.12)
    }
  }
  func achievement() { tone(880, duration: 0.15, volume: 0.16) }
  func aiWave() { tone(220, duration: 0.7, volume: 0.2) }
  func prestige() { tone(1040, duration: 0.5, volume: 0.2) }
}
