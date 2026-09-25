import Foundation

struct Tile: Hashable, Codable {
  let x: Int
  let y: Int

  func moved(_ direction: Direction) -> Tile {
    Tile(x: x + direction.dx, y: y + direction.dy)
  }

  func distance(to other: Tile) -> Int {
    abs(x - other.x) + abs(y - other.y)
  }
}

enum Direction: Int, CaseIterable {
  case north, east, south, west
  var dx: Int { [0, 1, 0, -1][rawValue] }
  var dy: Int { [-1, 0, 1, 0][rawValue] }
  var symbol: String { ["arrow.up", "arrow.right", "arrow.down", "arrow.left"][rawValue] }
  var name: String { ["North", "East", "South", "West"][rawValue] }

  func reflected(slash: Bool) -> Direction {
    let values: [Direction] =
      slash ? [.east, .north, .west, .south] : [.west, .south, .east, .north]
    return values[rawValue]
  }
}

struct Emitter {
  let tile: Tile
  let direction: Direction
  let circuit: Int
}

struct Sentry {
  let tile: Tile
  let facing: Direction
}

struct Room {
  let id: Int
  let title: String
  let collection: String
  let artifactName: String
  let briefing: String
  let map: [String]
  let emitters: [Emitter]
  let sentries: [Sentry]
  let par: Int

  var width: Int { map[0].count }
  var height: Int { map.count }
  var tiles: [Tile] {
    (0..<height).flatMap { y in (0..<width).map { Tile(x: $0, y: y) } }
  }
  func mark(_ tile: Tile) -> Character {
    guard tile.x >= 0, tile.x < width, tile.y >= 0, tile.y < height else { return "#" }
    return Array(map[tile.y])[tile.x]
  }
  func locate(_ mark: Character) -> Tile { tiles.first { self.mark($0) == mark }! }
  var start: Tile { locate("E") }
  var artifact: Tile { locate("A") }
  var mirrors: [Tile] { tiles.filter { mark($0) == "/" || mark($0) == "\\" } }
  var nodes: [Tile] { tiles.filter { mark($0).isNumber } }
  func circuit(at tile: Tile) -> Int { mark(tile).wholeNumberValue ?? 0 }
  func walkable(_ tile: Tile) -> Bool {
    let value = mark(tile)
    return value == "." || value == "E" || value == "A"
  }
}

enum HeistAction: Hashable {
  case move(Direction)
  case interact(Tile)
  case wait
}

enum Outcome: String, Codable { case playing, caught, escaped }

struct HeistState: Hashable, Codable {
  var player: Tile
  var turn = 0
  var power = 3
  var mirrorBits = 0
  var hasArtifact = false
  var outcome = Outcome.playing
}

struct BeamSegment {
  let from: Tile
  let to: Tile
  let searchlight: Bool
}

struct SecurityField {
  var danger = Set<Tile>()
  var segments: [BeamSegment] = []
}

enum HeistEngine {
  static func initial(_ room: Room) -> HeistState { HeistState(player: room.start) }

  static func field(_ room: Room, _ state: HeistState, nextTurn: Bool = false) -> SecurityField {
    var result = SecurityField()
    for emitter in room.emitters where state.power & (1 << emitter.circuit) != 0 {
      trace(
        room, state, origin: emitter.tile, direction: emitter.direction, range: 100,
        searchlight: false, into: &result)
    }
    for guardUnit in room.sentries {
      let direction = Direction(
        rawValue: (guardUnit.facing.rawValue + state.turn + (nextTurn ? 1 : 0)) % 4)!
      trace(
        room, state, origin: guardUnit.tile, direction: direction, range: 3, searchlight: true,
        into: &result)
    }
    return result
  }

  private static func trace(
    _ room: Room, _ state: HeistState, origin: Tile, direction: Direction, range: Int,
    searchlight: Bool, into field: inout SecurityField
  ) {
    var tile = origin
    var heading = direction
    var visited = Set<String>()
    for _ in 0..<range {
      let next = tile.moved(heading)
      if room.mark(next) == "#" { break }
      let key = "\(next.x),\(next.y),\(heading.rawValue)"
      if !visited.insert(key).inserted { break }
      field.segments.append(BeamSegment(from: tile, to: next, searchlight: searchlight))
      field.danger.insert(next)
      if room.nodes.contains(next) || room.emitters.contains(where: { $0.tile == next }) { break }
      if let index = room.mirrors.firstIndex(of: next) {
        let flipped = state.mirrorBits & (1 << index) != 0
        heading = heading.reflected(slash: (room.mark(next) == "/") != flipped)
      }
      tile = next
    }
  }

  static func applying(_ action: HeistAction, to state: HeistState, in room: Room) -> HeistState? {
    guard state.outcome == .playing else { return nil }
    var next = state
    switch action {
    case .move(let direction):
      let destination = state.player.moved(direction)
      guard room.walkable(destination) else { return nil }
      next.player = destination
      if field(room, state).danger.contains(destination) { next.outcome = .caught }
    case .interact(let tile):
      guard state.player.distance(to: tile) == 1 else { return nil }
      if let index = room.mirrors.firstIndex(of: tile) {
        next.mirrorBits ^= 1 << index
      } else if room.nodes.contains(tile) {
        next.power ^= 1 << room.circuit(at: tile)
      } else {
        return nil
      }
    case .wait:
      break
    }
    next.turn += 1
    if field(room, next).danger.contains(next.player) { next.outcome = .caught }
    if next.outcome != .caught {
      if next.player == room.artifact { next.hasArtifact = true }
      if next.player == room.start, next.hasArtifact { next.outcome = .escaped }
    }
    return next
  }

  static func actions(_ room: Room, _ state: HeistState) -> [HeistAction] {
    Direction.allCases.map(HeistAction.move)
      + (room.nodes + room.mirrors).filter {
        state.player.distance(to: $0) == 1
      }.map(HeistAction.interact) + [.wait]
  }
}

enum Rooms {
  static let all: [Room] = [
    Room(
      id: 1, title: "The quiet entrance", collection: "EAST WING", artifactName: "The Night Ruby",
      briefing:
        "Tap a mint-outlined neighbor to step. Reach the brass node and tap it to darken the laser.",
      map: [
        "#######", "#..A..#", "#.....#", "#>....#", "#.....#", "#.0...#", "#E....#", "#######",
      ],
      emitters: [Emitter(tile: Tile(x: 1, y: 3), direction: .east, circuit: 0)], sentries: [],
      par: 15
    ),
    Room(
      id: 2, title: "A different angle", collection: "HALL OF REFLECTIONS",
      artifactName: "Obsidian Bird",
      briefing:
        "Mirrors turn a beam by ninety degrees. Tap an adjacent mirror to redirect the corridor.",
      map: [
        "#######", "#.A...#", "#.....#", "#>./..#", "###..##", "#.....#", "#E....#", "#######",
      ],
      emitters: [Emitter(tile: Tile(x: 1, y: 3), direction: .east, circuit: 0)], sentries: [],
      par: 22
    ),
    Room(
      id: 3, title: "The watchful eye", collection: "SCULPTURE COURT", artifactName: "Golden Orbit",
      briefing:
        "Amber searchlights turn clockwise after every action. Dotted amber tiles show their next sweep.",
      map: [
        "#######", "#...A.#", "#.....#", "#..G..#", "#.....#", "#.....#", "#E....#", "#######",
      ],
      emitters: [], sentries: [Sentry(tile: Tile(x: 3, y: 3), facing: .north)], par: 17
    ),
    Room(
      id: 4, title: "Velvet divide", collection: "NORTH GALLERY", artifactName: "Velvet Moon",
      briefing:
        "Two independent circuits divide the gallery. Nodes I and II control matching emitters.",
      map: [
        "#######", "#..A..#", "#>....#", "#...1.#", "#....<#", "#.0...#", "#E....#", "#######",
      ],
      emitters: [
        Emitter(tile: Tile(x: 1, y: 2), direction: .east, circuit: 1),
        Emitter(tile: Tile(x: 5, y: 4), direction: .west, circuit: 0),
      ], sentries: [], par: 16
    ),
    Room(
      id: 5, title: "Borrowed light", collection: "MIRROR CHAMBER", artifactName: "Silver Echo",
      briefing:
        "The mirror is the only way through. Turn it, then follow the safe side of the room.",
      map: [
        "#######", "#A....#", "#.....#", "#>./..#", "###..##", "#.....#", "#E....#", "#######",
      ],
      emitters: [Emitter(tile: Tile(x: 1, y: 3), direction: .east, circuit: 0)], sentries: [],
      par: 24
    ),
    Room(
      id: 6, title: "The long shadow", collection: "MARBLE ATRIUM", artifactName: "Ivory Sentinel",
      briefing: "Cut the ruby circuit before crossing. Every interaction also advances the watch.",
      map: [
        "#######", "#...A.#", "#.....#", "#..G..#", "#>....#", "#.0...#", "#E....#", "#######",
      ],
      emitters: [Emitter(tile: Tile(x: 1, y: 4), direction: .east, circuit: 0)],
      sentries: [Sentry(tile: Tile(x: 3, y: 3), facing: .east)], par: 17
    ),
    Room(
      id: 7, title: "Double exposure", collection: "TWIN ROTUNDA", artifactName: "The Gemini",
      briefing:
        "Two watchmen, one rhythm. Use the corners as cover and wait when the next sweep closes in.",
      map: [
        "#######", "#..A..#", "#.G...#", "#...#.#", "#.....#", "#...G.#", "#E....#", "#######",
      ],
      emitters: [],
      sentries: [
        Sentry(tile: Tile(x: 2, y: 2), facing: .west),
        Sentry(tile: Tile(x: 4, y: 5), facing: .east),
      ], par: 18
    ),
    Room(
      id: 8, title: "The red thread", collection: "WEST ANNEX", artifactName: "Crimson Ribbon",
      briefing:
        "A reflection and a second circuit protect this piece. Read the beam all the way to its end.",
      map: [
        "#######", "#A....#", "#>....#", "#...1.#", "#>./..#", "###..##", "#E....#", "#######",
      ],
      emitters: [
        Emitter(tile: Tile(x: 1, y: 2), direction: .east, circuit: 1),
        Emitter(tile: Tile(x: 1, y: 4), direction: .east, circuit: 0),
      ], sentries: [], par: 29
    ),
    Room(
      id: 9, title: "An impeccable alibi", collection: "PRIVATE COLLECTION",
      artifactName: "Blue Hour",
      briefing:
        "Marble walls stop searchlights. Work around the watch, then turn the mirrored passage.",
      map: [
        "#######", "#A....#", "#.G...#", "#.....#", "#>./..#", "###..##", "#E....#", "#######",
      ],
      emitters: [Emitter(tile: Tile(x: 1, y: 4), direction: .east, circuit: 0)],
      sentries: [Sentry(tile: Tile(x: 2, y: 2), facing: .west)], par: 26
    ),
    Room(
      id: 10, title: "The final acquisition", collection: "MIDNIGHT VAULT",
      artifactName: "The Midnight Star",
      briefing:
        "One last masterpiece. Two circuits and the curator's watch stand between you and the complete collection.",
      map: [
        "#######", "#..A..#", "#>....#", "#...1.#", "#.G..<#", "#.0...#", "#E....#", "#######",
      ],
      emitters: [
        Emitter(tile: Tile(x: 1, y: 2), direction: .east, circuit: 1),
        Emitter(tile: Tile(x: 5, y: 4), direction: .west, circuit: 0),
      ], sentries: [Sentry(tile: Tile(x: 2, y: 4), facing: .north)], par: 19
    ),
  ]
}
