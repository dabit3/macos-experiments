import Foundation
import Security

struct AppConfiguration {
  var initialCommand: ClientCommand? { room.map { .join($0.uppercased(), spectate: false) } }
  var server: String
  var name: String
  var testID: String?
  var room: String?
  var autoConnect: Bool
  var theme: String

  init(
    arguments: [String] = ProcessInfo.processInfo.arguments,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    defaults: UserDefaults = .standard
  ) {
    func option(_ key: String, _ environmentKey: String) -> String? {
      for (index, value) in arguments.enumerated() {
        if value.hasPrefix("--\(environmentKey)=") {
          return String(value.dropFirst(environmentKey.count + 3))
        }
        if value.hasPrefix("--\(key)=") { return String(value.dropFirst(key.count + 3)) }
        if value == "--\(key)" || value == "--\(environmentKey)",
          arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--")
        {
          return arguments[index + 1]
        }
      }
      return environment[environmentKey]
    }
    #if os(macOS)
      let defaultName = "Mac player"
    #else
      let defaultName = "iPhone player"
    #endif
    server =
      option("server", "SWAPMATE_SERVER") ?? defaults.string(forKey: "server")
      ?? "ws://localhost:8787/ws"
    name = option("name", "SWAPMATE_NAME") ?? defaults.string(forKey: "name") ?? defaultName
    testID = option("test-id", "SWAPMATE_TEST_ID")
    room = option("room", "SWAPMATE_ROOM")
    let auto = option("autoconnect", "SWAPMATE_AUTOCONNECT")?.lowercased()
    autoConnect =
      auto == "1" || auto == "true" || (auto == nil && arguments.contains("--autoconnect"))
      || testID != nil || room != nil
    let requestedTheme =
      (option("theme", "SWAPMATE_THEME") ?? defaults.string(forKey: "theme") ?? "dark").lowercased()
    theme = ["dark", "light", "system"].contains(requestedTheme) ? requestedTheme : "dark"
  }
}

protocol ResumeStore {
  func load(server: String) throws -> String?
  func save(_ token: String?, server: String) throws
}

struct KeychainResumeStore: ResumeStore {
  private let service = "dev.swapmate.resume"
  func load(server: String) throws -> String? {
    let query: CFDictionary =
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: server,
        kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne,
      ] as CFDictionary
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainError(status: status) }
    guard let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }
  func save(_ token: String?, server: String) throws {
    let query: CFDictionary =
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: server,
      ] as CFDictionary
    guard let token else {
      let status = SecItemDelete(query)
      if status != errSecSuccess && status != errSecItemNotFound {
        throw KeychainError(status: status)
      }
      return
    }
    let data = Data(token.utf8)
    let update = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
    if update == errSecSuccess { return }
    guard update == errSecItemNotFound else { throw KeychainError(status: update) }
    let status = SecItemAdd(
      [
        kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: server,
        kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ] as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError(status: status) }
  }
}

struct KeychainError: LocalizedError {
  let status: OSStatus
  var errorDescription: String? {
    "Secure session storage failed (\(status)). Resume is available only while this app stays open."
  }
}
