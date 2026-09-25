import Foundation

public enum NodeKind: String, Codable, CaseIterable, Identifiable {
  case image, exposure, saturation, blur, blend, output
  public var id: String { rawValue }
  public var title: String { rawValue.capitalized }
  public var inputs: Int { self == .image ? 0 : (self == .blend ? 2 : 1) }
  public var defaultValue: Double {
    switch self {
    case .exposure: return 0.35
    case .saturation: return 1.25
    case .blur: return 16
    case .blend: return 0.45
    default: return 0
    }
  }
  public var range: ClosedRange<Double> {
    switch self {
    case .exposure: return -3...3
    case .saturation: return 0...2
    case .blur: return 0...60
    case .blend: return 0...1
    default: return 0...0
    }
  }
}

public struct GraphNode: Codable, Identifiable, Equatable {
  public var id: UUID
  public var kind: NodeKind
  public var x: Double
  public var y: Double
  public var value: Double
  public var asset: String

  public init(
    id: UUID = UUID(), kind: NodeKind, x: Double, y: Double,
    value: Double? = nil, asset: String = "Solstice"
  ) {
    self.id = id
    self.kind = kind
    self.x = x
    self.y = y
    self.value = value ?? kind.defaultValue
    self.asset = asset
  }
}

public struct GraphEdge: Codable, Equatable, Identifiable {
  public var id: String { "\(target.uuidString)-\(input)" }
  public var source: UUID
  public var target: UUID
  public var input: Int
  public init(source: UUID, target: UUID, input: Int = 0) {
    self.source = source
    self.target = target
    self.input = input
  }
}

public enum GraphError: LocalizedError, Equatable {
  case cycle, invalidConnection, invalidProject
  case missingInput(String, Int)
  case missingAsset
  public var errorDescription: String? {
    switch self {
    case .cycle: return "Cycle rejected. This connection would loop back into itself."
    case .invalidConnection: return "That connection is not valid. Choose an output, then an input."
    case .invalidProject:
      return "This is not a valid Prism project. Your current graph is unchanged."
    case .missingInput(let name, let input):
      return "\(name) needs input \(input == 0 ? "A" : "B"). Connect a node to render."
    case .missingAsset: return "The source image could not be loaded."
    }
  }
}

public struct Project: Codable, Equatable {
  public var version = 1
  public var name: String
  public var nodes: [GraphNode]
  public var edges: [GraphEdge]

  public init(name: String, nodes: [GraphNode], edges: [GraphEdge]) {
    self.name = name
    self.nodes = nodes
    self.edges = edges
  }

  public static func starter() -> Project {
    let image = GraphNode(kind: .image, x: 35, y: 62)
    let output = GraphNode(kind: .output, x: 785, y: 62)
    return Project(
      name: "Untitled study", nodes: [image, output],
      edges: [.init(source: image.id, target: output.id)])
  }

  public static func sample() -> Project {
    let image = GraphNode(kind: .image, x: 35, y: 62)
    let exposure = GraphNode(kind: .exposure, x: 285, y: 62, value: -0.15)
    let saturation = GraphNode(kind: .saturation, x: 535, y: 62, value: 1.18)
    let output = GraphNode(kind: .output, x: 785, y: 62)
    return Project(
      name: "Solstice / color study",
      nodes: [image, exposure, saturation, output],
      edges: [
        .init(source: image.id, target: exposure.id),
        .init(source: exposure.id, target: saturation.id),
        .init(source: saturation.id, target: output.id),
      ])
  }

  public func incoming(_ id: UUID, input: Int) -> GraphEdge? {
    edges.first { $0.target == id && $0.input == input }
  }

  public mutating func connect(source: UUID, target: UUID, input: Int) throws {
    guard let from = nodes.first(where: { $0.id == source }),
      let to = nodes.first(where: { $0.id == target }),
      from.kind != .output, input >= 0, input < to.kind.inputs
    else { throw GraphError.invalidConnection }
    let retained = edges.filter { !($0.target == target && $0.input == input) }
    var visited = Set<UUID>()
    func reachesSource(_ id: UUID) -> Bool {
      if id == source { return true }
      guard visited.insert(id).inserted else { return false }
      return retained.filter { $0.source == id }.contains { reachesSource($0.target) }
    }
    guard !reachesSource(target) else { throw GraphError.cycle }
    edges = retained + [.init(source: source, target: target, input: input)]
  }

  public mutating func delete(_ id: UUID) {
    guard nodes.first(where: { $0.id == id })?.kind != .output else { return }
    nodes.removeAll { $0.id == id }
    edges.removeAll { $0.source == id || $0.target == id }
  }

  public func validated() throws -> Project {
    guard version == 1, nodes.count <= 64, !nodes.isEmpty,
      Set(nodes.map(\.id)).count == nodes.count,
      nodes.filter({ $0.kind == .output }).count == 1,
      edges.count <= 128, name.count <= 200,
      nodes.allSatisfy({
        $0.x.isFinite && $0.y.isFinite && (0...1800).contains($0.x)
          && (0...1000).contains($0.y) && $0.value.isFinite
          && $0.kind.range.contains($0.value)
          && ["Solstice", "Nocturne"].contains($0.asset)
      })
    else { throw GraphError.invalidProject }
    var check = self
    check.edges = []
    for edge in edges {
      guard check.incoming(edge.target, input: edge.input) == nil else {
        throw GraphError.invalidProject
      }
      try check.connect(source: edge.source, target: edge.target, input: edge.input)
    }
    return self
  }

  public func encoded() throws -> Data {
    _ = try validated()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  public static func decode(_ data: Data) throws -> Project {
    guard data.count <= 2_000_000 else { throw GraphError.invalidProject }
    return try JSONDecoder().decode(Project.self, from: data).validated()
  }
}
