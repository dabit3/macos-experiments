import Foundation
import Security

enum SessionStore {
  static var legacyToken: String? {
    UserDefaults.standard.string(forKey: "flutter.session.token")
  }
  static func removeLegacyToken() {
    UserDefaults.standard.removeObject(forKey: "flutter.session.token")
  }
  private static func query(server: String) -> [String: NSObject] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "dev.brickfolk.native.resume" as NSString,
      kSecAttrAccount as String: server as NSString,
    ]
  }
  static func read(server: String) throws -> String? {
    var query = query(server: server)
    query[kSecReturnData as String] = NSNumber(value: true)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw StoreError(status: status)
    }
    return String(data: data, encoding: .utf8)
  }
  static func write(_ token: String?, server: String) throws {
    let query = query(server: server)
    guard let token else {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw StoreError(status: status)
      }
      return
    }
    let value: [String: NSObject] = [kSecValueData as String: Data(token.utf8) as NSData]
    var status = SecItemUpdate(query as CFDictionary, value as CFDictionary)
    if status == errSecItemNotFound {
      var item = query.merging(value) { _, new in new }
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw StoreError(status: status) }
  }
  struct StoreError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
      "Could not access the saved session in Keychain (\(status))."
    }
  }
}
