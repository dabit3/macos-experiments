import Foundation

enum Resource: Int, Codable, CaseIterable, Sendable {
  case grain, timber, stone
  var name: String { ["Grain", "Timber", "Stone"][rawValue] }
  var symbol: String { ["leaf.fill", "tree.fill", "shippingbox.fill"][rawValue] }
}

struct Island: Identifiable, Codable, Equatable, Sendable {
  let id: Int
  let name: String
  let subtitle: String
  let x: Double
  let y: Double
  let produces: Resource?
  let needs: [Resource]
  var inventory: [Int]
  var received = 0
  var underserved: Bool { needs.contains { inventory[$0.rawValue] < 4 } }
}

struct Ferry: Identifiable, Codable, Equatable, Sendable {
  let id: Int
  let name: String
  let capacity: Int
  let speed: Double
}

struct Route: Identifiable, Codable, Equatable, Sendable {
  let id: Int
  var source: Int
  var destination: Int
  var resource: Resource
  var ferryID: Int?
  var progress = 0.0
  var returning = false
  var cargo = 0
  var delivered = 0
}

enum GameError: String, Error, LocalizedError {
  case invalidRoute = "Choose different islands, and a destination that needs this resource."
  case budget = "A new route costs 60 coins. Deliver cargo to earn more."
  case duplicate = "These islands are already connected by this resource."
  case unavailableBoat = "That ferry already serves another route."
  case corruptSave = "This save could not be read safely. Your current voyage is unchanged."
  var errorDescription: String? { rawValue }
}

struct Game: Codable, Equatable, Sendable {
  static let fleet = [
    Ferry(id: 0, name: "Marigold", capacity: 12, speed: 1),
    Ferry(id: 1, name: "Juniper", capacity: 18, speed: 0.85),
    Ferry(id: 2, name: "Swift", capacity: 8, speed: 1.5),
    Ferry(id: 3, name: "Coral", capacity: 14, speed: 1.1),
  ]
  var version = 1
  var islands: [Island]
  var routes: [Route] = []
  var tick = 0
  var budget = 300
  var delivered = 0
  var produced = [0, 0, 0]
  var consumed = [0, 0, 0]
  var nextRouteID = 0
  var goalMet: Bool { delivered >= 36 && islands[4].received >= 8 }
  var day: Int { tick / 240 + 1 }
  var lanternDelivered: Int { islands[4].received }
  static var initial: Game {
    Game(islands: [
      Island(
        id: 0, name: "Sunfield", subtitle: "THE GOLDEN FIELDS", x: 0.24, y: 0.25,
        produces: .grain, needs: [], inventory: [48, 0, 0]),
      Island(
        id: 1, name: "Port Azure", subtitle: "THE HEART OF THE ISLES", x: 0.52, y: 0.47,
        produces: nil, needs: [.grain, .timber, .stone], inventory: [0, 0, 0]),
      Island(
        id: 2, name: "Pinehaven", subtitle: "THE WOODLAND PORT", x: 0.20, y: 0.72,
        produces: .timber, needs: [], inventory: [0, 48, 0]),
      Island(
        id: 3, name: "Roserock", subtitle: "THE QUARRY VILLAGE", x: 0.77, y: 0.21,
        produces: .stone, needs: [.timber], inventory: [0, 0, 36]),
      Island(
        id: 4, name: "Lantern Isle", subtitle: "THE DISTANT LIGHT", x: 0.80, y: 0.74,
        produces: nil, needs: [.grain], inventory: [0, 0, 0]),
    ])
  }

  func possibleDestinations(source: Int) -> [Island] {
    guard islands.indices.contains(source), let resource = islands[source].produces else {
      return []
    }
    return islands.filter { $0.id != source && $0.needs.contains(resource) }
  }

  mutating func createRoute(source: Int, destination: Int) throws {
    let resource = try validateRoute(source: source, destination: destination, excluding: nil)
    guard budget >= 60 else { throw GameError.budget }
    routes.append(
      Route(id: nextRouteID, source: source, destination: destination, resource: resource))
    nextRouteID += 1
    budget -= 60
  }

  private func validateRoute(source: Int, destination: Int, excluding: Int?) throws -> Resource {
    guard islands.indices.contains(source), islands.indices.contains(destination),
      let resource = islands[source].produces, source != destination,
      islands[destination].needs.contains(resource)
    else { throw GameError.invalidRoute }
    guard
      !routes.contains(where: {
        $0.id != excluding && $0.source == source && $0.destination == destination
      })
    else { throw GameError.duplicate }
    return resource
  }

  mutating func editRoute(id: Int, source: Int, destination: Int) throws {
    let resource = try validateRoute(source: source, destination: destination, excluding: id)
    guard let index = routes.firstIndex(where: { $0.id == id }) else {
      throw GameError.invalidRoute
    }
    returnCargo(index: index)
    routes[index].source = source
    routes[index].destination = destination
    routes[index].resource = resource
  }

  mutating func assign(ferryID: Int?, routeID: Int) throws {
    guard let index = routes.firstIndex(where: { $0.id == routeID }) else {
      throw GameError.invalidRoute
    }
    if let ferryID {
      guard Self.fleet.contains(where: { $0.id == ferryID }),
        !routes.contains(where: { $0.id != routeID && $0.ferryID == ferryID })
      else { throw GameError.unavailableBoat }
    }
    returnCargo(index: index)
    routes[index].ferryID = ferryID
  }

  private mutating func returnCargo(index: Int) {
    islands[routes[index].source].inventory[routes[index].resource.rawValue] += routes[index].cargo
    routes[index].cargo = 0
    routes[index].progress = 0
    routes[index].returning = false
  }

  mutating func removeRoute(id: Int) {
    guard let index = routes.firstIndex(where: { $0.id == id }) else { return }
    returnCargo(index: index)
    routes.remove(at: index)
    budget += 20
  }

  func duration(for route: Route) -> Double {
    let a = islands[route.source]
    let b = islands[route.destination]
    let distance = hypot(a.x - b.x, a.y - b.y)
    let speed = Self.fleet.first(where: { $0.id == route.ferryID })?.speed ?? 1
    return max(24, distance * 160) / speed
  }

  mutating func advance(steps: Int = 1) {
    guard steps > 0 else { return }
    for _ in 0..<steps {
      tick += 1
      for index in islands.indices {
        if tick.isMultiple(of: 24), let resource = islands[index].produces,
          islands[index].inventory[resource.rawValue] < 72
        {
          islands[index].inventory[resource.rawValue] += 2
          produced[resource.rawValue] += 2
        }
        if tick.isMultiple(of: 96) {
          for resource in islands[index].needs where islands[index].inventory[resource.rawValue] > 0
          {
            islands[index].inventory[resource.rawValue] -= 1
            consumed[resource.rawValue] += 1
          }
        }
      }
      for index in routes.indices {
        guard let boat = Self.fleet.first(where: { $0.id == routes[index].ferryID }) else {
          continue
        }
        let resource = routes[index].resource.rawValue
        let source = routes[index].source
        if routes[index].progress == 0 && !routes[index].returning {
          let quantity = min(boat.capacity, islands[source].inventory[resource])
          guard quantity > 0 else { continue }
          islands[source].inventory[resource] -= quantity
          routes[index].cargo = quantity
        }
        routes[index].progress += 1 / duration(for: routes[index])
        if routes[index].progress >= 1 {
          routes[index].progress = 0
          if !routes[index].returning {
            let destination = routes[index].destination
            let cargo = routes[index].cargo
            islands[destination].inventory[resource] += cargo
            islands[destination].received += cargo
            delivered += cargo
            routes[index].delivered += cargo
            budget += cargo * 3
            routes[index].cargo = 0
          }
          routes[index].returning.toggle()
        }
      }
    }
  }

  func total(resource: Resource) -> Int {
    islands.reduce(0) { $0 + $1.inventory[resource.rawValue] }
      + routes.filter { $0.resource == resource }.reduce(0) { $0 + $1.cargo }
  }

  func validate() throws {
    let original = Self.initial
    guard version == 1, islands.count == 5, produced.count == 3, consumed.count == 3,
      budget >= 0, tick >= 0, delivered >= 0, nextRouteID >= 0,
      produced.allSatisfy({ $0 >= 0 }), consumed.allSatisfy({ $0 >= 0 }),
      Set(routes.map(\.id)).count == routes.count
    else { throw GameError.corruptSave }
    for (index, island) in islands.enumerated() {
      let expected = original.islands[index]
      guard island.id == index, island.name == expected.name, island.x == expected.x,
        island.y == expected.y, island.produces == expected.produces,
        island.needs == expected.needs, island.inventory.count == 3,
        island.inventory.allSatisfy({ $0 >= 0 }), island.received >= 0
      else { throw GameError.corruptSave }
    }
    var assigned: Set<Int> = []
    var links: Set<String> = []
    for route in routes {
      guard route.id >= 0, route.id < nextRouteID,
        islands.indices.contains(route.source), islands.indices.contains(route.destination),
        route.source != route.destination, islands[route.source].produces == route.resource,
        islands[route.destination].needs.contains(route.resource),
        route.progress.isFinite, route.progress >= 0, route.progress < 1,
        route.cargo >= 0, route.delivered >= 0,
        links.insert("\(route.source)-\(route.destination)").inserted
      else { throw GameError.corruptSave }
      if let boatID = route.ferryID {
        guard let boat = Self.fleet.first(where: { $0.id == boatID }),
          assigned.insert(boatID).inserted, route.cargo <= boat.capacity,
          !route.returning || route.cargo == 0
        else { throw GameError.corruptSave }
      } else if route.cargo != 0 || route.progress != 0 || route.returning {
        throw GameError.corruptSave
      }
    }
    guard islands.reduce(0, { $0 + $1.received }) == delivered else { throw GameError.corruptSave }
    for resource in Resource.allCases {
      guard
        total(resource: resource) + consumed[resource.rawValue]
          == original.total(resource: resource) + produced[resource.rawValue]
      else { throw GameError.corruptSave }
    }
  }

  func encoded() throws -> Data {
    try validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decode(_ data: Data) throws -> Game {
    do {
      let value = try JSONDecoder().decode(Game.self, from: data)
      try value.validate()
      return value
    } catch {
      throw GameError.corruptSave
    }
  }
}
