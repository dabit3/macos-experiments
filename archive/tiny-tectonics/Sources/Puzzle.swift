import Foundation

struct GridPoint: Equatable {
  let x: Int
  let y: Int
}

struct Landscape: Identifiable {
  let id: Int
  let name: String
  let region: String
  let subtitle: String
  let route: [GridPoint]
  let initial: [Int]
  let fixed: Set<Int>
  let fossils: Set<Int>

  var par: Int { SlopeRules.minimumMoves(initial: initial, fixed: fixed) }
  var budget: Int { par + 2 }

  static let all: [Landscape] = [
    Landscape(
      id: 0, name: "First fold", region: "THE OCHRE VALLEY",
      subtitle: "A single lift can change the course of a world.",
      route: path([0, 0, 1, 0, 1, 1, 2, 1, 2, 2]),
      initial: [3, 1, 2, 1, 0], fixed: [0, 4], fossils: [2, 3]),
    Landscape(
      id: 1, name: "River steps", region: "THE OCHRE VALLEY",
      subtitle: "Build a gentle stair above the turquoise water.",
      route: path([0, 0, 1, 0, 1, 1, 2, 1, 3, 1, 3, 2]),
      initial: [4, 2, 3, 2, 1, 0], fixed: [0, 5], fossils: [1, 4]),
    Landscape(
      id: 2, name: "Pine bend", region: "THE OCHRE VALLEY",
      subtitle: "The quietest route runs between the trees.",
      route: path([0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 2]),
      initial: [4, 3, 1, 3, 1, 0], fixed: [0, 5], fossils: [2, 4]),
    Landscape(
      id: 3, name: "Sunken terrace", region: "THE RIVERLANDS",
      subtitle: "Some valleys need lifting. Some peaks need lowering.",
      route: path([0, 0, 1, 0, 2, 0, 2, 1, 2, 2, 3, 2, 3, 3]),
      initial: [4, 2, 4, 2, 0, 1, 0], fixed: [0, 3, 6], fossils: [2, 5]),
    Landscape(
      id: 4, name: "Amber crossing", region: "THE RIVERLANDS",
      subtitle: "Follow the fossils over a long, low bridge.",
      route: path([0, 0, 0, 1, 1, 1, 2, 1, 2, 2, 2, 3, 3, 3]),
      initial: [3, 1, 3, 2, 2, 0, 0], fixed: [0, 3, 6], fossils: [1, 4, 5]),
    Landscape(
      id: 5, name: "Fault line", region: "THE RIVERLANDS",
      subtitle: "An ancient shelf anchors both halves of the journey.",
      route: path([0, 0, 1, 0, 1, 1, 1, 2, 2, 2, 3, 2, 3, 3]),
      initial: [5, 3, 4, 2, 3, 0, 0], fixed: [0, 3, 6], fossils: [2, 4]),
    Landscape(
      id: 6, name: "Cloud islands", region: "THE HIGH COUNTRY",
      subtitle: "A chain of tiny worlds, balanced above the mist.",
      route: path([0, 0, 1, 0, 2, 0, 2, 1, 3, 1, 3, 2, 4, 2, 4, 3]),
      initial: [5, 3, 4, 2, 3, 2, 0, 0], fixed: [0, 4, 7], fossils: [1, 3, 6]),
    Landscape(
      id: 7, name: "Copper canyon", region: "THE HIGH COUNTRY",
      subtitle: "Carve a cascading route through the copper cliffs.",
      route: path([0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 3]),
      initial: [5, 5, 2, 3, 1, 3, 1, 0], fixed: [0, 3, 7], fossils: [2, 4, 6]),
    Landscape(
      id: 8, name: "The long descent", region: "THE HIGH COUNTRY",
      subtitle: "Let gravity draw one unbroken line.",
      route: path([0, 0, 1, 0, 2, 0, 2, 1, 2, 2, 3, 2, 3, 3, 4, 3, 4, 4]),
      initial: [5, 3, 5, 3, 1, 3, 2, 0, 0], fixed: [0, 4, 8], fossils: [2, 5, 7]),
    Landscape(
      id: 9, name: "A world in balance", region: "THE LAST HORIZON",
      subtitle: "Every small adjustment leaves a lasting landscape.",
      route: path([0, 0, 0, 1, 1, 1, 2, 1, 2, 2, 2, 3, 3, 3, 4, 3, 4, 4]),
      initial: [5, 5, 2, 4, 2, 0, 3, 0, 0], fixed: [0, 4, 8], fossils: [1, 3, 6, 7]),
  ]

  private static func path(_ values: [Int]) -> [GridPoint] {
    stride(from: 0, to: values.count, by: 2).map { GridPoint(x: values[$0], y: values[$0 + 1]) }
  }
}

enum SlopeFault: Equatable {
  case uphill
  case cliff

  var title: String { self == .uphill ? "A little too steep." : "Mind the gap." }
  var explanation: String {
    self == .uphill
      ? "The explorer cannot roll uphill. Lower the next plate, or raise the one before it."
      : "That drop is more than one layer. Lift the next plate to make a safe step."
  }
}

struct RouteOutcome: Equatable {
  let reached: Int
  let fault: SlopeFault?
  let fossils: Int
}

enum SlopeRules {
  static func fault(from: Int, to: Int) -> SlopeFault? {
    if to > from { return .uphill }
    if from - to > 1 { return .cliff }
    return nil
  }

  static func evaluate(_ heights: [Int], fossils: Set<Int>) -> RouteOutcome {
    guard !heights.isEmpty else { return RouteOutcome(reached: 0, fault: nil, fossils: 0) }
    for index in 1..<heights.count {
      if let fault = fault(from: heights[index - 1], to: heights[index]) {
        return RouteOutcome(
          reached: index - 1, fault: fault, fossils: fossils.filter { $0 < index }.count)
      }
    }
    return RouteOutcome(reached: heights.count - 1, fault: nil, fossils: fossils.count)
  }

  static func minimumMoves(initial: [Int], fixed: Set<Int>) -> Int {
    var costs = (0...5).map { height in
      fixed.contains(0) && height != initial[0] ? 10_000 : abs(height - initial[0])
    }
    for index in 1..<initial.count {
      costs = (0...5).map { height in
        guard !fixed.contains(index) || height == initial[index] else { return 10_000 }
        let predecessor = min(costs[height], height < 5 ? costs[height + 1] : 10_000)
        return predecessor + abs(height - initial[index])
      }
    }
    return costs.min() ?? 10_000
  }
}
