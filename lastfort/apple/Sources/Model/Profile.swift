import Combine
import CryptoKit
import Foundation
import OSLog
import Security

struct Cosmetic: Codable, Identifiable {
  let id: String
  let slot: CosmeticSlot
  let name: String
  let rarity: Rarity
  let primary, secondary, accent: UInt32
  let description: String
  let shape: Int
}
struct PassTier: Codable, Identifiable {
  let tier, xpRequired: Int
  let rewardId: String
  var id: Int { tier }
}
struct Catalogue: Codable {
  let cosmetics: [Cosmetic]
  let tiers: [PassTier]
  static func load(bundle: Bundle = .main) throws -> Catalogue {
    guard let url = bundle.url(forResource: "catalogue", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode(Catalogue.self, from: Data(contentsOf: url))
  }
  func cosmetic(_ id: String) -> Cosmetic? { cosmetics.first { $0.id == id } }
}
struct Career: Codable {
  enum CodingKeys: String, CodingKey {
    case matches, wins, kills, damage, harvested, built
    case bestPlacement = "best"
  }
  var matches = 0, wins = 0, kills = 0, damage = 0, harvested = 0, built = 0, bestPlacement = 0
}
struct ProfileData: Codable {
  var name = ProfileData.defaultName
  static var defaultName: String {
    #if os(macOS)
      "Warden"
    #else
      "Ranger"
    #endif
  }
  var server = "ws://localhost:8787/ws"
  var loadout = Loadout()
  var xp = 0
  var unlocked: Set<String> = ["outfit_recruit", "pickaxe_splinter", "glider_kite", "banner_fort"]
  var claimed: Set<Int> = []
  var recordedMatches: Set<String> = []
  var matchEpoch = UUID().uuidString
  var career = Career()
  var theme = "system"
  var reducedMotion = false
  var sound = true
  var haptics = true
  var seenIntro = false

  mutating func record(
    _ summary: MatchSummary, playerID: Int, server: String, room: String, token: String
  ) {
    let identity = "\(matchEpoch)|\(server)|\(room)|\(token)|\(summary.seed)|\(summary.endTick)"
    let key = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    guard !recordedMatches.contains(key),
      let row = summary.players.first(where: { $0.id == playerID })
    else { return }
    recordedMatches.insert(key)
    xp += row.xp
    career.matches += 1
    if summary.winnerTeam == row.team { career.wins += 1 }
    career.kills += row.kills
    career.damage += row.damage
    career.harvested += row.harvested
    career.built += row.built
    if row.placement > 0 && (career.bestPlacement == 0 || row.placement < career.bestPlacement) {
      career.bestPlacement = row.placement
    }
  }
  mutating func claim(_ tier: PassTier) {
    guard xp >= tier.xpRequired else { return }
    claimed.insert(tier.tier)
    unlocked.insert(tier.rewardId)
  }
}
@MainActor final class Profile: ObservableObject {
  @Published var data: ProfileData { didSet { save() } }
  @Published var persistenceError: String?
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let saved = defaults.data(forKey: "lastfort.native.profile"),
      let profile = try? JSONDecoder().decode(ProfileData.self, from: saved)
    {
      data = profile
    } else {
      data = Self.legacyProfile(defaults)
    }
    if let token = defaults.string(forKey: "flutter.token") {
      do {
        try ResumeToken.save(token, server: data.server)
        defaults.removeObject(forKey: "flutter.token")
      } catch {
        Logger(subsystem: "com.lastfort", category: "profile")
          .error("Resume token not migrated: \(error.localizedDescription, privacy: .public)")
      }
    }
    save()
  }
  private static func legacyProfile(_ defaults: UserDefaults) -> ProfileData {
    var data = ProfileData()
    data.name = defaults.string(forKey: "flutter.name") ?? data.name
    data.server = defaults.string(forKey: "flutter.server") ?? data.server
    data.xp = defaults.integer(forKey: "flutter.xp")
    data.theme = defaults.string(forKey: "flutter.theme") ?? data.theme
    data.reducedMotion = defaults.bool(forKey: "flutter.reducedMotion")
    data.seenIntro = defaults.bool(forKey: "flutter.seenIntro")
    data.sound = defaults.object(forKey: "flutter.sound") as? Bool ?? true
    data.haptics = defaults.object(forKey: "flutter.haptics") as? Bool ?? true
    data.unlocked.formUnion(defaults.stringArray(forKey: "flutter.unlocked") ?? [])
    data.claimed = Set((defaults.stringArray(forKey: "flutter.claimed") ?? []).compactMap(Int.init))
    if let json = defaults.string(forKey: "flutter.loadout"),
      let loadout = try? JSONDecoder().decode(Loadout.self, from: Data(json.utf8))
    {
      data.loadout = loadout
    }
    if let json = defaults.string(forKey: "flutter.career"),
      let career = try? JSONDecoder().decode(Career.self, from: Data(json.utf8))
    {
      data.career = career
    }
    return data
  }
  func save() {
    do { defaults.set(try JSONEncoder().encode(data), forKey: "lastfort.native.profile") } catch {
      persistenceError = "Cannot save profile: \(error.localizedDescription)"
    }
  }
}
enum ResumeToken {
  static func read(server: String) -> String? {
    let query: [CFString: CFTypeRef] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "com.lastfort.native.resume" as CFString,
      kSecAttrAccount: server as CFString, kSecReturnData: kCFBooleanTrue,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let bytes = result as? Data
    else { return nil }
    return String(data: bytes, encoding: .utf8)
  }
  static func save(_ token: String, server: String) throws {
    let query: [CFString: CFTypeRef] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "com.lastfort.native.resume" as CFString,
      kSecAttrAccount: server as CFString,
    ]
    let value = Data(token.utf8) as CFData
    var status = SecItemUpdate(query as CFDictionary, [kSecValueData: value] as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData] = value
      item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
  }
}
struct LaunchOptions {
  let environment: [String: String]
  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments
  ) {
    var values = environment
    for argument in arguments where argument.hasPrefix("--") {
      let pair = argument.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
      if pair.count == 2 { values["LASTFORT_" + pair[0].uppercased()] = pair[1] }
    }
    self.environment = values
  }
  subscript(_ key: String) -> String? { environment["LASTFORT_" + key] }
  var auto: Bool { self["AUTO"] == "1" || self["AUTO"] == "true" }
  var fast: Bool { self["FAST"] == "1" || self["FAST"] == "true" }
  var autoStart: Int { Int(self["AUTOSTART"] ?? "") ?? 0 }
}
