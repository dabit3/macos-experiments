import Foundation

public struct BlockDefinition: Decodable {
  public let id: Int
  public let name: String
  public let hardness: Double
  public let tool: Int
  public let minTier: Int
  public let solid: Bool
  public let opaque: Bool
  public let light: Int
  public let replaceable: Bool
  public let interactive: Bool
  public let fluid: Bool
  public let decoration: Bool
}

public struct ItemDefinition: Decodable, Identifiable {
  public let id: Int
  public let name: String
  public let maxStack: Int
  public let tool: Int
  public let tier: Int
  public let food: Int
  public let attack: Int
  public let fuelTicks: Int
  public let tile: Int
}

public struct Recipe: Decodable, Identifiable {
  public var id: String { name }
  public let name: String
  public let result: ItemStack
  public let width: Int
  public let height: Int
  public let pattern: [Int]
  public let shapeless: [Int]?
  public let gridNeeded: Int
  public func grid(_ n: Int) -> [Int] {
    var grid = [Int](repeating: 0, count: n * n)
    if let shapeless {
      for (i, id) in shapeless.prefix(n * n).enumerated() { grid[i] = id }
    } else if width <= n && height <= n {
      for y in 0..<height {
        for x in 0..<width { grid[y * n + x] = pattern[y * width + x] }
      }
    }
    return grid
  }
  public func affordable(in slots: [ItemStack]) -> Bool {
    let needed = (shapeless ?? pattern).filter { $0 != 0 }
    return Set(needed).allSatisfy { id in
      slots.filter { $0.id == id }.reduce(0) { $0 + $1.count } >= needed.filter { $0 == id }.count
    }
  }
}

public final class Registry {
  public static let shared = Registry()
  public let blocks: [Int: BlockDefinition]
  public let items: [Int: ItemDefinition]
  public let recipes: [Recipe]
  private struct Export: Decodable {
    let blocks: [BlockDefinition]
    let items: [ItemDefinition]
    let recipes: [Recipe]
  }
  private init() {
    guard let url = Bundle.module.url(forResource: "registry", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let export = try? JSONDecoder().decode(Export.self, from: data)
    else {
      preconditionFailure("Bundled VoxelHearth registry is missing or invalid")
    }
    blocks = Dictionary(uniqueKeysWithValues: export.blocks.map { ($0.id, $0) })
    items = Dictionary(uniqueKeysWithValues: export.items.map { ($0.id, $0) })
    recipes = export.recipes
  }
  public func block(_ id: Int) -> BlockDefinition { blocks[id] ?? blocks[0]! }
  public func item(_ id: Int) -> ItemDefinition { items[id] ?? items[0]! }
  public func breakSeconds(_ id: Int, held: Int) -> Double {
    let b = block(id)
    let tool = item(held)
    if b.hardness < 0 { return -1 }
    if b.hardness == 0 { return 0.05 }
    if b.tool == 0 || tool.tool != b.tool { return b.hardness }
    let speed = [1.0, 2, 4, 6, 9][tool.tier]
    let base = b.minTier != 0 && tool.tier >= b.minTier ? b.hardness * 0.3 : b.hardness
    return base / speed
  }
}
