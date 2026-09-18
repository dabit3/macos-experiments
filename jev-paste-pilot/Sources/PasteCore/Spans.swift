import Foundation

public enum PilotError: LocalizedError {
  case message(String)
  public var errorDescription: String? {
    switch self {
    case .message(let text): return text
    }
  }
}

public struct Candidate: Codable, Identifiable, Equatable {
  public let id: String
  public let text: String
  public let kind: String
  public let excerpt: String
  public let location: Int
  public let length: Int
}

public struct SourceDocument: Equatable {
  public let text: String
  public let candidates: [Candidate]

  public init(_ text: String) throws {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw PilotError.message("Clipboard has no text. Copy a brief first.")
    }
    guard text.utf16.count <= 12_000 else {
      throw PilotError.message("Source exceeds 12,000 characters. Copy a smaller section.")
    }
    self.text = text
    let ns = text as NSString
    var found: [(NSRange, String)] = []
    func add(_ range: NSRange, _ kind: String) {
      guard range.length > 0, range.length <= 700,
        NSMaxRange(range) <= ns.length,
        !found.contains(where: { $0.0 == range })
      else { return }
      found.append((range, kind))
    }
    let lines = try NSRegularExpression(pattern: "[^\\r\\n]+")
      .matches(in: text, range: NSRange(location: 0, length: ns.length))
    for line in lines {
      let raw = ns.substring(with: line.range)
      let trimmed = raw.trimmingCharacters(in: .whitespaces)
      let trimRange = (raw as NSString).range(of: trimmed)
      if trimmed.isEmpty { continue }
      if let colon = trimmed.firstIndex(of: ":") {
        let value = String(trimmed[trimmed.index(after: colon)...])
          .trimmingCharacters(in: .whitespaces)
        if !value.isEmpty {
          let offset = (raw as NSString).range(of: value, options: .backwards)
          add(
            NSRange(location: line.range.location + offset.location, length: offset.length),
            "label value")
        }
      } else if trimmed.count < 180 {
        add(
          NSRange(location: line.range.location + trimRange.location, length: trimRange.length),
          "line")
      }
    }
    let patterns: [(String, String)] = [
      (#"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "email"),
      (#"(?<!\w)(?:\+\d{1,3}[\s.-]?)?(?:\(\d{2,4}\)|\d{3})[\s.-]\d{3}[\s.-]\d{4}(?!\d)"#, "phone"),
      (
        #"(?:[$€£]\s?\d(?:[\d,.]*\d)?|(?:USD|EUR|GBP)\s+\d(?:[\d,.]*\d)?|\d(?:[\d,.]*\d)?\s+(?:USD|EUR|GBP))"#,
        "amount"
      ),
      (
        #"(?im)^[^\r\n:]{0,60}(?:address|ship to|bill to)[^\r\n:]*:\s*\r?\n((?:[^\r\n]+\r?\n?){1,4})"#,
        "address block"
      ),
    ]
    for (pattern, kind) in patterns {
      let regex = try NSRegularExpression(pattern: pattern)
      for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        var range = kind == "address block" ? match.range(at: 1) : match.range
        if kind == "address block" {
          let raw = ns.substring(with: range)
          let value = raw.components(separatedBy: "\n\n")[0].trimmingCharacters(
            in: .whitespacesAndNewlines)
          range.length = (value as NSString).length
        }
        add(range, kind)
      }
    }
    found.sort {
      $0.0.location == $1.0.location ? $0.0.length < $1.0.length : $0.0.location < $1.0.location
    }
    guard found.count <= 64 else {
      throw PilotError.message(
        "Found more than 64 spans. Copy a smaller section; nothing was silently omitted.")
    }
    candidates = found.enumerated().map { index, item in
      let before = max(0, item.0.location - 180)
      let after = min(ns.length, NSMaxRange(item.0) + 120)
      return Candidate(
        id: "span_\(index + 1)", text: ns.substring(with: item.0), kind: item.1,
        excerpt: ns.substring(with: NSRange(location: before, length: after - before)),
        location: item.0.location, length: item.0.length)
    }
  }

  public func exactText(_ candidate: Candidate) throws -> String {
    guard candidates.contains(candidate) else {
      throw PilotError.message("Source changed. Capture again.")
    }
    let result = (text as NSString).substring(
      with: NSRange(location: candidate.location, length: candidate.length))
    guard result == candidate.text else {
      throw PilotError.message("Source span failed verification.")
    }
    return result
  }
}

public struct FieldContext: Codable, Equatable {
  public let app: String
  public let role: String
  public let title: String
  public let help: String
  public let labels: [String]
  public let intent: String

  public init(
    app: String, role: String = "AXTextField", title: String, help: String = "",
    labels: [String] = [], intent: String = ""
  ) {
    self.app = app
    self.role = role
    self.title = title
    self.help = help
    self.labels = labels
    self.intent = intent
  }
}

public struct FieldVersion: Equatable {
  public let identity: String
  public let role: String
  public let label: String
  public let value: String
  public let selection: NSRange?

  public init(identity: String, role: String, label: String, value: String, selection: NSRange?) {
    self.identity = identity
    self.role = role
    self.label = label
    self.value = value
    self.selection = selection
  }

  public func validate(
    against current: FieldVersion, sameElement: Bool, sameWindow: Bool,
    focused: Bool, secure: Bool
  ) throws {
    guard !secure else { throw PilotError.message("Secure fields are never supported.") }
    guard sameElement, sameWindow, focused, self == current else {
      throw PilotError.message(
        "Target changed since preview. Focus the intended field and inspect again.")
    }
  }
}
