import Foundation

public struct GameState: Codable, Equatable {
  public var cash: Double
  public var lifetimeCash: Double
  public var gpusShipped: Double
  public var taps: Int
  public var buildings: [BuildingKind: Int]
  public var purchasedUpgrades: Set<String>
  public var node: ProcessNode
  public var researchers: Int
  public var researchPoints: Double
  public var aiWaveTriggered: Bool
  public var architecturePoints: Int
  public var generation: Int
  public var unlockedAchievements: Set<String>
  public var stockHistory: [Double]
  public var stockPrice: Double
  public var lastSaved: Date
  public var soundEnabled: Bool
  public var hapticsEnabled: Bool
  public var totalPlaySeconds: Double
  public var rngState: UInt64
  public var stockSampleAccumulator: Double

  public var totalBuildings: Int { buildings.values.reduce(0, +) }
  public var marketCap: Double { lifetimeCash * 4 + cashPerSecondEstimate * 3600 * 24 * 30 }
  private var cashPerSecondEstimate: Double {
    buildings.reduce(0) { partial, pair in
      partial + Double(pair.value) * pair.key.baseRate * node.multiplier
    }
  }

  public static let fresh = GameState(
    cash: 0, lifetimeCash: 0, gpusShipped: 0, taps: 0,
    buildings: [:], purchasedUpgrades: [], node: .n28, researchers: 0,
    researchPoints: 0, aiWaveTriggered: false, architecturePoints: 0, generation: 0,
    unlockedAchievements: [], stockHistory: [1], stockPrice: 1, lastSaved: Date(),
    soundEnabled: true, hapticsEnabled: true, totalPlaySeconds: 0,
    rngState: 0xFABC0DE, stockSampleAccumulator: 0
  )
}
