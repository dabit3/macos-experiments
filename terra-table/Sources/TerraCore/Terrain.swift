import Foundation

public enum Brush: String, CaseIterable, Sendable {
  case raise = "Raise"
  case lower = "Carve"
  case smooth = "Smooth"
  case orbit = "Orbit"
}

public enum Landscape: String, CaseIterable, Codable, Sendable {
  case alpine = "Alpine island"
  case caldera = "Caldera"
  case archipelago = "Archipelago"

  public var subtitle: String {
    switch self {
    case .alpine: return "A ridge above the tide"
    case .caldera: return "A quiet volcanic lake"
    case .archipelago: return "Islands in a shallow sea"
    }
  }
}

public struct Terrain: Codable, Equatable, Sendable {
  public static let resolution = 81
  public static let extent: Float = 10
  public var heights: [Float]
  public var water: Float
  public var landscape: Landscape
  public var title: String

  public init(landscape: Landscape = .alpine, seed: Int = 42) {
    self.landscape = landscape
    title = landscape.rawValue
    water = 0.23
    heights = [Float](repeating: 0, count: Self.resolution * Self.resolution)
    for z in 0..<Self.resolution {
      for x in 0..<Self.resolution {
        let u = Float(x) / Float(Self.resolution - 1) * 2 - 1
        let v = Float(z) / Float(Self.resolution - 1) * 2 - 1
        let r = sqrt(u * u + v * v)
        let detail =
          sin(u * 23 + Float(seed)) * cos(v * 19 - Float(seed)) * 0.018
          + sin(u * 47 + v * 31) * 0.009
        let h: Float
        switch landscape {
        case .alpine:
          let peakA = Self.hill(u + 0.25, v + 0.22, 0.055) * 0.65
          let peakB = Self.hill(u - 0.22, v - 0.18, 0.065) * 0.57
          let foothills = Self.hill(u, v, 0.32) * 0.31
          let ridge = Self.hill(u + 0.35, v - 0.34, 0.05) * 0.26
          let crags = sin(u * 37 + v * 11) * cos(v * 32) * 0.035
          h = 0.05 + peakA + peakB + foothills + ridge + (detail + crags) * max(0, 1 - r)
        case .caldera:
          let ring = exp(-pow((r - 0.47) * 7, 2)) * 0.62
          h = 0.06 + ring * (0.85 + 0.15 * sin(atan2(v, u) * 5)) + detail
        case .archipelago:
          h =
            0.035 + Self.hill(u + 0.4, v + 0.25, 0.065) * 0.69
            + Self.hill(u - 0.32, v - 0.25, 0.09) * 0.62
            + Self.hill(u - 0.3, v + 0.46, 0.028) * 0.4
            + Self.hill(u + 0.4, v - 0.47, 0.026) * 0.32 + detail
        }
        heights[z * Self.resolution + x] = min(1.25, max(0.015, h))
      }
    }
  }

  private static func hill(_ x: Float, _ z: Float, _ spread: Float) -> Float {
    exp(-(x * x + z * z) / spread)
  }

  public var isValid: Bool {
    heights.count == Self.resolution * Self.resolution
      && heights.allSatisfy { $0.isFinite && (0...1.25).contains($0) }
      && water.isFinite && (0...0.85).contains(water)
      && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 80
  }

  public mutating func apply(
    _ brush: Brush, x: Float, z: Float, radius: Float, strength: Float
  ) {
    guard brush != .orbit, x.isFinite, z.isFinite, radius.isFinite,
      strength.isFinite, radius > 0, strength > 0
    else { return }
    let old = heights
    let step = Self.extent / Float(Self.resolution - 1)
    for row in 0..<Self.resolution {
      for col in 0..<Self.resolution {
        let px = Float(col) * step - Self.extent / 2
        let pz = Float(row) * step - Self.extent / 2
        let distance = hypot(px - x, pz - z)
        guard distance < radius else { continue }
        let weight = pow(1 - distance / radius, 2)
        let index = row * Self.resolution + col
        if brush == .smooth {
          var total: Float = 0
          var count: Float = 0
          for dz in -2...2 {
            for dx in -2...2 {
              let nx = max(0, min(Self.resolution - 1, col + dx))
              let nz = max(0, min(Self.resolution - 1, row + dz))
              total += old[nz * Self.resolution + nx]
              count += 1
            }
          }
          heights[index] += (total / count - old[index]) * min(1, strength * 5) * weight
        } else {
          let delta = (brush == .raise ? 1 : Float(-1)) * strength * 0.065 * weight
          heights[index] = min(1.25, max(0.015, old[index] + delta))
        }
      }
    }
  }

  public var landPercent: Int {
    Int(Float(heights.filter { $0 > water }.count) / Float(heights.count) * 100)
  }

  public var summit: Int { Int((heights.max() ?? 0) * 1000) }

  public func obj() -> String {
    var lines = ["# Terra Table heightfield — units are arbitrary studio units", "o TerraTable"]
    let n = Self.resolution
    for z in 0..<n {
      for x in 0..<n {
        lines.append(
          String(
            format: "v %.5f %.5f %.5f", Float(x) / Float(n - 1) * 10 - 5,
            heights[z * n + x] * 3, Float(z) / Float(n - 1) * 10 - 5))
      }
    }
    for z in 0..<(n - 1) {
      for x in 0..<(n - 1) {
        let a = z * n + x + 1
        lines.append("f \(a) \(a + n) \(a + 1)")
        lines.append("f \(a + 1) \(a + n) \(a + n + 1)")
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }
}

public struct TerrainHistory: Sendable {
  public private(set) var undoStack: [Terrain] = []
  public private(set) var redoStack: [Terrain] = []

  public init() {}

  public mutating func record(_ before: Terrain, after: Terrain) {
    guard before != after else { return }
    undoStack.append(before)
    if undoStack.count > 30 { undoStack.removeFirst() }
    redoStack.removeAll()
  }

  public mutating func undo(_ current: Terrain) -> Terrain? {
    guard let previous = undoStack.popLast() else { return nil }
    redoStack.append(current)
    return previous
  }

  public mutating func redo(_ current: Terrain) -> Terrain? {
    guard let next = redoStack.popLast() else { return nil }
    undoStack.append(current)
    return next
  }
}

public struct SavedWorld: Codable, Identifiable, Sendable {
  public var id: UUID
  public var date: Date
  public var terrain: Terrain

  public init(terrain: Terrain) {
    id = UUID()
    date = Date()
    self.terrain = terrain
  }
}
