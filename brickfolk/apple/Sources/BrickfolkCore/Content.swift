import Foundation

public enum ItemSlot: String, Codable, CaseIterable, Sendable { case face, hat, accessory }
public struct CatalogItem: Codable, Identifiable, Sendable {
  public let id, name, blurb: String
  public let slot: ItemSlot
  public let price: Int
}
public struct PlaceInfo: Codable, Identifiable, Sendable {
  public let kind: Experience
  public let name, tagline, description: String
  public let accent: UInt32
  public let matchSeconds, minPlayers: Int
  public var id: Experience { kind }
}
public struct Badge: Codable, Identifiable, Sendable {
  public let id, name, description: String
  public let color: UInt32
}
public struct BrickType: Codable, Identifiable, Sendable {
  public let id, name, blurb: String
  public let cost, income: Int
  public let color: UInt32
}
public struct Upgrade: Codable, Identifiable, Sendable {
  public let id, name, blurb: String
  public let cost: Int
  public let multiplier: Double
}
public struct WorldRect: Codable, Sendable {
  public let x, y, w, h: Double
  public let kind: String?
}
public struct WorldPoint: Codable, Sendable {
  public let x, y: Double
}
public struct ObbyCourse: Codable, Sendable {
  public let platforms: [WorldRect]
  public let checkpoints: [WorldPoint]
  public let finishX: Double
}
public struct Arena: Codable, Sendable {
  public let width, height: Double
  public let walls: [WorldRect]
}
public struct GameContent: Codable, Sendable {
  public let catalog: [CatalogItem]
  public let bodyColors: [UInt32]
  public let bodyColorNames: [String]
  public let dailyRewards: [Int]
  public let badges: [Badge]
  public let places: [PlaceInfo]
  public let bricks: [BrickType]
  public let upgrades: [Upgrade]
  public let obby: ObbyCourse
  public let tag: Arena
  public static func load() throws -> GameContent {
    guard let url = Bundle.module.url(forResource: "content", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(GameContent.self, from: Data(contentsOf: url))
  }
}
