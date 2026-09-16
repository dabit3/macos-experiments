import Foundation

/// Deterministic xorshift generator so runs and tests can be replayed.
public struct SeededGenerator: RandomNumberGenerator, Codable, Sendable, Equatable {
  private var state: UInt64

  public init(seed: UInt64) {
    state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
  }

  public mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

/// Seven-bag randomizer: every kernel appears exactly once per bag of seven.
public struct KernelBag: Codable, Sendable, Equatable {
  private var rng: SeededGenerator
  private var bag: [Kernel] = []

  public init(seed: UInt64) {
    rng = SeededGenerator(seed: seed)
  }

  public mutating func next() -> Kernel {
    if bag.isEmpty { bag = Kernel.allCases.shuffled(using: &rng) }
    return bag.removeFirst()
  }
}
