import Foundation

struct IslandRNG {
  var state: UInt32
  init(_ seed: Int) {
    state = UInt32(truncatingIfNeeded: seed)
    if state == 0 { state = 0x9E37_79B9 }
  }
  mutating func next() -> UInt32 {
    state ^= state &<< 13
    state ^= state >> 17
    state ^= state &<< 5
    return state
  }
  mutating func unit() -> Double { Double(next()) / 4_294_967_296 }
  mutating func int(_ maximum: Int) -> Int { maximum <= 0 ? 0 : Int(next()) % maximum }
  mutating func range(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }
  mutating func chance(_ probability: Double) -> Bool { unit() < probability }
  func fork(_ salt: Int) -> IslandRNG {
    IslandRNG(Int(state ^ (UInt32(truncatingIfNeeded: salt) &* 0x45D9F3B)))
  }
}

struct IslandNoise {
  let salt: UInt32
  init(_ rng: IslandRNG) {
    var rng = rng
    salt = rng.next()
  }
  func hash(_ x: Int, _ y: Int) -> Double {
    var value =
      UInt32(truncatingIfNeeded: x) &* 374_761_393
      &+ UInt32(truncatingIfNeeded: y) &* 668_265_263 &+ salt
    value = (value ^ (value >> 13)) &* 1_274_126_177
    value ^= value >> 16
    return Double(value & 0xFFFF) / 65_535
  }
  func value(_ x: Double, _ y: Double) -> Double {
    let x0 = Int(floor(x))
    let y0 = Int(floor(y))
    let fx = x - Double(x0)
    let fy = y - Double(y0)
    let sx = fx * fx * (3 - 2 * fx)
    let sy = fy * fy * (3 - 2 * fy)
    let top = hash(x0, y0) + (hash(x0 + 1, y0) - hash(x0, y0)) * sx
    let bottom = hash(x0, y0 + 1) + (hash(x0 + 1, y0 + 1) - hash(x0, y0 + 1)) * sx
    return top + (bottom - top) * sy
  }
  func fbm(_ x: Double, _ y: Double, _ octaves: Int) -> Double {
    var amplitude = 0.5
    var frequency = 1.0
    var sum = 0.0
    var norm = 0.0
    for _ in 0..<octaves {
      sum += value(x * frequency, y * frequency) * amplitude
      norm += amplitude
      amplitude *= 0.5
      frequency *= 2
    }
    return sum / norm
  }
}
enum Terrain: Int, Codable {
  case water, sand, grass, meadow, dirt, road, rock
  var rgb: UInt32 {
    switch self {
    case .water: return 0x117FA3
    case .sand: return 0xF0D595
    case .grass: return 0x81B957
    case .meadow: return 0xACCD67
    case .dirt: return 0xC0A474
    case .road: return 0x566D79
    case .rock: return 0x8AABAF
    }
  }
}
struct PointOfInterest: Codable {
  let name: String
  let x, y, r: Double
}

final class Island {
  let rules: Rules
  let seed: Int
  let n: Int
  var terrain: [Terrain]
  var pois: [PointOfInterest] = []
  var nodes: [Int: ResourceNode] = [:]
  var chests: [Int: Chest] = [:]
  var structures: [Int: Structure] = [:]
  var nodesByTile: [Int: [Int]] = [:]
  private var occupied: Set<Int> = []

  init(rules: Rules, seed: Int) {
    self.rules = rules
    self.seed = seed
    n = Int((rules.mapSize / rules.tileSize).rounded())
    terrain = Array(repeating: .water, count: n * n)
    let rng = IslandRNG(seed)
    let noise = IslandNoise(rng.fork(11))
    for gy in 0..<n {
      for gx in 0..<n {
        let x = Double(gx)
        let y = Double(gy)
        let half = Double(n) / 2
        let distance = hypot(x + 0.5 - half, y + 0.5 - half) / (rules.islandRadius / rules.tileSize)
        let shape = noise.fbm(x / 46, y / 46, 3) * 0.34 - 0.17
        let height = 1 - distance + shape
        let lake = noise.fbm(x / 22 + 900, y / 22 + 900, 2)
        let tile: Terrain
        if height < 0.02 {
          tile = .water
        } else if height < 0.075 {
          tile = .sand
        } else if lake > 0.74 && height > 0.25 {
          tile = .water
        } else if lake > 0.70 && height > 0.25 {
          tile = .sand
        } else {
          let detail = noise.fbm(x / 9 + 300, y / 9 + 300, 2)
          if height > 0.62 && detail > 0.55 {
            tile = .rock
          } else if detail > 0.63 {
            tile = .meadow
          } else if detail < 0.36 {
            tile = .dirt
          } else {
            tile = .grass
          }
        }
        terrain[key(gx, gy)] = tile
      }
    }
    placePOIs(rng.fork(21))
    for index in pois.indices { road(pois[index], pois[(index + 1) % pois.count]) }
    placeBuildings(rng.fork(31))
    placeNodes(noise, rng.fork(41))
    for node in nodes.values {
      nodesByTile[key(tile(node.x), tile(node.y)), default: []].append(node.id)
    }
  }
  func tile(_ value: Double) -> Int { Int(floor(value / rules.tileSize)) }
  func center(_ grid: Int) -> Double { (Double(grid) + 0.5) * rules.tileSize }
  func key(_ x: Int, _ y: Int) -> Int { y * n + x }
  func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < n && y < n }
  func at(_ x: Int, _ y: Int) -> Terrain { inBounds(x, y) ? terrain[key(x, y)] : .water }
  private func landPatch(_ gx: Int, _ gy: Int, _ radius: Int) -> Bool {
    for y in (gy - radius)...(gy + radius) {
      for x in (gx - radius)...(gx + radius) where at(x, y) == .water { return false }
    }
    return true
  }
  private func placePOIs(_ generator: IslandRNG) {
    var rng = generator
    var names = [
      "Ember Yards", "Saltwick", "Hollow Pines", "Gridlock Depot",
      "Marrow Heights", "Cinder Flats", "Old Tidewall", "Quillmarket",
    ]
    for _ in 0..<4000 {
      if pois.count >= 6 { break }
      let x = rng.range(rules.mapSize * 0.22, rules.mapSize * 0.78)
      let y = rng.range(rules.mapSize * 0.22, rules.mapSize * 0.78)
      guard landPatch(tile(x), tile(y), 9) else { continue }
      guard !pois.contains(where: { pow($0.x - x, 2) + pow($0.y - y, 2) < 170 * 170 }) else {
        continue
      }
      let name = names.remove(at: rng.int(names.count))
      pois.append(PointOfInterest(name: name, x: x, y: y, r: rng.range(48, 70)))
    }
  }
  private func road(_ a: PointOfInterest, _ b: PointOfInterest) {
    var x = tile(a.x)
    var y = tile(a.y)
    let x1 = tile(b.x)
    let y1 = tile(b.y)
    let dx = abs(x1 - x)
    let dy = -abs(y1 - y)
    let sx = x < x1 ? 1 : -1
    let sy = y < y1 ? 1 : -1
    var error = dx + dy
    while true {
      for oy in 0...1 {
        for ox in 0...1 where inBounds(x + ox, y + oy) {
          if at(x + ox, y + oy) != .water && at(x + ox, y + oy) != .sand {
            terrain[key(x + ox, y + oy)] = .road
          }
        }
      }
      if x == x1 && y == y1 { break }
      let twice = error * 2
      if twice >= dy {
        error += dy
        x += sx
      }
      if twice <= dx {
        error += dx
        y += sy
      }
    }
  }
  private func addChest(_ gx: Int, _ gy: Int) {
    let id = chests.count + 1
    chests[id] = Chest(id: id, x: center(gx), y: center(gy))
  }
  private func placeBuildings(_ generator: IslandRNG) {
    var rng = generator
    var structureID = 1
    for poi in pois {
      let houses = 3 + rng.int(3)
      var placed = 0
      for _ in 0..<60 {
        if placed >= houses { break }
        let width = 4 + rng.int(3)
        let height = 3 + rng.int(3)
        let cx = poi.x + rng.range(-poi.r, poi.r)
        let cy = poi.y + rng.range(-poi.r, poi.r)
        let gx = tile(cx) - width / 2
        let gy = tile(cy) - height / 2
        var okay = true
        for y in (gy - 1)...(gy + height) {
          for x in (gx - 1)...(gx + width) {
            if at(x, y) == .water || occupied.contains(key(x, y)) { okay = false }
          }
        }
        if !okay { continue }
        let material: BuildingMaterial = rng.chance(0.3) ? .metal : .stone
        let doorSide = rng.int(4)
        let doorOffset = 1 + rng.int(max(1, (doorSide.isMultiple(of: 2) ? width : height) - 2))
        for y in gy..<(gy + height) {
          for x in gx..<(gx + width) {
            let edge = x == gx || x == gx + width - 1 || y == gy || y == gy + height - 1
            occupied.insert(key(x, y))
            var edit: PieceEdit = .none
            if edge {
              let door: Bool
              switch doorSide {
              case 0: door = y == gy && x == gx + doorOffset
              case 1: door = x == gx + width - 1 && y == gy + doorOffset
              case 2: door = y == gy + height - 1 && x == gx + doorOffset
              default: door = x == gx && y == gy + doorOffset
              }
              if door { edit = .door } else if rng.chance(0.18) { edit = .window }
            }
            let mat: BuildingMaterial = edge ? material : .wood
            structures[key(x, y)] = Structure(
              id: structureID, gx: x, gy: y,
              p: edge ? .wall : .floor, m: mat, t: -1, hp: mat.maxHP, max: mat.maxHP, e: edit)
            structureID += 1
          }
        }
        let count = 1 + (rng.chance(0.35) ? 1 : 0)
        for _ in 0..<count {
          addChest(gx + 1 + rng.int(max(1, width - 2)), gy + 1 + rng.int(max(1, height - 2)))
        }
        placed += 1
      }
      for _ in 0..<3 {
        let x = poi.x + rng.range(-poi.r, poi.r)
        let y = poi.y + rng.range(-poi.r, poi.r)
        let gx = tile(x)
        let gy = tile(y)
        if at(gx, gy) != .water && !occupied.contains(key(gx, gy)) {
          occupied.insert(key(gx, gy))
          addChest(gx, gy)
        }
      }
    }
    for _ in 0..<3000 {
      if chests.count >= pois.count * 6 + 24 { break }
      let gx = rng.int(n)
      let gy = rng.int(n)
      if at(gx, gy) == .water || at(gx, gy) == .sand || occupied.contains(key(gx, gy)) { continue }
      occupied.insert(key(gx, gy))
      addChest(gx, gy)
    }
  }
  private func placeNodes(_ noise: IslandNoise, _ generator: IslandRNG) {
    var rng = generator
    func add(_ kind: ResourceKind, _ x: Double, _ y: Double, _ variant: Int) {
      let id = nodes.count + 1
      nodes[id] = ResourceNode(id: id, k: kind, x: x, y: y, hp: kind.hp, max: kind.hp, v: variant)
    }
    for gy in stride(from: 2, to: n - 2, by: 3) {
      for gx in stride(from: 2, to: n - 2, by: 3) {
        let terrain = at(gx, gy)
        if [.water, .sand, .road].contains(terrain) || occupied.contains(key(gx, gy)) { continue }
        let forest = noise.fbm(Double(gx) / 14 + 5000, Double(gy) / 14 + 5000, 2)
        var kind: ResourceKind?
        if terrain == .rock {
          if rng.chance(0.55) { kind = .rock }
        } else if forest > 0.56 && rng.chance(0.7) {
          kind = .tree
        } else if terrain == .dirt && rng.chance(0.12) {
          kind = .rock
        }
        if let kind {
          let x = (Double(gx) + rng.range(0.2, 0.8)) * rules.tileSize
          let y = (Double(gy) + rng.range(0.2, 0.8)) * rules.tileSize
          add(kind, x, y, rng.int(4))
        }
      }
    }
    for poi in pois {
      for _ in 0..<5 {
        let x = poi.x + rng.range(-poi.r * 1.3, poi.r * 1.3)
        let y = poi.y + rng.range(-poi.r * 1.3, poi.r * 1.3)
        if at(tile(x), tile(y)) == .water || occupied.contains(key(tile(x), tile(y))) { continue }
        add(.car, x, y, rng.int(4))
      }
    }
  }
  func blocked(_ x: Double, _ y: Double) -> Bool {
    let radius = rules.playerRadius
    func circleHits(_ gx: Int, _ gy: Int, _ r: Double) -> Bool {
      let x0 = Double(gx) * rules.tileSize
      let y0 = Double(gy) * rules.tileSize
      let dx = x - min(max(x, x0), x0 + rules.tileSize)
      let dy = y - min(max(y, y0), y0 + rules.tileSize)
      return dx * dx + dy * dy < r * r
    }
    for gy in tile(y - radius)...tile(y + radius) {
      for gx in tile(x - radius)...tile(x + radius) {
        if !inBounds(gx, gy) { return true }
        let structure = structures[key(gx, gy)]
        if let structure, structure.p == .wall && structure.e != .door && circleHits(gx, gy, radius)
        {
          return true
        }
        if structure == nil && at(gx, gy) == .water && circleHits(gx, gy, radius * 0.5) {
          return true
        }
        for id in nodesByTile[key(gx, gy)] ?? [] {
          guard let node = nodes[id], node.hp > 0, node.k != .tree else { continue }
          if hypot(node.x - x, node.y - y) < node.k.radius * 0.6 + radius { return true }
        }
      }
    }
    return false
  }
  func move(_ player: inout Player, frame: InputFrame) {
    guard player.s == .alive, player.con else { return }
    let speed =
      rules.moveSpeed * (frame.sprint && !frame.fire ? rules.sprintMultiplier : 1)
      * (player.rl || player.us ? 0.6 : 1)
    let nx = player.x + frame.mx * speed * rules.dt
    let ny = player.y + frame.my * speed * rules.dt
    if !blocked(nx, player.y) { player.x = nx }
    if !blocked(player.x, ny) { player.y = ny }
    player.a = frame.aim
  }
}
