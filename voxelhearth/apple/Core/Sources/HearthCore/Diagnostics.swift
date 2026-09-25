import Foundation

public struct DriveAction: Codable, Sendable {
  public var t: String
  public var code: String?, name: String?, mode: String?, text: String?, screen: String?,
    theme: String?, dir: String?
  public var seed: Int?, bots: Int?, startTime: Int?, durationTicks: Int?, id: Int?, count: Int?,
    slot: Int?, n: Int?
  public var freezeTime: Bool?, spawnMobs: Bool?, ready: Bool?, on: Bool?, open: Bool?, jump: Bool?
  public var x: Double?, y: Double?, z: Double?, yaw: Double?, pitch: Double?, seconds: Double?
  public var nx: Int?, ny: Int?, nz: Int?, grid: [Int]?
  public init(_ t: String) { self.t = t }
}

public struct ClientReport: Encodable, Sendable {
  public var t: String
  public var id: String?
  public var ok = true
  public var error: String?, screen: String?, phase: String?, world: String?, chat: String?,
    region: String?
  public var worldHash: String?, chatHash: String?
  public var x: Double?, y: Double?, z: Double?, yaw: Double?, pitch: Double?
  public var hp: Int?, food: Int?, score: Int?, selected: Int?, players: Int?, block: Int?,
    chunks: Int?
  public var held: ItemStack?, results: [Player]?, lines: [ChatLine]?
  public var ready: Bool?, spawnReady: Bool?, ground: Bool?
  public init(_ t: String = "drive_done") { self.t = t }
}

public struct Fingerprint {
  private var value: UInt32 = 2_166_136_261
  public var hex: String { String(format: "%08x", value) }
  public init() {}
  public mutating func byte(_ value: UInt8) {
    self.value = (self.value ^ UInt32(value)) &* 16_777_619
  }
  public mutating func int(_ value: Int) {
    let unsigned = UInt32(truncatingIfNeeded: value)
    for shift in stride(from: 0, to: 32, by: 8) {
      byte(UInt8(truncatingIfNeeded: unsigned >> shift))
    }
  }
  public mutating func string(_ value: String) {
    for unit in value.utf16 { int(Int(unit)) }
    byte(255)
  }
  public static func chat(_ lines: [ChatLine]) -> String {
    var hash = Fingerprint()
    for line in lines {
      hash.string(line.from)
      hash.string(line.text)
    }
    return hash.hex
  }
}

extension World {
  public var editsHash: String {
    var hash = Fingerprint()
    hash.int(seed)
    for key in chunks.keys.sorted(by: { ($0.x, $0.z) < ($1.x, $1.z) }) {
      guard let chunk = chunks[key], !chunk.edits.isEmpty else { continue }
      hash.int(key.x)
      hash.int(key.z)
      for index in chunk.edits.keys.sorted() {
        hash.int(index)
        hash.byte(chunk.edits[index]!)
      }
    }
    return hash.hex
  }
  public func regionHash(_ region: [Int]) -> String? {
    guard region.count == 6,
      (0..<3).allSatisfy({ region[$0] <= region[$0 + 3] && region[$0 + 3] - region[$0] < 128 })
    else { return nil }
    var hash = Fingerprint()
    for y in region[1]...region[4] {
      for z in region[2]...region[5] {
        for x in region[0]...region[3] { hash.byte(UInt8(peek(x, y, z))) }
      }
    }
    return hash.hex
  }
}
