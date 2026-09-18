import CryptoKit
import Foundation

public struct WindowEvidence: Codable, Identifiable, Sendable {
  public let id: UUID
  public let app: String
  public let bundleID: String
  public let pid: Int32
  public let launchTime: Double
  public let title: String
  public let document: String
  public let text: String
  public let capturedAt: Date

  public init(
    id: UUID = UUID(), app: String, bundleID: String = "", pid: Int32 = 0,
    launchTime: Double = 0, title: String, document: String = "", text: String,
    capturedAt: Date = Date()
  ) {
    self.id = id
    self.app = app
    self.bundleID = bundleID
    self.pid = pid
    self.launchTime = launchTime
    self.title = title
    self.document = document
    self.text = text
    self.capturedAt = capturedAt
  }

  public var version: String {
    SHA256.hash(data: Data([title, document, text].joined(separator: "\u{0}").utf8))
      .map { String(format: "%02x", $0) }.joined()
  }

  public func isFresh(comparedTo other: WindowEvidence, now: Date = Date()) -> Bool {
    pid == other.pid && launchTime == other.launchTime && bundleID == other.bundleID
      && version == other.version && now.timeIntervalSince(capturedAt) < 300
  }
}

public enum WindowCapturePolicy {
  public static func supports(subrole: String, minimized: Bool, document: String) -> Bool {
    subrole == "AXStandardWindow"
      || (subrole == "AXDialog" && minimized && URL(string: document)?.scheme != nil)
  }
}

public struct Frame: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public func approximatelyEquals(_ other: Frame) -> Bool {
    abs(x - other.x) <= 2 && abs(y - other.y) <= 2
      && abs(width - other.width) <= 2 && abs(height - other.height) <= 2
  }
}

public enum DeckLayout {
  public static func frames(count: Int, in bounds: Frame) -> [Frame] {
    guard count > 0, count <= 4, bounds.width >= 500, bounds.height >= 350 else {
      return []
    }
    let gap = 14.0
    if count == 1 { return [bounds] }
    if count == 2 {
      let width = (bounds.width - gap) / 2
      return (0..<2).map {
        Frame(
          x: bounds.x + Double($0) * (width + gap), y: bounds.y,
          width: width, height: bounds.height)
      }
    }
    if count == 3 {
      let left = (bounds.width - gap) * 0.55
      let right = bounds.width - left - gap
      let height = (bounds.height - gap) / 2
      return [
        Frame(x: bounds.x, y: bounds.y, width: left, height: bounds.height),
        Frame(x: bounds.x + left + gap, y: bounds.y, width: right, height: height),
        Frame(
          x: bounds.x + left + gap, y: bounds.y + height + gap,
          width: right, height: height),
      ]
    }
    let width = (bounds.width - gap) / 2
    let height = (bounds.height - gap) / 2
    return (0..<4).map {
      Frame(
        x: bounds.x + Double($0 % 2) * (width + gap),
        y: bounds.y + Double($0 / 2) * (height + gap), width: width, height: height)
    }
  }
}

public struct Judgment: Codable, Sendable {
  public let relevance: Double
  public let confidence: Double
  public let contradiction: Double
  public let model: String
  public let milliseconds: Double
  public let requests: Int
  public var selected: Bool { relevance >= 2.1 && contradiction <= 0.25 }
  public var rank: Double { relevance / 3 * (1 - contradiction) }
  public var label: String {
    if contradiction >= 0.65 { return "Conflicting evidence" }
    if selected { return "Fits this task" }
    if relevance >= 1.4 || (0.25...0.65).contains(contradiction) { return "Needs review" }
    return "Different task"
  }
}

public enum DeckError: LocalizedError {
  case message(String)
  public var errorDescription: String? {
    switch self {
    case .message(let text): return text
    }
  }
}
