import Foundation
import Security

struct LaunchConfiguration {
  var server: String
  var name: String
  var room: String?
  var level: String?
  var automatic: Bool
  static var platform: String {
    #if os(macOS)
      return "macos"
    #else
      return "ios"
    #endif
  }
  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard
  ) {
    var args: [String: String] = [:]
    for (index, argument) in arguments.enumerated() {
      let key = argument.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
      let pair = key.split(separator: "=", maxSplits: 1).map(String.init)
      if pair.count == 2, pair[0].hasPrefix("PP_") { args[pair[0]] = pair[1] }
      if key.hasPrefix("PP_"), pair.count == 1, index + 1 < arguments.count {
        args[key] = arguments[index + 1]
      }
    }
    func value(_ key: String) -> String? {
      args[key] ?? environment[key] ?? environment["SIMCTL_CHILD_\(key)"]
    }
    server = value("PP_SERVER") ?? defaults.string(forKey: "server") ?? "ws://localhost:8787/ws"
    name =
      value("PP_NAME") ?? defaults.string(forKey: "chefName")
      ?? (Self.platform == "ios" ? "Pip" : "Mac")
    room = value("PP_ROOM")
    level = value("PP_LEVEL")
    automatic = value("PP_AUTO") == "1"
  }
  static func serverURL(_ string: String) -> URL? {
    guard
      let components = URLComponents(
        string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
      ["ws", "wss"].contains(components.scheme?.lowercased() ?? ""),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil, components.fragment == nil,
      let url = components.url
    else { return nil }
    return url
  }
}

protocol ResumeStore {
  func read(server: String) -> String?
  func write(_ token: String?, server: String) throws
}

struct KeychainResumeStore: ResumeStore {
  private let service = "dev.panicpantry.panicPantry.resume"
  func read(server: String) -> String? {
    let query =
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service,
        kSecAttrAccount: server, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne,
      ] as CFDictionary
    var result: CFTypeRef?
    guard SecItemCopyMatching(query, &result) == errSecSuccess, let data = result as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }
  func write(_ token: String?, server: String) throws {
    let query =
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: server,
      ] as CFDictionary
    guard let token else {
      SecItemDelete(query)
      return
    }
    let attributes = [kSecValueData: Data(token.utf8)] as CFDictionary
    let update = SecItemUpdate(query, attributes)
    if update == errSecSuccess { return }
    guard update == errSecItemNotFound else { throw KeychainError(status: update) }
    let insert =
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: server,
        kSecValueData: Data(token.utf8),
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ] as CFDictionary
    let status = SecItemAdd(insert, nil)
    if status != errSecSuccess { throw KeychainError(status: status) }
  }
  struct KeychainError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
      "Could not save the resume token in Keychain (\(status)). Keep this app open to retain your seat."
    }
  }
}

enum LevelCatalogue {
  static func load() throws -> [Level] {
    #if SWIFT_PACKAGE
      let bundle = Bundle.module
    #else
      let bundle = Bundle.main
    #endif
    guard let url = bundle.url(forResource: "levels", withExtension: "json") else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try JSONDecoder().decode([Level].self, from: Data(contentsOf: url))
  }
}
