import Foundation

/// Deterministic SplitMix64 generator so gameplay simulations are reproducible in tests.
public struct SeededRandom: RandomNumberGenerator, Codable, Equatable {
  public private(set) var state: UInt64

  public init(seed: UInt64) {
    state = seed
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  public mutating func unit() -> Double {
    Double(next() >> 11) / Double(1 << 53)
  }

  public mutating func range(_ lo: Double, _ hi: Double) -> Double {
    lo + (hi - lo) * unit()
  }

  public mutating func chance(_ probability: Double) -> Bool {
    unit() < probability
  }

  public mutating func pick<T>(_ items: [T]) -> T? {
    guard !items.isEmpty else { return nil }
    return items[Int(next() % UInt64(items.count))]
  }

  /// Weighted pick; weights must be non-negative.
  public mutating func weighted<T>(_ items: [(T, Double)]) -> T? {
    let total = items.reduce(0) { $0 + max(0, $1.1) }
    guard total > 0 else { return items.first?.0 }
    var roll = unit() * total
    for (item, weight) in items {
      roll -= max(0, weight)
      if roll <= 0 { return item }
    }
    return items.last?.0
  }
}
