import Foundation

/// Minimal 2D vector used by the rules and hit-testing code so the Core module
/// stays free of CoreGraphics and can be unit tested with `swift test`.
public struct V2: Equatable, Hashable {
  public var x: Double
  public var y: Double

  public init(x: Double = 0, y: Double = 0) {
    self.x = x
    self.y = y
  }

  public static let zero = V2()

  public static func + (lhs: V2, rhs: V2) -> V2 { V2(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
  public static func - (lhs: V2, rhs: V2) -> V2 { V2(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
  public static func * (lhs: V2, rhs: Double) -> V2 { V2(x: lhs.x * rhs, y: lhs.y * rhs) }

  public var length: Double { (x * x + y * y).squareRoot() }
  public var normalized: V2 { length > 0.0001 ? self * (1 / length) : .zero }
  public func dot(_ other: V2) -> Double { x * other.x + y * other.y }
  public func cross(_ other: V2) -> Double { x * other.y - y * other.x }
  public var perpendicular: V2 { V2(x: -y, y: x) }
  public var angle: Double { atan2(y, x) }
}

public enum Geometry {
  /// Closest point on segment `ab` to `p`, expressed as a parameter in 0...1.
  public static func projectionParameter(of p: V2, onto a: V2, _ b: V2) -> Double {
    let ab = b - a
    let lengthSquared = ab.dot(ab)
    guard lengthSquared > 0.000001 else { return 0 }
    return min(1, max(0, (p - a).dot(ab) / lengthSquared))
  }

  public static func distance(from p: V2, toSegment a: V2, _ b: V2) -> Double {
    let t = projectionParameter(of: p, onto: a, b)
    return (a + (b - a) * t - p).length
  }

  /// A swept blade segment slices a circular target when it passes within the
  /// target's radius. Zero-length segments (a resting finger) never slice.
  public static func segment(_ a: V2, _ b: V2, hitsCircleAt center: V2, radius: Double) -> Bool {
    guard (b - a).length > 0.5 else { return false }
    return distance(from: center, toSegment: a, b) <= radius
  }

  /// Signed side of `p` relative to the infinite line through `a` and `b`.
  /// Positive values are on the left of the travel direction.
  public static func side(of p: V2, line a: V2, _ b: V2) -> Double {
    (b - a).cross(p - a)
  }

  /// Splits a convex polygon (counter-clockwise or clockwise) by the infinite
  /// line through `a` and `b`. Returns the two pieces; a piece may be empty when
  /// the line misses the polygon.
  public static func split(polygon: [V2], along a: V2, _ b: V2) -> (left: [V2], right: [V2]) {
    guard polygon.count >= 3 else { return ([], []) }
    var left: [V2] = []
    var right: [V2] = []
    for index in polygon.indices {
      let current = polygon[index]
      let next = polygon[(index + 1) % polygon.count]
      let sideCurrent = side(of: current, line: a, b)
      let sideNext = side(of: next, line: a, b)
      if sideCurrent >= 0 { left.append(current) }
      if sideCurrent <= 0 { right.append(current) }
      if (sideCurrent > 0 && sideNext < 0) || (sideCurrent < 0 && sideNext > 0) {
        let t = sideCurrent / (sideCurrent - sideNext)
        let intersection = current + (next - current) * t
        left.append(intersection)
        right.append(intersection)
      }
    }
    if left.count < 3 { left = [] }
    if right.count < 3 { right = [] }
    return (left, right)
  }

  public static func regularPolygon(sides: Int, radius: Double, rotation: Double = 0) -> [V2] {
    (0..<max(3, sides)).map { index in
      let angle = rotation + Double(index) / Double(max(3, sides)) * 2 * .pi
      return V2(x: cos(angle) * radius, y: sin(angle) * radius)
    }
  }

  public static func area(of polygon: [V2]) -> Double {
    guard polygon.count >= 3 else { return 0 }
    var total = 0.0
    for index in polygon.indices {
      total += polygon[index].cross(polygon[(index + 1) % polygon.count])
    }
    return abs(total) / 2
  }

  public static func centroid(of polygon: [V2]) -> V2 {
    guard !polygon.isEmpty else { return .zero }
    let sum = polygon.reduce(V2.zero, +)
    return sum * (1 / Double(polygon.count))
  }
}

/// Deterministic linear congruential generator so launches and tests are reproducible.
public struct SeededRandom {
  public var state: UInt64

  public init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

  public mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64.max >> 11)
  }

  public mutating func next(in range: ClosedRange<Double>) -> Double {
    range.lowerBound + next() * (range.upperBound - range.lowerBound)
  }

  public mutating func chance(_ probability: Double) -> Bool { next() < probability }

  public mutating func pick<T>(_ items: [T]) -> T {
    items[min(items.count - 1, Int(next() * Double(items.count)))]
  }
}
