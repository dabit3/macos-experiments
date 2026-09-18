import Foundation

struct NoiseGenerator {
  var state: UInt64

  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 33) / Double(UInt32.max >> 1) * 2 - 1
  }
}

enum Synthesis {
  static let sampleRate = 22_050.0
  static let seconds = 12.0

  static func samples(for layer: Layer, seconds: Double = seconds) -> [Float] {
    let count = Int(sampleRate * seconds)
    let overlap = min(Int(sampleRate * 0.3), count / 4)
    var random = NoiseGenerator(state: UInt64(Layer.allCases.firstIndex(of: layer)! + 19))
    var low = 0.0
    var deep = 0.0
    var previous = 0.0
    var result = [Float]()
    result.reserveCapacity(count + overlap)
    for index in 0..<(count + overlap) {
      let t = Double(index) / sampleRate
      let noise = random.next()
      low += 0.07 * (noise - low)
      deep += 0.009 * (noise - deep)
      let value: Double
      switch layer {
      case .rain:
        let patter = noise > 0.998 ? 0.22 : 0
        value =
          (noise * 0.24 + low * 0.9 + patter)
          * (0.88 + 0.12 * sin(t * .pi / 3))
      case .ocean:
        let swell = pow((sin(t * .pi / 3 - .pi / 2) + 1) / 2, 1.7)
        value = (low * 2.6 + noise * 0.065) * (0.25 + swell * 0.75)
      case .wind:
        let gust = 0.5 + 0.5 * sin(t * .pi / 6)
        value =
          low * 1.2 * (0.35 + gust * 0.65)
          + sin(t * 2 * .pi * 137) * 0.012 * gust
      case .brown:
        previous = (previous + noise * 0.035) / 1.014
        value = previous * 1.8 + deep * 0.7
      }
      result.append(Float(value))
    }
    for index in 0..<overlap {
      let ratio = Float(index) / Float(overlap)
      result[index] = result[count + index] * (1 - ratio) + result[index] * ratio
    }
    result.removeLast(overlap)
    let peak = result.reduce(Float(0)) { max($0, abs($1)) }
    if peak > 0 {
      let gain = min(3, 0.68 / peak)
      for index in result.indices { result[index] *= gain }
    }
    return result
  }
}
