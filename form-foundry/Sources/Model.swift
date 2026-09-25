import Foundation

enum Profile: String, Codable, CaseIterable {
  case rectangle, circle
  var label: String { self == .rectangle ? "Rectangle" : "Ellipse" }
}

enum Finish: String, Codable, CaseIterable {
  case porcelain, graphite, vermilion, sage, sand
  var label: String { rawValue.capitalized }
  var rgb: (Double, Double, Double) {
    switch self {
    case .porcelain: return (0.88, 0.86, 0.80)
    case .graphite: return (0.24, 0.28, 0.29)
    case .vermilion: return (0.79, 0.25, 0.16)
    case .sage: return (0.48, 0.55, 0.46)
    case .sand: return (0.73, 0.58, 0.40)
    }
  }
}

struct Solid: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var profile: Profile = .rectangle
  var width: Double = 50
  var depth: Double = 40
  var height: Double = 25
  var x: Double = 0
  var y: Double = 0
  var z: Double = 0
  var rotation: Double = 0
  var finish: Finish = .porcelain

  var volume: Double {
    width * depth * height * (profile == .circle ? .pi / 4 : 1)
  }

  var isValid: Bool {
    [width, depth, height].allSatisfy { $0.isFinite && (1...500).contains($0) }
      && [x, z].allSatisfy { $0.isFinite && (-500...500).contains($0) }
      && y.isFinite && (0...500).contains(y)
      && rotation.isFinite && (-360...360).contains(rotation)
      && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func world(_ vertex: Vertex) -> Vertex {
    let angle = rotation * .pi / 180
    return Vertex(
      x: vertex.x * cos(angle) + vertex.z * sin(angle) + x,
      y: vertex.y + y,
      z: -vertex.x * sin(angle) + vertex.z * cos(angle) + z
    )
  }
}

struct Project: Codable, Equatable {
  var title: String
  var solids: [Solid]

  var isValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && solids.count <= 100 && solids.allSatisfy(\.isValid)
      && Set(solids.map(\.id)).count == solids.count
  }

  static var sample: Project {
    Project(
      title: "Desk / 01",
      solids: [
        Solid(name: "Foundation", width: 180, depth: 120, height: 8, finish: .sand),
        Solid(name: "Back wall", width: 180, depth: 6, height: 54, y: 8, z: -57, finish: .sage),
        Solid(name: "Left wall", width: 6, depth: 108, height: 38, x: -87, y: 8, finish: .sage),
        Solid(name: "Right wall", width: 6, depth: 108, height: 38, x: 87, y: 8, finish: .sage),
        Solid(name: "Divider", width: 6, depth: 108, height: 30, x: -24, y: 8, finish: .porcelain),
        Solid(name: "Front lip", width: 180, depth: 6, height: 16, y: 8, z: 57, finish: .sage),
        Solid(
          name: "Round rest", profile: .circle, width: 30, depth: 30, height: 12,
          x: 48, y: 8, z: 22, finish: .vermilion),
      ])
  }
}

struct Vertex: Equatable {
  var x: Double
  var y: Double
  var z: Double
}

struct Mesh {
  var vertices: [Vertex]
  var triangles: [[Int]]

  static func make(for solid: Solid, segments: Int = 64) -> Mesh {
    let count = solid.profile == .rectangle ? 4 : max(3, segments)
    var ring: [Vertex] = []
    if solid.profile == .rectangle {
      ring = [
        Vertex(x: -solid.width / 2, y: 0, z: -solid.depth / 2),
        Vertex(x: solid.width / 2, y: 0, z: -solid.depth / 2),
        Vertex(x: solid.width / 2, y: 0, z: solid.depth / 2),
        Vertex(x: -solid.width / 2, y: 0, z: solid.depth / 2),
      ]
    } else {
      ring = (0..<count).map {
        let angle = Double($0) / Double(count) * 2 * .pi
        return Vertex(x: cos(angle) * solid.width / 2, y: 0, z: sin(angle) * solid.depth / 2)
      }
    }
    let top = ring.map { Vertex(x: $0.x, y: solid.height, z: $0.z) }
    var triangles: [[Int]] = []
    for i in 0..<count {
      let j = (i + 1) % count
      triangles.append([i, i + count, j + count])
      triangles.append([i, j + count, j])
    }
    for i in 1..<(count - 1) {
      triangles.append([0, i, i + 1])
      triangles.append([count, count + i + 1, count + i])
    }
    return Mesh(vertices: (ring + top).map(solid.world), triangles: triangles)
  }

  static func obj(project: Project) -> String {
    var lines = [
      "# Form Foundry / Wavefront OBJ", "# Units: millimeters. Y up. Separate closed solids.",
    ]
    var offset = 1
    for (index, solid) in project.solids.enumerated() {
      let mesh = make(for: solid)
      lines.append("o solid_\(index + 1)")
      lines.append("# \(solid.name.replacingOccurrences(of: "\n", with: " "))")
      lines += mesh.vertices.map {
        String(
          format: "v %.6f %.6f %.6f", locale: Locale(identifier: "en_US_POSIX"), $0.x, $0.y, $0.z)
      }
      lines += mesh.triangles.map { "f \($0[0] + offset) \($0[1] + offset) \($0[2] + offset)" }
      offset += mesh.vertices.count
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

struct History {
  private(set) var past: [Project] = []
  private(set) var future: [Project] = []

  mutating func record(_ project: Project) {
    past.append(project)
    if past.count > 100 { past.removeFirst() }
    future.removeAll()
  }

  mutating func undo(_ current: Project) -> Project? {
    guard let previous = past.popLast() else { return nil }
    future.append(current)
    return previous
  }

  mutating func redo(_ current: Project) -> Project? {
    guard let next = future.popLast() else { return nil }
    past.append(current)
    return next
  }
}

enum ProjectIO {
  static func decode(_ data: Data) throws -> Project {
    let project = try JSONDecoder().decode(Project.self, from: data)
    guard project.isValid else { throw CocoaError(.fileReadCorruptFile) }
    return project
  }

  static func write(_ project: Project, to url: URL) throws {
    guard project.isValid else { throw CocoaError(.fileWriteInvalidFileName) }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(project).write(to: url, options: .atomic)
  }
}
