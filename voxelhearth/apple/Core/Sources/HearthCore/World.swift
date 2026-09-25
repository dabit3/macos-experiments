import Foundation

public func hash3(_ a: Int, _ b: Int, _ c: Int) -> UInt32 {
  var h = UInt32(truncatingIfNeeded: a) &* 374_761_393
  h = h &+ UInt32(truncatingIfNeeded: b) &* 668_265_263
  h = h &+ UInt32(truncatingIfNeeded: c) &* 2_147_483_647
  h = (h ^ (h >> 13)) &* 1_274_126_177
  return h ^ (h >> 16)
}

public struct ValueNoise {
  let seed: Int
  public init(_ seed: Int) { self.seed = seed }
  func lattice(_ x: Int, _ y: Int, _ z: Int) -> Double {
    Double(hash3(x + seed, y - seed * 3, z + seed * 7) & 0xffff) / 65535
  }
  public func noise(_ x: Double, _ y: Double, _ z: Double = 0) -> Double {
    let ix = Int(floor(x))
    let iy = Int(floor(y))
    let iz = Int(floor(z))
    func fade(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    let fx = fade(x - Double(ix))
    let fy = fade(y - Double(iy))
    let fz = fade(z - Double(iz))
    let a = lerp(lattice(ix, iy, iz), lattice(ix + 1, iy, iz), fx)
    let b = lerp(lattice(ix, iy + 1, iz), lattice(ix + 1, iy + 1, iz), fx)
    let c = lerp(lattice(ix, iy, iz + 1), lattice(ix + 1, iy, iz + 1), fx)
    let d = lerp(lattice(ix, iy + 1, iz + 1), lattice(ix + 1, iy + 1, iz + 1), fx)
    return lerp(lerp(a, b, fy), lerp(c, d, fy), fz)
  }
  public func fbm(_ x: Double, _ y: Double, _ octaves: Int, persistence: Double = 0.5) -> Double {
    var amp = 1.0
    var frequency = 1.0
    var sum = 0.0
    var norm = 0.0
    for _ in 0..<octaves {
      sum += noise(x * frequency, y * frequency) * amp
      norm += amp
      amp *= persistence
      frequency *= 2
    }
    return sum / norm
  }
}

public struct ChunkKey: Hashable, Sendable {
  public let x: Int
  public let z: Int
  public init(_ x: Int, _ z: Int) {
    self.x = x
    self.z = z
  }
}

public final class Chunk {
  public var blocks = [UInt8](repeating: 0, count: 16 * 16 * 64)
  public var edits: [Int: UInt8] = [:]
  public init() {}
  public func get(_ x: Int, _ y: Int, _ z: Int) -> Int {
    guard (0..<64).contains(y) else { return 0 }
    return Int(blocks[(y * 16 + z) * 16 + x])
  }
  func set(_ x: Int, _ y: Int, _ z: Int, _ id: Int) {
    guard (0..<64).contains(y) else { return }
    blocks[(y * 16 + z) * 16 + x] = UInt8(id)
  }
}

public final class WorldGenerator {
  enum Biome { case plains, forest, desert, tundra, mountains }
  let height: ValueNoise, detail: ValueNoise, temp: ValueNoise, moist: ValueNoise
  let cave: ValueNoise, cave2: ValueNoise, ore: ValueNoise
  var columns: [ChunkKey: (Int, Biome)] = [:]
  public init(seed: Int) {
    height = ValueNoise(seed)
    detail = ValueNoise(seed + 101)
    temp = ValueNoise(seed + 202)
    moist = ValueNoise(seed + 303)
    cave = ValueNoise(seed + 404)
    cave2 = ValueNoise(seed + 505)
    ore = ValueNoise(seed + 606)
  }
  func rawHeight(_ x: Int, _ z: Int) -> Double {
    let base = height.fbm(Double(x) / 140, Double(z) / 140, 4, persistence: 0.55)
    let d = detail.fbm(Double(x) / 32, Double(z) / 32, 3)
    let mountain = max(0, min(1, (base - 0.55) * 4))
    return 22 + base * 20 + d * 5 + mountain * mountain * 22
  }
  func column(_ x: Int, _ z: Int) -> (Int, Biome) {
    let key = ChunkKey(x, z)
    if let cached = columns[key] { return cached }
    let h = rawHeight(x, z)
    let t = temp.fbm(Double(x) / 180, Double(z) / 180, 2)
    let m = moist.fbm(Double(x) / 150 + 40, Double(z) / 150 - 40, 2)
    let biome: Biome =
      h > 44
      ? .mountains
      : t < 0.36 ? .tundra : t > 0.66 && m < 0.45 ? .desert : m > 0.55 ? .forest : .plains
    let result = (max(4, min(60, Int(floor(h)))), biome)
    columns[key] = result
    return result
  }
  func hasTree(_ x: Int, _ z: Int, _ biome: Biome) -> Bool {
    let h = hash3(x, 7, z) & 0xffff
    let density: Double
    switch biome {
    case .forest: density = 0.045
    case .plains: density = 0.0045
    case .tundra: density = 0.018
    case .mountains: density = 0.004
    case .desert: density = 0
    }
    guard Double(h) < density * 65536 else { return false }
    for dx in -2...2 {
      for dz in -2...2 where dx != 0 || dz != 0 {
        let nh = hash3(x + dx, 7, z + dz) & 0xffff
        if Double(nh) < density * 65536 && nh < h { return false }
      }
    }
    let sh = column(x, z).0
    return sh > 27 && sh < 54
  }
  public func generate(_ cx: Int, _ cz: Int) -> Chunk {
    let chunk = Chunk()
    let bx = cx * 16
    let bz = cz * 16
    for lz in 0..<16 {
      for lx in 0..<16 {
        let x = bx + lx
        let z = bz + lz
        let (sh, biome) = column(x, z)
        for y in 0...sh {
          var id: Int
          if y == 0 || (y == 1 && hash3(x, y, z) & 1 == 0) {
            id = 14
          } else if y == sh {
            switch biome {
            case .desert: id = 4
            case .tundra: id = 22
            case .mountains: id = sh > 50 ? 22 : 1
            default: id = sh <= 27 ? 4 : 3
            }
          } else if y > sh - 4 {
            switch biome {
            case .desert: id = y > sh - 3 ? 4 : 1
            case .mountains: id = 1
            default: id = 2
            }
            if id == 2 && y == sh - 1 && sh <= 27 { id = 4 }
          } else {
            let n = ore.noise(Double(x) / 5, Double(y) / 5, Double(z) / 5)
            let h = hash3(x, y, z) & 0xffff
            if y < 10 && n > 0.78 && h < 9000 {
              id = 13
            } else if y < 16 && n > 0.76 && h < 14000 {
              id = 12
            } else if y < 30 && n > 0.74 {
              id = 11
            } else if y < 45 && n < 0.24 {
              id = 10
            } else if n > 0.86 && h < 6000 {
              id = 21
            } else {
              id = 1
            }
          }
          if id != 14 && y > 2 && y < sh - 1 {
            let a = cave.noise(Double(x) / 22, Double(y) / 14, Double(z) / 22)
            let b = cave2.noise(Double(x) / 22 + 100, Double(y) / 14, Double(z) / 22 - 100)
            if abs(a - 0.5) < 0.055 && abs(b - 0.5) < 0.055 { id = 0 }
          }
          chunk.set(lx, y, lz, id)
        }
        if sh < 26 {
          for y in (sh + 1)...26 { chunk.set(lx, y, lz, 5) }
          if biome != .desert { chunk.set(lx, sh, lz, hash3(x, 3, z) % 5 == 0 ? 33 : 4) }
        } else {
          let top = chunk.get(lx, sh, lz)
          let h = Int(hash3(x, 11, z) & 0xffff)
          if top == 3 {
            if h < 5500 {
              chunk.set(lx, sh + 1, lz, 24)
            } else if h < 6200 {
              chunk.set(lx, sh + 1, lz, 23)
            }
          } else if top == 4 && biome == .desert && h < 500 {
            for i in 1...(1 + h % 3) { chunk.set(lx, sh + i, lz, 28) }
          }
        }
      }
    }
    for lz in -3..<19 {
      for lx in -3..<19 {
        let x = bx + lx
        let z = bz + lz
        let (sh, biome) = column(bx + lx, bz + lz)
        guard biome != .desert && hasTree(x, z, biome) else { continue }
        let frost = biome == .tundra
        let trunk = 4 + Int(hash3(x, 9, z) % 3)
        func put(_ wx: Int, _ wy: Int, _ wz: Int, _ id: Int, onlyAir: Bool = true) {
          let px = wx - bx
          let pz = wz - bz
          guard (0..<16).contains(px), (0..<16).contains(pz), (0..<64).contains(wy) else { return }
          if !onlyAir || chunk.get(px, wy, pz) == 0 { chunk.set(px, wy, pz, id) }
        }
        for i in 1...trunk { put(x, sh + i, z, frost ? 31 : 6, onlyAir: false) }
        if frost {
          for layer in 0..<trunk {
            let y = sh + trunk + 1 - layer
            let r = layer / 2 + 1
            for dx in -r...r {
              for dz in -r...r where abs(dx) + abs(dz) <= r + layer % 2 {
                put(x + dx, y, z + dz, 32)
              }
            }
          }
          put(x, sh + trunk + 2, z, 32)
        } else {
          for dy in -2...1 {
            let y = sh + trunk + dy
            let r = dy >= 0 ? 1 : 2
            for dx in -r...r {
              for dz in -r...r {
                if abs(dx) == r && abs(dz) == r && dy != -1 { continue }
                if dy == 1 && abs(dx) + abs(dz) > 1 { continue }
                put(x + dx, y, z + dz, 7)
              }
            }
          }
        }
      }
    }
    if columns.count > 100_000 { columns.removeAll(keepingCapacity: true) }
    return chunk
  }
}

public final class World {
  public let seed: Int
  public let generator: WorldGenerator
  public private(set) var chunks: [ChunkKey: Chunk] = [:]
  public var revision = 0
  public init(seed: Int) {
    self.seed = seed
    generator = WorldGenerator(seed: seed)
  }
  public static func coordinate(_ value: Int) -> Int { Int(floor(Double(value) / 16)) }
  public func loaded(_ x: Int, _ z: Int) -> Bool {
    chunks[ChunkKey(Self.coordinate(x), Self.coordinate(z))] != nil
  }
  public func apply(_ cx: Int, _ cz: Int, edits: [Int]) {
    let key = ChunkKey(cx, cz)
    let chunk = generator.generate(cx, cz)
    for i in stride(from: 0, to: edits.count - edits.count % 2, by: 2) {
      guard chunk.blocks.indices.contains(edits[i]), (0...255).contains(edits[i + 1]) else {
        continue
      }
      chunk.blocks[edits[i]] = UInt8(edits[i + 1])
      chunk.edits[edits[i]] = UInt8(edits[i + 1])
    }
    chunks[key] = chunk
    revision += 1
  }
  public func peek(_ x: Int, _ y: Int, _ z: Int) -> Int {
    guard (0..<64).contains(y) else { return 0 }
    let cx = Self.coordinate(x)
    let cz = Self.coordinate(z)
    return chunks[ChunkKey(cx, cz)]?.get(x - cx * 16, y, z - cz * 16) ?? 14
  }
  public func set(_ x: Int, _ y: Int, _ z: Int, _ id: Int) {
    guard (0..<64).contains(y), (0...255).contains(id) else { return }
    let cx = Self.coordinate(x)
    let cz = Self.coordinate(z)
    let key = ChunkKey(Self.coordinate(x), Self.coordinate(z))
    let chunk = chunks[key] ?? generator.generate(cx, cz)
    let index = (y * 16 + z - cz * 16) * 16 + x - cx * 16
    chunk.blocks[index] = UInt8(id)
    chunk.edits[index] = UInt8(id)
    chunks[key] = chunk
    revision += 1
  }
}
