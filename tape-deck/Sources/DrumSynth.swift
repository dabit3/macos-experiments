import Foundation

enum DrumSynth {
  static func sample(drum: Drum, sampleRate: Double) -> [Float] {
    let durations = [0.48, 0.24, 0.095, 0.29]
    let count = Int(durations[drum.rawValue] * sampleRate)
    var seed: UInt64 = 0x5441_5045 + UInt64(drum.rawValue)
    var phase = 0.0
    var previousNoise = 0.0
    return (0..<count).map { frame in
      let time = Double(frame) / sampleRate
      seed = seed &* 6_364_136_223_846_793_005 &+ 1
      let noise = Double(seed >> 33) / Double(UInt32.max >> 1) * 2 - 1
      let highpass = noise - previousNoise
      previousNoise = noise
      let attack = min(1, time * 2000)
      let value: Double
      switch drum {
      case .kick:
        phase += 2 * .pi * (48 + 115 * exp(-time * 48)) / sampleRate
        value = sin(phase) * exp(-time * 10) * 0.85 + noise * exp(-time * 230) * 0.12
      case .snare:
        value = (noise * 0.53 + sin(time * 2 * .pi * 185) * 0.22) * exp(-time * 23)
      case .hat:
        value = highpass * exp(-time * 63) * 0.25
      case .clap:
        let bursts = [0.0, 0.012, 0.025].reduce(0.0) { result, start in
          result + (time >= start ? exp(-(time - start) * 90) : 0)
        }
        value = highpass * (bursts * 0.17 + exp(-time * 18) * 0.11)
      }
      return Float(value * attack)
    }
  }
}
