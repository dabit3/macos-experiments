import Foundation

public enum ProcessNode: Int, Codable, CaseIterable, Sendable {
  case n28, n16, n7, n4, n2, evenSmaller

  public var displayName: String {
    ["28nm", "16nm", "7nm", "4nm", "2nm", "Even Smaller™"][rawValue]
  }
  public var multiplier: Double { [1, 2, 5, 12, 30, 100][rawValue].doubleValue }
  public var researchCost: Double { [0, 50, 400, 3_000, 25_000, 250_000][rawValue].doubleValue }
  public var flavor: String {
    [
      "Big enough to see from space.",
      "Smaller transistors, bigger dreams.",
      "The AI wave starts to shimmer.",
      "Yield is a personality trait.",
      "Physics politely asks us to stop.",
      "We have entered the realm of tiny miracles.",
    ][rawValue]
  }
}

extension Int { fileprivate var doubleValue: Double { Double(self) } }

public enum BuildingKind: Int, Codable, CaseIterable, Sendable {
  case garageBench, fabLine, cleanRoom, megaFab, gigaFab, tensorForge, orbitalFoundry

  public var displayName: String {
    [
      "Garage Bench", "Fab Line", "Clean Room", "Mega Fab", "Giga Fab", "Tensor Forge",
      "Orbital Foundry",
    ][rawValue]
  }
  public var baseCost: Double {
    [15, 100, 1_100, 12_000, 130_000, 1_400_000, 20_000_000][rawValue].doubleValue
  }
  public var baseRate: Double { [0.1, 1, 8, 47, 260, 1_400, 7_800][rawValue] }
  public var flavor: String {
    [
      "One bench. Infinite ambition.",
      "The first real production line.",
      "Dust is now your sworn enemy.",
      "Scale is a feature, not a bug.",
      "The lights are visible from orbit.",
      "Specialized silicon for the AI wave.",
      "Launch GPUs into the stratosphere.",
    ][rawValue]
  }
  public var symbol: String {
    [
      "wrench.and.screwdriver.fill", "rectangle.3.group.fill", "aqi.medium", "building.2.fill",
      "building.columns.fill", "cpu.fill", "globe.americas.fill",
    ][rawValue]
  }
}

public enum UpgradeEffect {
  case tapMultiplier(Double)
  case globalMultiplier(Double)
  case buildingMultiplier(BuildingKind, Double)
  case priceMultiplier(Double)
}

public struct UpgradeDef: Identifiable {
  public let id: String
  public let name: String
  public let flavor: String
  public let cost: Double
  public let effect: UpgradeEffect

  public init(id: String, name: String, flavor: String, cost: Double, effect: UpgradeEffect) {
    self.id = id
    self.name = name
    self.flavor = flavor
    self.cost = cost
    self.effect = effect
  }
}

public struct AchievementDef: Identifiable {
  public let id: String
  public let title: String
  public let detail: String
  public let check: (GameState) -> Bool

  public init(id: String, title: String, detail: String, check: @escaping (GameState) -> Bool) {
    self.id = id
    self.title = title
    self.detail = detail
    self.check = check
  }
}

public enum Architecture {
  public static let names = [
    "Kestrel", "Aurora", "Helix", "Quasar", "Nova", "Zenith", "Halcyon", "Meridian",
  ]
  public static func name(for generation: Int) -> String { names[generation % names.count] }
}

public enum Balance {
  public static let upgrades: [UpgradeDef] = [
    UpgradeDef(
      id: "thermal-paste", name: "Thermal Paste", flavor: "Tap x2. Cooler chips, faster clicks.",
      cost: 100, effect: .tapMultiplier(2)),
    UpgradeDef(
      id: "cuda-cores", name: "CUDA Cores", flavor: "Global production x1.5.", cost: 2_500,
      effect: .globalMultiplier(1.5)),
    UpgradeDef(
      id: "ray-tracing", name: "Ray Tracing Cores",
      flavor: "Global production x2. Reflections included.", cost: 50_000,
      effect: .globalMultiplier(2)),
    UpgradeDef(
      id: "dlss", name: "DLSS Frame Generation", flavor: "Ships frames that don't exist. Tap x3.",
      cost: 400_000, effect: .tapMultiplier(3)),
    UpgradeDef(
      id: "tensor", name: "Tensor Cores", flavor: "Tensor Forge output x3.", cost: 1_000_000,
      effect: .buildingMultiplier(.tensorForge, 3)),
    UpgradeDef(
      id: "founders", name: "Founders Edition", flavor: "Premium silicon commands 1.5x price.",
      cost: 6_000_000, effect: .priceMultiplier(1.5)),
    UpgradeDef(
      id: "chiplets", name: "Chiplet Packaging", flavor: "Mix and match more good ideas.",
      cost: 18_000_000, effect: .globalMultiplier(1.75)),
    UpgradeDef(
      id: "hbm", name: "HBM Stack", flavor: "Memory bandwidth for days.", cost: 60_000_000,
      effect: .buildingMultiplier(.gigaFab, 2.5)),
    UpgradeDef(
      id: "hyperlink", name: "HyperLink Bridge", flavor: "Every fab talks to every other fab.",
      cost: 200_000_000, effect: .globalMultiplier(2)),
    UpgradeDef(
      id: "liquid-cooling", name: "Liquid Cooling", flavor: "Cold chips, hot numbers.",
      cost: 800_000_000, effect: .buildingMultiplier(.megaFab, 2.5)),
    UpgradeDef(
      id: "yield", name: "Yield Optimizer", flavor: "Fewer duds, more green lights.",
      cost: 3_000_000_000, effect: .globalMultiplier(2)),
    UpgradeDef(
      id: "driver", name: "Driver Day-One Patch", flavor: "It works on launch day. Probably.",
      cost: 12_000_000_000, effect: .tapMultiplier(4)),
    UpgradeDef(
      id: "wafer-broker", name: "Wafer Broker", flavor: "Bulk silicon at bulk confidence.",
      cost: 50_000_000_000, effect: .priceMultiplier(2)),
    UpgradeDef(
      id: "datacenter", name: "Datacenter Contract", flavor: "The cloud has entered the chat.",
      cost: 250_000_000_000, effect: .globalMultiplier(3)),
  ]

  public static let achievements: [AchievementDef] = [
    AchievementDef(
      id: "first-tap", title: "Power On", detail: "Tap the chip once.", check: { $0.taps >= 1 }),
    AchievementDef(
      id: "hundred-gpus", title: "Small Batch", detail: "Ship 100 GPUs.",
      check: { $0.gpusShipped >= 100 }),
    AchievementDef(
      id: "first-fab", title: "Assembly Required", detail: "Build your first fab.",
      check: { $0.totalBuildings >= 1 }),
    AchievementDef(
      id: "cash-k", title: "Four Digits", detail: "Hold $1K cash.", check: { $0.cash >= 1_000 }),
    AchievementDef(
      id: "cash-m", title: "Millionaire", detail: "Hold $1M cash.", check: { $0.cash >= 1_000_000 }),
    AchievementDef(
      id: "cash-b", title: "Billionaire", detail: "Hold $1B cash.",
      check: { $0.cash >= 1_000_000_000 }),
    AchievementDef(
      id: "cash-t", title: "Market Maker", detail: "Hold $1T cash.",
      check: { $0.cash >= 1_000_000_000_000 }),
    AchievementDef(
      id: "node-upgrade", title: "Smaller Is Better", detail: "Advance a process node.",
      check: { $0.node != .n28 }),
    AchievementDef(
      id: "researchers", title: "R&D Department", detail: "Hire 10 researchers.",
      check: { $0.researchers >= 10 }),
    AchievementDef(
      id: "ai-wave", title: "The AI Wave", detail: "Ship one million GPUs.",
      check: { $0.aiWaveTriggered }),
    AchievementDef(
      id: "prestige", title: "New Architecture", detail: "Prestige your fab.",
      check: { $0.generation >= 1 }),
    AchievementDef(
      id: "market-cap", title: "Trillion Dollar Idea", detail: "Reach a $1T market cap.",
      check: { $0.marketCap >= 1_000_000_000_000 }),
    AchievementDef(
      id: "taps", title: "Carpal Silicon", detail: "Tap 1,000 times.", check: { $0.taps >= 1_000 }),
    AchievementDef(
      id: "all-buildings", title: "Full Stack", detail: "Own every building type.",
      check: {
        $0.buildings.count == BuildingKind.allCases.count
          && $0.buildings.values.allSatisfy { $0 > 0 }
      }),
  ]
}
