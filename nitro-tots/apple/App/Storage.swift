import AVFoundation
import CoreText
import Foundation
import Observation
import Security

#if os(iOS)
  import UIKit
#endif

struct Preferences: Codable {
  var name = "Racer", character = "pip", kart = "jellybean"
  var server = "ws://localhost:8787/ws", theme = "system", controls = "auto", camera = "chase"
  var autoAccelerate = true, haptics = true, reduceMotion = false
  var musicVolume = 0.5, sfxVolume = 0.8
  var lastRoom = ""
}
struct Pose: Codable {
  var pos: V2
  var heading: Double
}
struct Ghost: Codable {
  let ticks, laps: Int
  let frames: [Pose]
}
struct Credentials: Codable { let playerId, token: String }
enum LegacyPreferences {
  struct OldGhost: Decodable {
    let ticks: Int
    let frames: [[Double]]
  }
  static func load(_ defaults: UserDefaults) -> Preferences {
    var p = Preferences()
    p.name = defaults.string(forKey: "flutter.name") ?? p.name
    p.character = defaults.string(forKey: "flutter.character") ?? p.character
    p.kart = defaults.string(forKey: "flutter.kart") ?? p.kart
    p.server = defaults.string(forKey: "flutter.server") ?? p.server
    p.lastRoom = defaults.string(forKey: "flutter.lastRoom") ?? p.lastRoom
    p.theme =
      ["system", "light", "dark"][min(2, max(0, defaults.integer(forKey: "flutter.theme")))]
    p.controls =
      ["auto", "touch", "keyboard"][min(2, max(0, defaults.integer(forKey: "flutter.controls")))]
    p.camera = defaults.integer(forKey: "flutter.camera") == 1 ? "fixed" : "chase"
    if defaults.object(forKey: "flutter.autoAccel") != nil {
      p.autoAccelerate = defaults.bool(forKey: "flutter.autoAccel")
    }
    if defaults.object(forKey: "flutter.haptics") != nil {
      p.haptics = defaults.bool(forKey: "flutter.haptics")
    }
    p.reduceMotion = defaults.bool(forKey: "flutter.reduceMotion")
    if defaults.object(forKey: "flutter.music") != nil {
      p.musicVolume = defaults.double(forKey: "flutter.music")
    }
    if defaults.object(forKey: "flutter.sfx") != nil {
      p.sfxVolume = defaults.double(forKey: "flutter.sfx")
    }
    return p
  }
  static func ghosts(_ defaults: UserDefaults) -> [String: Ghost] {
    guard let text = defaults.string(forKey: "flutter.ghosts"),
      let old = try? JSONDecoder().decode([String: OldGhost].self, from: Data(text.utf8))
    else { return [:] }
    return old.mapValues { ghost in
      Ghost(
        ticks: ghost.ticks, laps: 3,
        frames: ghost.frames.compactMap {
          $0.count == 3 ? Pose(pos: V2(x: $0[0], y: $0[1]), heading: $0[2]) : nil
        })
    }
  }
  static func moveToken(_ defaults: UserDefaults, server: String) throws {
    guard let id = defaults.string(forKey: "flutter.resumeId"),
      let token = defaults.string(forKey: "flutter.resumeToken"),
      !id.isEmpty, !token.isEmpty
    else { return }
    try TokenStore.save(Credentials(playerId: id, token: token), server)
    defaults.removeObject(forKey: "flutter.resumeId")
    defaults.removeObject(forKey: "flutter.resumeToken")
  }
}
enum TokenStore {
  static func query(_ server: String) -> NSMutableDictionary {
    [
      kSecClass: kSecClassGenericPassword, kSecAttrService: "dev.nitrotots.resume",
      kSecAttrAccount: server,
    ] as NSMutableDictionary
  }
  static func read(_ server: String) -> Credentials? {
    let q = query(server)
    q[kSecReturnData] = true
    q[kSecMatchLimit] = kSecMatchLimitOne
    var result: CFTypeRef?
    guard SecItemCopyMatching(q, &result) == errSecSuccess, let data = result as? Data else {
      return nil
    }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }
  static func save(_ credentials: Credentials, _ server: String) throws {
    let data = try JSONEncoder().encode(credentials)
    let q = query(server)
    let update = [kSecValueData: data] as CFDictionary
    var status = SecItemUpdate(q, update)
    if status == errSecItemNotFound {
      q[kSecValueData] = data
      q[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      status = SecItemAdd(q, nil)
    }
    if status != errSecSuccess { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
  }
  static func clear(_ server: String) { SecItemDelete(query(server)) }
}
struct LaunchConfig {
  let values: [String: String]
  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments args: [String] = ProcessInfo.processInfo.arguments
  ) {
    var values = environment.filter { $0.key.hasPrefix("NT_") }
    for (i, arg) in args.enumerated() where arg.hasPrefix("--NT_") {
      let parts = arg.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        values[parts[0]] = parts[1]
      } else if i + 1 < args.count && !args[i + 1].hasPrefix("--") {
        values[parts[0]] = args[i + 1]
      } else {
        values[parts[0]] = "1"
      }
    }
    self.values = values
  }
  subscript(_ key: String) -> String? { values["NT_" + key] }
  var active: Bool { self["TEST"] == "1" || self["TEST"] == "true" }
}
enum Assets {
  static func url(_ name: String, _ ext: String) -> URL? {
    Bundle.main.url(forResource: name, withExtension: ext)
  }
  static func registerFonts() {
    for name in ["Fredoka", "Nunito"] {
      if let url = url(name, "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
}
@MainActor final class Feedback {
  private var music: AVAudioPlayer?
  private var effects: [AVAudioPlayer] = []
  private var song = ""
  private var lastEffect: [String: Date] = [:]
  func event(_ event: String, preferences: Preferences) {
    let name: String
    switch event {
    case "miniTurbo": name = "turbo"
    case "pad", "rocketStart", "slipstream": name = "boost"
    case "knockout": name = "hit"
    case "wall": name = "bump"
    case "shieldPop": name = "shield"
    case "trickLand": name = "land"
    case "wrongWay": name = "wrongway"
    case "driftStart": name = "drift"
    default: name = event
    }
    let interval = name == "wrongway" ? 1.5 : 0.15
    if Date().timeIntervalSince(lastEffect[name] ?? .distantPast) < interval { return }
    lastEffect[name] = Date()
    sound(name, preferences: preferences)
  }
  func volumes(_ preferences: Preferences) { music?.volume = Float(preferences.musicVolume) }
  func playMusic(_ name: String, preferences: Preferences) {
    if song == name {
      volumes(preferences)
      return
    }
    music?.stop()
    song = name
    guard let url = Assets.url(name, "wav"), let player = try? AVAudioPlayer(contentsOf: url) else {
      return
    }
    music = player
    player.numberOfLoops = -1
    player.volume = Float(preferences.musicVolume)
    player.play()
  }
  func sound(_ name: String, preferences: Preferences) {
    effects.removeAll { !$0.isPlaying }
    if preferences.sfxVolume > 0, let url = Assets.url(name, "wav"),
      let player = try? AVAudioPlayer(contentsOf: url)
    {
      player.volume = Float(preferences.sfxVolume)
      player.play()
      effects.append(player)
    }
    #if os(iOS)
      if preferences.haptics && ["boost", "hit", "pickup", "go", "turbo"].contains(name) {
        UIImpactFeedbackGenerator(style: name == "hit" ? .heavy : .light).impactOccurred()
      }
    #endif
  }
}
