import Foundation

public enum SampleKind: String, CaseIterable, Sendable {
  case tide = "Tidal pulse"
  case glass = "Glass bloom"
  case orbit = "Orbit engine"

  public var subtitle: String {
    switch self {
    case .tide: "Percussive / warm / 96 BPM"
    case .glass: "Tonal / crystalline / one-shot"
    case .orbit: "Texture / mechanical / rising"
    }
  }

  public var number: String {
    switch self {
    case .tide: "01"
    case .glass: "02"
    case .orbit: "03"
    }
  }

  public func generate() -> AudioDocument {
    let sampleRate = 44_100.0
    let duration = self == .tide ? 5.0 : self == .glass ? 4.0 : 6.0
    let count = Int(duration * sampleRate)
    var left = [Float](repeating: 0, count: count)
    var right = left
    var seed: UInt64 = 0x1234_5678
    for index in 0..<count {
      let t = Double(index) / sampleRate
      seed = seed &* 6_364_136_223_846_793_005 &+ 1
      let noise = Double(seed >> 33) / Double(UInt32.max >> 1) * 2 - 1
      let tau = Double.pi * 2
      let l: Double
      let r: Double
      switch self {
      case .tide:
        let beat = t.truncatingRemainder(dividingBy: 0.625)
        let half = t.truncatingRemainder(dividingBy: 0.3125)
        let kick =
          sin(tau * (48 * beat + 3.8 * (1 - exp(-beat * 30))))
          * exp(-beat * 13) * 0.66
        let hat = noise * exp(-half * 90) * 0.20
        let tone =
          (sin(tau * 146.832 * t) + sin(tau * 220 * t) * 0.3)
          * exp(-beat * 6) * 0.13
        l = kick + hat + tone
        r = kick + hat * 0.65 + tone * 1.1
      case .glass:
        let env = min(1, t * 150) * exp(-t * 1.2)
        l =
          env
          * (sin(tau * 523.25 * t) * 0.4 + sin(tau * 1310.2 * t) * 0.2
            + sin(tau * 2096 * t) * 0.12)
        r =
          env
          * (sin(tau * 523.6 * t) * 0.4 + sin(tau * 1309.7 * t) * 0.2
            + sin(tau * 2098 * t) * 0.12)
      case .orbit:
        let env = min(1, t * 2) * min(1, (duration - t) * 2)
        let wobble = 0.65 + 0.35 * sin(tau * 3 * t)
        l =
          env * wobble
          * (sin(tau * (55 * t + 8 * t * t)) * 0.45
            + sin(tau * 111 * t) * 0.15 + noise * 0.1)
        r =
          env * wobble
          * (sin(tau * (55 * t + 8 * t * t) + 0.2) * 0.45
            + sin(tau * 110.5 * t) * 0.15 + noise * 0.08)
      }
      left[index] = Float(l)
      right[index] = Float(r)
    }
    // Generator constants satisfy the public document limits.
    return try! AudioDocument(name: rawValue, sampleRate: sampleRate, channels: [left, right])
  }
}
