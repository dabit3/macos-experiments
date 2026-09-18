import CryptoKit
import Foundation

public enum LensError: Error, LocalizedError {
  case message(String)
  public var errorDescription: String? {
    switch self {
    case .message(let message): return message
    }
  }
}

public struct MenuCandidate: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let path: [String]
  public let enabled: Bool
  public let checked: Bool
  public let shortcut: String
  public let permitted: Bool

  public init(
    id: String, path: [String], enabled: Bool = true, checked: Bool = false,
    shortcut: String = "", permitted: Bool = true
  ) {
    self.id = id
    self.path = path
    self.enabled = enabled
    self.checked = checked
    self.shortcut = shortcut
    self.permitted = permitted
  }

  public var breadcrumb: String { path.joined(separator: " › ") }
  public var title: String { path.last ?? "" }
}

public struct MenuContext: Codable, Equatable, Sendable {
  public let app: String
  public let bundleID: String
  public let window: String
  public let selection: String
  public let focusedRole: String

  public init(app: String, bundleID: String, window: String, selection: String, focusedRole: String)
  {
    self.app = app
    self.bundleID = bundleID
    self.window = window
    self.selection = selection
    self.focusedRole = focusedRole
  }
}

public struct RankedCommand: Codable, Identifiable, Sendable {
  public let candidate: MenuCandidate
  public let score: Double
  public let confidence: Double
  public var id: String { candidate.id }
}

public struct Ranking: Codable, Sendable {
  public let commands: [RankedCommand]
  public let model: String
  public let requests: Int
  public let milliseconds: Int
  public let indexed: Int
  public let cached: Bool
  public let routeID: String?
  public let routeConfidence: Double

  public var matches: [RankedCommand] {
    commands.filter { $0.score >= 2.25 }
  }
  public var actionable: [RankedCommand] {
    matches.filter { $0.candidate.enabled && $0.candidate.permitted && $0.confidence >= 0.5 }
  }
  public var ambiguous: Bool {
    actionable.count > 1 && actionable[0].score - actionable[1].score < 0.25
  }
}

public enum GuardPolicy {
  public static func permits(bundleID: String, path: [String]) -> Bool {
    guard path.count >= 2 else { return false }
    let root = path[0]
    let leaf = path.last ?? ""
    switch bundleID {
    case "com.apple.TextEdit":
      if path.count == 3 && root == "Edit" && path[1] == "Transformations" {
        return ["Make Upper Case", "Make Lower Case", "Capitalize"].contains(leaf)
      }
      if path.count == 3 && root == "Format" && path[1] == "Font" {
        return ["Bold", "Italic", "Underline", "Outline"].contains(leaf)
      }
      if path.count == 3 && root == "Format" && path[1] == "Text" {
        return ["Align Left", "Center", "Justify", "Align Right"].contains(leaf)
      }
      return root == "View"
        && [
          "Show Ruler", "Hide Ruler", "Wrap to Page", "Wrap to Window", "Actual Size",
          "Zoom In", "Zoom Out",
        ].contains(leaf)
    case "com.apple.finder":
      if root == "View" && path.count == 3
        && ["Sort By", "Clean Up By", "Group By"].contains(path[1])
      {
        return [
          "None", "Name", "Kind", "Date Last Opened", "Date Added", "Date Modified",
          "Date Created", "Size", "Tags",
        ].contains(leaf)
      }
      return root == "View" && path.count == 2
        && [
          "as Icons", "as List", "as Columns", "as Gallery", "Show Sidebar", "Hide Sidebar",
          "Show Path Bar", "Hide Path Bar", "Show Status Bar", "Hide Status Bar",
          "Show Preview", "Hide Preview", "Use Groups",
        ].contains(leaf)
    case "com.apple.Safari":
      return root == "View" && path.count == 2
        && [
          "Show Sidebar", "Hide Sidebar", "Show Status Bar", "Hide Status Bar",
          "Show Tab Bar", "Hide Tab Bar", "Zoom In", "Zoom Out", "Actual Size",
        ].contains(leaf)
    default: return false
    }
  }

  public static func validate(
    original: MenuCandidate, current: MenuCandidate, originalState: String, currentState: String,
    age: TimeInterval
  ) throws {
    guard age <= 120 else { throw LensError.message("Preview expired. Capture this app again.") }
    guard originalState == currentState else {
      throw LensError.message(
        "The window, selection or document changed. Capture again before acting.")
    }
    guard original == current else {
      throw LensError.message("The menu changed since this preview. Capture again.")
    }
    guard current.enabled else {
      throw LensError.message("This command is disabled in the target app.")
    }
    guard current.permitted else {
      throw LensError.message(
        "Preview only: this command is outside the reversible demo allowlist.")
    }
  }
}

public func digest(_ value: String) -> String {
  SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}
