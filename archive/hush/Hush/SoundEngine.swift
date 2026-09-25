import AVFoundation
import MediaPlayer

@MainActor
protocol AudioPlayback {
  func start() throws
  func update(mix: Mix, gain: Double)
  func stop()
}

@MainActor
final class SoundEngine: AudioPlayback {
  private let engine = AVAudioEngine()
  private var players: [AVAudioPlayerNode] = []
  private var buffers: [AVAudioPCMBuffer] = []

  func prepare() {
    guard players.isEmpty,
      let format = AVAudioFormat(
        standardFormatWithSampleRate: Synthesis.sampleRate, channels: 2)
    else { return }
    for layer in Layer.allCases {
      let samples = Synthesis.samples(for: layer)
      guard
        let buffer = AVAudioPCMBuffer(
          pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
        let channels = buffer.floatChannelData
      else { continue }
      buffer.frameLength = buffer.frameCapacity
      for index in samples.indices {
        channels[0][index] = samples[index]
        channels[1][index] = samples[(index + 173) % samples.count]
      }
      let player = AVAudioPlayerNode()
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)
      players.append(player)
      buffers.append(buffer)
    }
    engine.mainMixerNode.outputVolume = 0
    engine.prepare()
  }

  func start() throws {
    prepare()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default)
    try session.setActive(true)
    if !engine.isRunning { try engine.start() }
    for (index, player) in players.enumerated() {
      if !player.isPlaying {
        player.scheduleBuffer(buffers[index], at: nil, options: .loops)
        player.play()
      }
    }
  }

  func update(mix: Mix, gain: Double) {
    for (index, player) in players.enumerated() {
      player.volume = Float(mix.levels[index]) * 0.34
    }
    engine.mainMixerNode.outputVolume = Float(Mix.clamp(mix.master * gain))
  }

  func stop() {
    for player in players { player.stop() }
    engine.pause()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
