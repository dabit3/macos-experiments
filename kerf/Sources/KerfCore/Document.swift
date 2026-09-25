import Foundation

public enum ShapeKind: String, Codable, CaseIterable, Sendable {
  case rectangle, circle, polyline
}

public enum Operation: String, Codable, CaseIterable, Sendable {
  case cut, engrave
}

public struct Point: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
}

public struct Part: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var name: String
  public var kind: ShapeKind
  public var operation: Operation
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double
  public var points: [Point]

  public init(
    name: String, kind: ShapeKind, operation: Operation = .cut, x: Double, y: Double,
    width: Double, height: Double, points: [Point] = []
  ) {
    id = UUID()
    self.name = name
    self.kind = kind
    self.operation = operation
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.points = points
  }

  public var vertices: [Point] {
    points.map { Point(x + $0.x * width, y + $0.y * height) }
  }

  public func contains(_ p: Point, tolerance: Double = 1) -> Bool {
    switch kind {
    case .rectangle:
      return p.x >= x - tolerance && p.x <= x + width + tolerance
        && p.y >= y - tolerance && p.y <= y + height + tolerance
    case .circle:
      let dx = (p.x - x - width / 2) / (width / 2 + tolerance)
      let dy = (p.y - y - height / 2) / (height / 2 + tolerance)
      return dx * dx + dy * dy <= 1
    case .polyline:
      return zip(vertices, vertices.dropFirst()).contains { a, b in
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
        return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy) <= tolerance + 1
      }
    }
  }
}

public struct Design: Codable, Equatable, Sendable {
  public var version: Int = 1
  public var title: String = "Alpine / coaster collection"
  public var sheetWidth: Double = 320
  public var sheetHeight: Double = 240
  public var kerf: Double = 0.15
  public var compensate: Bool = false
  public var material: String = "Birch plywood"
  public var parts: [Part] = []

  public init() {}

  public static var sample: Design {
    var design = Design()
    design.sheetWidth = 360
    design.parts = [
      Part(name: "01 / Alpine coaster", kind: .circle, x: 22, y: 25, width: 86, height: 86),
      Part(
        name: "Alpine / inner ring", kind: .circle, operation: .engrave, x: 29, y: 32, width: 72,
        height: 72),
      Part(
        name: "Alpine / ridgeline", kind: .polyline, operation: .engrave, x: 38, y: 49, width: 54,
        height: 32,
        points: [Point(0, 1), Point(0.31, 0.22), Point(0.46, 0.55), Point(0.66, 0), Point(1, 1)]),
      Part(
        name: "Alpine / horizon", kind: .polyline, operation: .engrave, x: 43, y: 87, width: 44,
        height: 1,
        points: [Point(0, 0), Point(1, 0)]),
      Part(name: "02 / Utility panel", kind: .rectangle, x: 145, y: 25, width: 145, height: 86),
      Part(
        name: "Panel / inset", kind: .rectangle, operation: .engrave, x: 153, y: 33, width: 129,
        height: 70),
      Part(
        name: "Panel / index line", kind: .polyline, operation: .engrave, x: 165, y: 68, width: 105,
        height: 20,
        points: [
          Point(0, 1), Point(0.2, 0), Point(0.4, 1), Point(0.6, 0), Point(0.8, 1), Point(1, 0),
        ]),
      Part(name: "03 / Blank coaster", kind: .circle, x: 22, y: 139, width: 86, height: 86),
      Part(name: "04 / Studio tile", kind: .rectangle, x: 145, y: 139, width: 86, height: 86),
      Part(
        name: "Tile / signature", kind: .polyline, operation: .engrave, x: 164, y: 161, width: 48,
        height: 42,
        points: [Point(0, 1), Point(0, 0), Point(1, 1), Point(1, 0)]),
    ]
    return design
  }

  public func validated() throws -> Design {
    guard version == 1 else { throw DesignError.invalid("Unsupported document version.") }
    guard sheetWidth.isFinite, sheetHeight.isFinite, (20...2000).contains(sheetWidth),
      (20...2000).contains(sheetHeight), kerf.isFinite, (0...2).contains(kerf),
      parts.count <= 2000, Set(parts.map(\.id)).count == parts.count
    else { throw DesignError.invalid("Invalid sheet, kerf, or part count.") }
    for part in parts {
      guard [part.x, part.y, part.width, part.height].allSatisfy(\.isFinite),
        abs(part.x) <= 10000, abs(part.y) <= 10000,
        (0.1...2000).contains(part.width), (0.1...2000).contains(part.height),
        part.kind != .circle || abs(part.width - part.height) < 0.0001,
        part.points.count <= 10000,
        part.kind != .polyline || part.points.count >= 2,
        part.points.allSatisfy({
          $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)
        })
      else { throw DesignError.invalid("Invalid geometry in “\(part.name)”.") }
    }
    return self
  }

  public var outOfBounds: Set<UUID> {
    Set(
      parts.filter { p in
        let offset = compensate && p.operation == .cut && p.kind != .polyline ? kerf / 2 : 0
        return p.x - offset < 0 || p.y - offset < 0 || p.x + p.width + offset > sheetWidth
          || p.y + p.height + offset > sheetHeight
      }.map(\.id))
  }

  public var overlapPairs: [(UUID, UUID)] {
    let cuts = parts.filter { $0.operation == .cut }
    var pairs: [(UUID, UUID)] = []
    for i in cuts.indices {
      for j in cuts.indices where j > i {
        if Self.overlaps(cuts[i], cuts[j], clearance: compensate ? kerf : 0) {
          pairs.append((cuts[i].id, cuts[j].id))
        }
      }
    }
    return pairs
  }

  public static func overlaps(_ a: Part, _ b: Part, clearance: Double = 0) -> Bool {
    guard a.x < b.x + b.width + clearance, b.x < a.x + a.width + clearance,
      a.y < b.y + b.height + clearance, b.y < a.y + a.height + clearance
    else { return false }
    if a.kind == .circle && b.kind == .circle {
      return hypot(a.x + a.width / 2 - b.x - b.width / 2, a.y + a.height / 2 - b.y - b.height / 2)
        < (a.width + b.width) / 2 + clearance
    }
    if a.kind == .circle && b.kind == .rectangle { return circleRect(a, b, clearance) }
    if b.kind == .circle && a.kind == .rectangle { return circleRect(b, a, clearance) }
    return true
  }

  private static func circleRect(_ circle: Part, _ rect: Part, _ gap: Double) -> Bool {
    let cx = circle.x + circle.width / 2
    let cy = circle.y + circle.height / 2
    return hypot(
      cx - max(rect.x, min(cx, rect.x + rect.width)),
      cy - max(rect.y, min(cy, rect.y + rect.height)))
      < circle.width / 2 + gap
  }

  public func svg() throws -> String {
    _ = try validated()
    func f(_ value: Double) -> String {
      String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    func escaped(_ value: String) -> String {
      value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    var lines = [
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(f(sheetWidth))mm\" height=\"\(f(sheetHeight))mm\" viewBox=\"0 0 \(f(sheetWidth)) \(f(sheetHeight))\">",
      "<title>\(escaped(title))</title>",
      "<desc>Kerf: \(f(kerf)) mm. Outside compensation \(compensate ? "enabled for circles and rectangles" : "off"). Open polylines use their centerline. Red=cut; blue=engrave.</desc>",
    ]
    for op in Operation.allCases {
      lines.append(
        "<g id=\"\(op.rawValue)\" fill=\"none\" stroke=\"\(op == .cut ? "#e04040" : "#2466ba")\" stroke-width=\"0.1\" stroke-linejoin=\"round\" stroke-linecap=\"round\">"
      )
      for p in parts where p.operation == op {
        let offset = compensate && op == .cut && p.kind != .polyline ? kerf / 2 : 0
        let label = "<title>\(escaped(p.name))</title>"
        switch p.kind {
        case .rectangle:
          lines.append(
            "<rect x=\"\(f(p.x - offset))\" y=\"\(f(p.y - offset))\" width=\"\(f(p.width + offset * 2))\" height=\"\(f(p.height + offset * 2))\">\(label)</rect>"
          )
        case .circle:
          lines.append(
            "<circle cx=\"\(f(p.x + p.width / 2))\" cy=\"\(f(p.y + p.height / 2))\" r=\"\(f(p.width / 2 + offset))\">\(label)</circle>"
          )
        case .polyline:
          lines.append(
            "<polyline points=\"\(p.vertices.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " "))\">\(label)</polyline>"
          )
        }
      }
      lines.append("</g>")
    }
    lines.append("</svg>")
    return lines.joined(separator: "\n")
  }
}

public enum DesignError: LocalizedError {
  case invalid(String)
  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

public struct History: Sendable {
  public private(set) var past: [Design] = []
  public private(set) var future: [Design] = []
  public init() {}
  public mutating func record(_ current: Design) {
    past.append(current)
    if past.count > 100 { past.removeFirst() }
    future.removeAll()
  }
  public mutating func undo(_ current: Design) -> Design? {
    guard let previous = past.popLast() else { return nil }
    future.append(current)
    return previous
  }
  public mutating func redo(_ current: Design) -> Design? {
    guard let next = future.popLast() else { return nil }
    past.append(current)
    return next
  }
}
