import Foundation

public struct TickResult {
  public let newlyUnlocked: [AchievementDef]
  public let aiWaveJustTriggered: Bool
}

public struct OfflineReport {
  public let elapsed: TimeInterval
  public let cash: Double
  public let gpus: Double
}

public struct GameEngine {
  public var state: GameState

  public init(state: GameState = .fresh) { self.state = state }

  public var pricePerGPU: Double {
    1 * priceMultiplier * (state.aiWaveTriggered ? 10 : 1)
  }
  public var productionMultiplier: Double {
    state.node.multiplier * globalMultiplier * (1 + 0.10 * Double(state.architecturePoints))
  }
  public var gpusPerSecond: Double {
    BuildingKind.allCases.reduce(0) { total, kind in
      let owned = Double(state.buildings[kind] ?? 0)
      return total + owned * kind.baseRate * buildingMultiplier(for: kind)
    } * productionMultiplier
  }
  public var cashPerSecond: Double { gpusPerSecond * pricePerGPU }
  public var tapValueGPUs: Double {
    (1 + 0.05 * Double(state.totalBuildings)) * tapMultiplier * state.node.multiplier
  }
  public var tapValueCash: Double { tapValueGPUs * pricePerGPU }
  public var researchPerSecond: Double {
    Double(state.researchers) * (1 + 0.1 * Double(state.architecturePoints))
  }
  public var researcherCost: Double { 500 * pow(1.25, Double(state.researchers)) }
  public var marketCap: Double { state.lifetimeCash * 4 + cashPerSecond * 3600 * 24 * 30 }
  public var stockPrice: Double { max(1, marketCap / 2.4e9) }
  public var earnedArchitecturePoints: Int {
    max(0, Int(floor(pow(max(0, state.lifetimeCash / 1e9), 0.5))) - state.architecturePoints)
  }
  public var canPrestige: Bool { earnedArchitecturePoints >= 1 }
  public var nextNode: ProcessNode? {
    guard let index = ProcessNode.allCases.firstIndex(of: state.node),
      index + 1 < ProcessNode.allCases.count
    else { return nil }
    return ProcessNode.allCases[index + 1]
  }
  public var canAdvanceNode: Bool {
    guard let nextNode else { return false }
    return state.researchPoints >= nextNode.researchCost
  }

  private var tapMultiplier: Double {
    Balance.upgrades.reduce(1) { value, upgrade in
      guard state.purchasedUpgrades.contains(upgrade.id) else { return value }
      if case .tapMultiplier(let multiplier) = upgrade.effect { return value * multiplier }
      return value
    }
  }
  private var globalMultiplier: Double {
    Balance.upgrades.reduce(1) { value, upgrade in
      guard state.purchasedUpgrades.contains(upgrade.id) else { return value }
      if case .globalMultiplier(let multiplier) = upgrade.effect { return value * multiplier }
      return value
    }
  }
  private var priceMultiplier: Double {
    Balance.upgrades.reduce(1) { value, upgrade in
      guard state.purchasedUpgrades.contains(upgrade.id) else { return value }
      if case .priceMultiplier(let multiplier) = upgrade.effect { return value * multiplier }
      return value
    }
  }
  private func buildingMultiplier(for kind: BuildingKind) -> Double {
    Balance.upgrades.reduce(1) { value, upgrade in
      guard state.purchasedUpgrades.contains(upgrade.id) else { return value }
      if case .buildingMultiplier(let target, let multiplier) = upgrade.effect, target == kind {
        return value * multiplier
      }
      return value
    }
  }

  public func cost(of kind: BuildingKind) -> Double {
    kind.baseCost * pow(1.15, Double(state.buildings[kind] ?? 0))
  }
  public func cost(of kind: BuildingKind, count: Int) -> Double {
    guard count > 0 else { return 0 }
    let firstCost = cost(of: kind)
    return firstCost * (pow(1.15, Double(count)) - 1) / 0.15
  }
  public func affordableCount(of kind: BuildingKind, maxCount: Int = 100) -> Int {
    guard maxCount > 0 else { return 0 }
    var count = 0
    var remaining = state.cash
    while count < maxCount {
      let nextCost = kind.baseCost * pow(1.15, Double((state.buildings[kind] ?? 0) + count))
      guard remaining >= nextCost else { break }
      remaining -= nextCost
      count += 1
    }
    return count
  }
  public func canBuy(_ kind: BuildingKind) -> Bool { state.cash >= cost(of: kind) }
  @discardableResult public mutating func buy(_ kind: BuildingKind) -> Bool {
    let cost = cost(of: kind)
    guard state.cash >= cost else { return false }
    state.cash -= cost
    state.buildings[kind, default: 0] += 1
    return true
  }
  @discardableResult public mutating func buyUpgrade(id: String) -> Bool {
    guard let upgrade = Balance.upgrades.first(where: { $0.id == id }),
      !state.purchasedUpgrades.contains(id), state.cash >= upgrade.cost
    else { return false }
    state.cash -= upgrade.cost
    state.purchasedUpgrades.insert(id)
    return true
  }
  @discardableResult public mutating func hireResearcher() -> Bool {
    guard state.cash >= researcherCost else { return false }
    state.cash -= researcherCost
    state.researchers += 1
    return true
  }
  @discardableResult public mutating func advanceNode() -> Bool {
    guard let nextNode, state.researchPoints >= nextNode.researchCost else { return false }
    state.researchPoints -= nextNode.researchCost
    state.node = nextNode
    return true
  }
  @discardableResult public mutating func tap() -> (cash: Double, gpus: Double) {
    let gpus = tapValueGPUs
    let cash = gpus * pricePerGPU
    state.taps += 1
    state.gpusShipped += gpus
    state.cash += cash
    state.lifetimeCash += cash
    return (cash, gpus)
  }
  public mutating func tick(dt: TimeInterval) -> TickResult {
    let delta = max(0, dt)
    let produced = gpusPerSecond * delta
    let earned = cashPerSecond * delta
    state.gpusShipped += produced
    state.cash += earned
    state.lifetimeCash += earned
    state.researchPoints += researchPerSecond * delta
    state.totalPlaySeconds += delta
    state.stockSampleAccumulator += delta
    let aiWasActive = state.aiWaveTriggered
    if state.gpusShipped >= 1_000_000 { state.aiWaveTriggered = true }
    if state.stockSampleAccumulator >= 0.5 {
      state.stockSampleAccumulator.formTruncatingRemainder(dividingBy: 0.5)
      state.stockPrice = stockPrice * (1 + nextNoise())
      state.stockHistory.append(state.stockPrice)
      if state.stockHistory.count > 240 {
        state.stockHistory.removeFirst(state.stockHistory.count - 240)
      }
    }
    let unlocked = checkAchievements()
    return TickResult(
      newlyUnlocked: unlocked, aiWaveJustTriggered: !aiWasActive && state.aiWaveTriggered)
  }
  public mutating func applyOffline(now: Date) -> OfflineReport? {
    let elapsed = now.timeIntervalSince(state.lastSaved)
    state.lastSaved = now
    guard elapsed >= 10 else { return nil }
    let capped = min(elapsed, 8 * 3600)
    let cash = cashPerSecond * capped * 0.5
    let gpus = gpusPerSecond * capped * 0.5
    state.cash += cash
    state.lifetimeCash += cash
    state.gpusShipped += gpus
    state.researchPoints += researchPerSecond * capped * 0.5
    return OfflineReport(elapsed: capped, cash: cash, gpus: gpus)
  }
  @discardableResult public mutating func prestige() -> Bool {
    guard canPrestige else { return false }
    let earned = earnedArchitecturePoints
    state.cash = 0
    state.buildings = [:]
    state.purchasedUpgrades = []
    state.node = .n28
    state.researchers = 0
    state.researchPoints = 0
    state.aiWaveTriggered = false
    state.architecturePoints += earned
    state.generation += 1
    return true
  }
  private mutating func nextNoise() -> Double {
    state.rngState = 6_364_136_223_846_793_005 &* state.rngState &+ 1_442_695_040_888_963_407
    let unit = Double(state.rngState >> 11) / Double(1 << 53)
    return (unit * 0.04) - 0.02
  }
  private mutating func checkAchievements() -> [AchievementDef] {
    let fresh = Balance.achievements.filter {
      !$0.check(state) ? false : !state.unlockedAchievements.contains($0.id)
    }
    for achievement in fresh {
      state.unlockedAchievements.insert(achievement.id)
    }
    return fresh
  }
}
