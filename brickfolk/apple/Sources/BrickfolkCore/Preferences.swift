import Foundation

public enum NativePreferences {
  public static func migrateLegacy(in defaults: UserDefaults) {
    for key in ["theme", "session.name"] {
      if defaults.string(forKey: key) == nil,
        let value = defaults.string(forKey: "flutter.\(key)")
      {
        defaults.set(value, forKey: key)
      }
    }
    for key in ["sound", "haptics"] {
      if defaults.object(forKey: key) == nil,
        let value = defaults.object(forKey: "flutter.\(key)") as? Bool
      {
        defaults.set(value, forKey: key)
      }
    }
  }
}
