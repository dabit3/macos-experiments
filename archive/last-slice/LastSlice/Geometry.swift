import Foundation

struct Point: Codable, Equatable {
  var x: Double
  var y: Double

  static func + (lhs: Point, rhs: Point) -> Point {
    Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
  }

  static func - (lhs: Point, rhs: Point) -> Point {
    Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }

  static func * (lhs: Point, rhs: Double) -> Point {
    Point(x: lhs.x * rhs, y: lhs.y * rhs)
  }

  var length: Double { hypot(x, y) }
}

struct Cut: Codable, Equatable {
  var start: Point
  var end: Point

  func side(of point: Point) -> Double {
    let direction = end - start
    let offset = point - start
    return direction.x * offset.y - direction.y * offset.x
  }

  static func line(angle: Double, offset: Double = 0) -> Cut {
    let direction = Point(x: cos(angle), y: sin(angle))
    let normal = Point(x: -direction.y, y: direction.x)
    return Cut(start: normal * offset - direction * 1.4, end: normal * offset + direction * 1.4)
  }
}

struct Polygon: Equatable {
  var vertices: [Point]

  static let pizza = Polygon(
    vertices: (0..<120).map {
      let angle = Double($0) * 2 * .pi / 120
      return Point(x: cos(angle), y: sin(angle))
    })

  var area: Double {
    guard vertices.count >= 3 else { return 0 }
    return abs(
      vertices.indices.reduce(0.0) { sum, index in
        let a = vertices[index]
        let b = vertices[(index + 1) % vertices.count]
        return sum + a.x * b.y - b.x * a.y
      }) / 2
  }

  var center: Point {
    guard !vertices.isEmpty else { return Point(x: 0, y: 0) }
    var weighted = Point(x: 0, y: 0)
    var total = 0.0
    for index in vertices.indices {
      let a = vertices[index]
      let b = vertices[(index + 1) % vertices.count]
      let cross = a.x * b.y - b.x * a.y
      weighted = weighted + (a + b) * cross
      total += cross
    }
    guard abs(total) > 0.000001 else { return vertices[0] }
    return weighted * (1 / (3 * total))
  }

  func clipped(by cut: Cut, positive: Bool) -> Polygon {
    guard vertices.count >= 3 else { return Polygon(vertices: []) }
    var result: [Point] = []
    for index in vertices.indices {
      let a = vertices[index]
      let b = vertices[(index + 1) % vertices.count]
      let da = cut.side(of: a) * (positive ? 1 : -1)
      let db = cut.side(of: b) * (positive ? 1 : -1)
      if da >= 0 { result.append(a) }
      if (da >= 0) != (db >= 0) {
        result.append(a + (b - a) * (da / (da - db)))
      }
    }
    return Polygon(vertices: result)
  }

  func contains(_ point: Point) -> Bool {
    guard vertices.count >= 3 else { return false }
    return vertices.indices.allSatisfy { index in
      Cut(start: vertices[index], end: vertices[(index + 1) % vertices.count])
        .side(of: point) >= -0.0000001
    }
  }

  func contains(_ point: Point, margin: Double) -> Bool {
    guard vertices.count >= 3 else { return false }
    return vertices.indices.allSatisfy { index in
      let a = vertices[index]
      let b = vertices[(index + 1) % vertices.count]
      let length = (b - a).length
      return length < 0.000001 || Cut(start: a, end: b).side(of: point) / length >= margin
    }
  }
}

enum ToppingKind: String, Codable, CaseIterable {
  case tomato, basil, olive
  var title: String {
    switch self {
    case .tomato: "tomato"
    case .basil: "basil"
    case .olive: "olive"
    }
  }
}

struct Topping: Identifiable {
  let id: Int
  let kind: ToppingKind
  let point: Point
}

struct Portion {
  let polygon: Polygon
  let toppings: [Topping]
  var fraction: Double { polygon.area / Polygon.pizza.area }
  func count(_ kind: ToppingKind) -> Int { toppings.filter { $0.kind == kind }.count }
}

struct Guest: Identifiable {
  let id: Int
  let name: String
  let fraction: Double
  let topping: ToppingKind
  let count: Int
  var percent: Int { Int((fraction * 100).rounded()) }
}

struct Dinner: Identifiable {
  let id: Int
  let title: String
  let subtitle: String
  let solution: [Cut]
  let toppings: [Topping]
  let guests: [Guest]
  var budget: Int { solution.count }
}

struct GuestMatch {
  let guest: Guest
  let portionIndex: Int?
  let fraction: Double
  let count: Int
  var areaPass: Bool {
    portionIndex != nil && abs(fraction - guest.fraction) <= Rules.tolerance + 0.0000001
  }
  var toppingPass: Bool { portionIndex != nil && count == guest.count }
  var passed: Bool { areaPass && toppingPass }
  var percent: Int { Int((fraction * 100).rounded()) }
}

struct Verdict {
  let matches: [GuestMatch]
  let portions: [Portion]
  let extraPortions: Int
  var success: Bool { extraPortions == 0 && matches.allSatisfy(\.passed) }
  var passedCount: Int { matches.filter(\.passed).count }
  var accuracy: Int {
    guard !matches.isEmpty else { return 0 }
    return Int(
      (100
        * matches.reduce(0.0) { sum, match in
          guard match.portionIndex != nil else { return sum }
          return sum + max(0, 1 - abs(match.fraction - match.guest.fraction))
        } / Double(matches.count)).rounded())
  }
  var stars: Int { success ? (accuracy >= 99 ? 3 : accuracy >= 97 ? 2 : 1) : 0 }
}

enum Rules {
  static let tolerance = 0.05
  static let minimumPortion = 0.01

  static func polygons(cuts: [Cut]) -> [Polygon] {
    cuts.reduce([Polygon.pizza]) { pieces, cut in
      pieces.flatMap { polygon in
        let halves = [
          polygon.clipped(by: cut, positive: true), polygon.clipped(by: cut, positive: false),
        ]
        return halves.filter { $0.area > 0.000001 }
      }
    }
  }

  static func valid(_ cut: Cut, after cuts: [Cut]) -> Bool {
    guard (cut.end - cut.start).length > 0.2 else { return false }
    let before = polygons(cuts: cuts)
    let after = polygons(cuts: cuts + [cut])
    return after.count > before.count
      && after.allSatisfy { $0.area / Polygon.pizza.area >= minimumPortion }
  }

  static func portions(cuts: [Cut], toppings: [Topping]) -> [Portion] {
    let pieces = polygons(cuts: cuts)
    var memberships = Array(repeating: [Topping](), count: pieces.count)
    for topping in toppings {
      if let index = pieces.firstIndex(where: { $0.contains(topping.point) }) {
        memberships[index].append(topping)
      }
    }
    return pieces.indices.map { Portion(polygon: pieces[$0], toppings: memberships[$0]) }
  }

  static func evaluate(_ portions: [Portion], guests: [Guest]) -> Verdict {
    var best: [GuestMatch] = []
    var bestCost = Double.infinity
    func visit(_ index: Int, used: Set<Int>, matches: [GuestMatch], cost: Double) {
      if cost >= bestCost { return }
      if index == guests.count {
        best = matches
        bestCost = cost
        return
      }
      let guest = guests[index]
      let available = portions.indices.filter { !used.contains($0) }
      for portionIndex in available {
        let portion = portions[portionIndex]
        let match = GuestMatch(
          guest: guest, portionIndex: portionIndex, fraction: portion.fraction,
          count: portion.count(guest.topping))
        let penalty =
          (match.passed ? 0.0 : 100.0)
          + abs(portion.fraction - guest.fraction)
          + (match.toppingPass ? 0 : 1)
        visit(
          index + 1, used: used.union([portionIndex]), matches: matches + [match],
          cost: cost + penalty)
      }
      if available.isEmpty || portions.count < guests.count {
        let missing = GuestMatch(guest: guest, portionIndex: nil, fraction: 0, count: 0)
        visit(index + 1, used: used, matches: matches + [missing], cost: cost + 102)
      }
    }
    visit(0, used: [], matches: [], cost: 0)
    return Verdict(
      matches: best, portions: portions, extraPortions: max(0, portions.count - guests.count))
  }
}

enum Menu {
  static let names = ["Luca", "Rosa", "Enzo", "Gia"]
  static let dinners: [Dinner] = {
    let recipes: [(String, String, [Cut])] = [
      ("A table for two", "One pizza. Two very particular people.", [.line(angle: .pi / 2)]),
      (
        "The little appetite", "Rosa says she's only a little hungry.",
        [.line(angle: .pi / 2, offset: 0.4)]
      ),
      (
        "Sunday, four ways", "Everyone gets a seat. Everyone gets a quarter.",
        [.line(angle: 0), .line(angle: .pi / 2)]
      ),
      ("The diagonal deal", "A different angle on dinner.", [.line(angle: .pi / 4)]),
      (
        "Three's company", "The middle child wants the middle slice.",
        [.line(angle: .pi / 2, offset: -0.28), .line(angle: .pi / 2, offset: 0.28)]
      ),
      ("Nonna's portion", "A little more for the one who cooked.", [.line(angle: 0, offset: 0.3)]),
      (
        "The crooked cross", "Four friends. No equal appetites.",
        [.line(angle: 0, offset: 0.18), .line(angle: .pi / 2, offset: -0.18)]
      ),
      (
        "Parallel cravings", "Three strips. Absolutely no sharing.",
        [.line(angle: .pi / 4, offset: -0.35), .line(angle: .pi / 4, offset: 0.35)]
      ),
      ("An olive affair", "There's an olive for every opinion.", [.line(angle: -.pi / 5)]),
      (
        "Off the grid", "The dinner conversation takes a sharp turn.",
        [.line(angle: .pi / 5), .line(angle: .pi * 0.7)]
      ),
      (
        "The tasting menu", "Four courses, on a single crust.",
        [
          .line(angle: .pi / 2, offset: -0.5), .line(angle: .pi / 2),
          .line(angle: .pi / 2, offset: 0.5),
        ]
      ),
      (
        "The last slice", "An improbable order. An exquisite finish.",
        [.line(angle: -.pi / 5, offset: 0.22), .line(angle: .pi * 0.3, offset: -0.22)]
      ),
    ]
    return recipes.enumerated().map { index, recipe in
      let polygons = Rules.polygons(cuts: recipe.2)
      var toppings: [Topping] = []
      for (pieceIndex, polygon) in polygons.enumerated() {
        let kind = ToppingKind.allCases[(index + pieceIndex) % 3]
        let count = 1 + ((index + pieceIndex) % 2)
        let accent = ToppingKind.allCases[(index + pieceIndex + 1) % 3]
        let positions = FoodLayout.toppingPositions(
          in: polygon, count: count + 1, existing: toppings)
        for (toppingKind, point) in zip(Array(repeating: kind, count: count) + [accent], positions)
        {
          toppings.append(
            Topping(id: toppings.count, kind: toppingKind, point: point)
          )
        }
      }
      let portions = Rules.portions(cuts: recipe.2, toppings: toppings)
      let guests = portions.enumerated().map { pieceIndex, portion in
        let kind = ToppingKind.allCases[(index + pieceIndex) % 3]
        return Guest(
          id: pieceIndex, name: names[pieceIndex],
          fraction: Double(Int((portion.fraction * 100).rounded())) / 100,
          topping: kind, count: portion.count(kind))
      }
      return Dinner(
        id: index, title: recipe.0, subtitle: recipe.1, solution: recipe.2, toppings: toppings,
        guests: guests)
    }
  }()

  static func dailyIndex(date: Date = Date()) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 1
    return day % dinners.count
  }
}

enum FoodLayout {
  static let grid = (-10...10).flatMap { row in
    (-10...10).map { column in Point(x: Double(column) * 0.08, y: Double(row) * 0.08) }
  }

  static func toppingPositions(in polygon: Polygon, count: Int, existing: [Topping]) -> [Point] {
    let candidates = grid.filter { $0.length <= 0.84 && polygon.contains($0, margin: 0.14) }
    var best = Array(repeating: polygon.center, count: count)
    var bestScore = -Double.infinity
    for seed in candidates {
      var layout = [seed]
      while layout.count < count {
        let occupied = existing.map(\.point) + layout
        let next =
          candidates.max { lhs, rhs in
            let left = occupied.map { ($0 - lhs).length }.min() ?? 0
            let right = occupied.map { ($0 - rhs).length }.min() ?? 0
            return left < right
          } ?? polygon.center
        layout.append(next)
      }
      let separation =
        layout.enumerated().flatMap { index, point in
          (Array(layout.dropFirst(index + 1)) + existing.map(\.point)).map { ($0 - point).length }
        }.min() ?? 0
      let score =
        min(separation, 0.55) - layout.reduce(0) { $0 + ($1 - polygon.center).length } * 0.02
      if score > bestScore {
        best = layout
        bestScore = score
      }
    }
    return best
  }

  static func labelPosition(
    in polygon: Polygon, toppings: [Topping], halfWidth: Double, halfHeight: Double
  ) -> Point? {
    let candidates = grid.filter { point in
      let corners = [
        Point(x: -halfWidth, y: -halfHeight), Point(x: halfWidth, y: -halfHeight),
        Point(x: -halfWidth, y: halfHeight), Point(x: halfWidth, y: halfHeight),
      ]
      guard corners.allSatisfy({ polygon.contains(point + $0, margin: 0.035) }) else {
        return false
      }
      return toppings.allSatisfy { topping in
        let dx = max(0, abs(topping.point.x - point.x) - halfWidth)
        let dy = max(0, abs(topping.point.y - point.y) - halfHeight)
        return hypot(dx, dy) > 0.16
      }
    }
    return candidates.min { ($0 - polygon.center).length < ($1 - polygon.center).length }
  }
}
