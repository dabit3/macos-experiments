import Foundation

public enum FurnitureKind: String, CaseIterable, Codable, Sendable {
  case sofa, chair, coffeeTable, console, diningTable, rug, plant, lamp

  public var title: String {
    switch self {
    case .sofa: "Arc sofa"
    case .chair: "Lounge chair"
    case .coffeeTable: "Pebble table"
    case .console: "Oak sideboard"
    case .diningTable: "Gather table"
    case .rug: "Woven rug"
    case .plant: "Fiddle leaf"
    case .lamp: "Paper lantern"
    }
  }

  public var subtitle: String {
    switch self {
    case .sofa: "Linen · three seat"
    case .chair: "Bouclé · oak frame"
    case .coffeeTable: "Solid walnut"
    case .console: "Fluted oak"
    case .diningTable: "Oak · four places"
    case .rug: "Natural wool"
    case .plant: "Terracotta pot"
    case .lamp: "Rice paper · brass"
    }
  }

  public var width: Double {
    switch self {
    case .sofa: 2.3
    case .chair: 0.9
    case .coffeeTable: 1.2
    case .console: 1.8
    case .diningTable: 1.6
    case .rug: 2.8
    case .plant: 0.6
    case .lamp: 0.5
    }
  }

  public var depth: Double {
    switch self {
    case .sofa: 0.95
    case .chair: 0.9
    case .coffeeTable: 0.65
    case .console: 0.4
    case .diningTable: 0.9
    case .rug: 2.1
    case .plant: 0.6
    case .lamp: 0.5
    }
  }
}

public enum FloorMaterial: String, CaseIterable, Codable, Sendable {
  case oak, walnut, limestone
  public var title: String { rawValue.capitalized }
}

public enum WallMaterial: String, CaseIterable, Codable, Sendable {
  case chalk, clay, sage
  public var title: String { rawValue.capitalized }
}

public struct Furniture: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var kind: FurnitureKind
  public var x: Double
  public var z: Double
  public var rotation: Int

  public init(
    id: UUID = UUID(), kind: FurnitureKind, x: Double, z: Double, rotation: Int = 0
  ) {
    self.id = id
    self.kind = kind
    self.x = x
    self.z = z
    self.rotation = rotation
  }

  public var footprintWidth: Double { rotation % 180 == 0 ? kind.width : kind.depth }
  public var footprintDepth: Double { rotation % 180 == 0 ? kind.depth : kind.width }
}

public struct Room: Identifiable, Codable, Equatable, Sendable {
  public var id: UUID
  public var name: String
  public var width: Double
  public var depth: Double
  public var floor: FloorMaterial
  public var wall: WallMaterial
  public var furniture: [Furniture]

  public init(
    id: UUID = UUID(), name: String = "Untitled room", width: Double = 6,
    depth: Double = 5, floor: FloorMaterial = .oak, wall: WallMaterial = .chalk,
    furniture: [Furniture] = []
  ) {
    self.id = id
    self.name = name
    self.width = width
    self.depth = depth
    self.floor = floor
    self.wall = wall
    self.furniture = furniture
  }

  public static var sample: Room {
    Room(
      name: "Sunday in Copenhagen",
      furniture: [
        Furniture(kind: .rug, x: 3, z: 2.8),
        Furniture(kind: .sofa, x: 3, z: 1.25),
        Furniture(kind: .coffeeTable, x: 3, z: 2.7),
        Furniture(kind: .chair, x: 1.25, z: 3.2, rotation: 90),
        Furniture(kind: .console, x: 3.2, z: 4.6),
        Furniture(kind: .plant, x: 5.45, z: 0.55),
        Furniture(kind: .lamp, x: 1.4, z: 1.2),
      ])
  }

  public mutating func constrain(snap: Bool = false) {
    width = width.isFinite ? min(10, max(3, width)) : 6
    depth = depth.isFinite ? min(10, max(3, depth)) : 5
    for i in furniture.indices {
      furniture[i].rotation = ((furniture[i].rotation / 90 * 90) % 360 + 360) % 360
      let halfW = furniture[i].footprintWidth / 2
      let halfD = furniture[i].footprintDepth / 2
      var x = furniture[i].x.isFinite ? furniture[i].x : width / 2
      var z = furniture[i].z.isFinite ? furniture[i].z : depth / 2
      if snap {
        x = (x * 10).rounded() / 10
        z = (z * 10).rounded() / 10
      }
      furniture[i].x = min(width - halfW, max(halfW, x))
      furniture[i].z = min(depth - halfD, max(halfD, z))
    }
  }

  public mutating func add(_ kind: FurnitureKind, snap: Bool) -> UUID {
    let offset = Double(furniture.filter { $0.kind == kind }.count % 4) * 0.3
    let item = Furniture(kind: kind, x: width / 2 + offset, z: depth / 2 + offset)
    furniture.append(item)
    constrain(snap: snap)
    return item.id
  }
}

public struct RoomArchive: Codable, Equatable, Sendable {
  public var current: Room
  public var saved: [Room]

  public init(current: Room = .sample, saved: [Room] = []) {
    self.current = current
    self.saved = saved
  }

  public mutating func save() {
    if let index = saved.firstIndex(where: { $0.id == current.id }) {
      saved[index] = current
    } else {
      saved.insert(current, at: 0)
    }
  }

  public func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(self).write(to: url, options: .atomic)
  }

  public static func read(from url: URL) throws -> RoomArchive {
    var archive = try JSONDecoder().decode(RoomArchive.self, from: Data(contentsOf: url))
    archive.current.constrain()
    for index in archive.saved.indices { archive.saved[index].constrain() }
    return archive
  }
}
