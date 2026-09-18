import AppKit
import ApplicationServices
import PasteCore

struct EvalCase: Decodable {
  let name: String
  let source: String
  let field: String
  let intent: String?
  let expected: String?
}

struct EvalRow: Encodable {
  let name: String
  let expected: String?
  let actual: String?
  let choiceCorrect: Bool
  let actionCorrect: Bool
  let allowedPaste: Bool
  let confidence: Double
  let role: Double?
  let milliseconds: Int
  let requests: Int
  let model: String
}

struct EvalReport: Encodable {
  let date: String
  let cases: Int
  let choiceCorrect: Int
  let actionCorrect: Int
  let falsePositiveActions: Int
  let medianMS: Double
  let p95MS: Int
  let requests: Int
  let results: [EvalRow]
}

enum Commands {
  static func evaluate(path: String) async throws {
    let cases = try JSONDecoder().decode(
      [EvalCase].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    let client = JevClient()
    var rows: [EvalRow] = []
    for item in cases {
      let source = try SourceDocument(item.source)
      let result = try await client.evaluate(
        source: source,
        target: FieldContext(app: "Held-out form", title: item.field, intent: item.intent ?? ""),
        useCache: false)
      let actual = source.candidates.first { $0.id == result.choice }?.text
      rows.append(
        EvalRow(
          name: item.name, expected: item.expected, actual: actual,
          choiceCorrect: actual == item.expected,
          actionCorrect: item.expected == nil
            ? !result.approved : result.approved && actual == item.expected,
          allowedPaste: result.approved, confidence: result.confidence,
          role: result.roles[result.choice], milliseconds: result.milliseconds,
          requests: result.requests, model: result.model))
    }
    let times = rows.map(\.milliseconds).sorted()
    let report = EvalReport(
      date: ISO8601DateFormatter().string(from: Date()), cases: rows.count,
      choiceCorrect: rows.filter(\.choiceCorrect).count,
      actionCorrect: rows.filter(\.actionCorrect).count,
      falsePositiveActions: rows.filter { $0.allowedPaste && $0.actual != $0.expected }.count,
      medianMS: times.isEmpty
        ? 0 : Double(times[(times.count - 1) / 2] + times[times.count / 2]) / 2,
      p95MS: times.isEmpty ? 0 : times[Int(ceil(Double(times.count) * 0.95)) - 1],
      requests: rows.map(\.requests).reduce(0, +), results: rows)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
  }

  @MainActor
  static func launchForm() async throws -> NSRunningApplication {
    let config = NSWorkspace.OpenConfiguration()
    let app = try await NSWorkspace.shared.openApplication(at: AppPaths.form, configuration: config)
    for _ in 0..<30 {
      if AX.element(
        AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute) != nil
      {
        return app
      }
      try await Task.sleep(for: .milliseconds(100))
    }
    throw PilotError.message("Fixture did not expose a focused field.")
  }

  @MainActor
  static func nativeSmoke() async throws {
    guard AXIsProcessTrusted() else {
      throw PilotError.message(
        "Accessibility permission is required for the signed PastePilot.app. Grant it in System Settings and rerun --native-smoke."
      )
    }
    let source = try SourceDocument(String(contentsOf: AppPaths.fixture))
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(source.text, forType: .string)
    guard NSPasteboard.general.string(forType: .string) == source.text else {
      throw PilotError.message("Clipboard roundtrip failed.")
    }
    let app = try await launchForm()
    app.activate(options: [])
    try await Task.sleep(for: .milliseconds(200))
    let root = AXUIElementCreateApplication(app.processIdentifier)
    guard
      let billing = AX.find(
        root, matching: { AX.string($0, kAXIdentifierAttribute) == "pastepilot-1" }),
      let sales = AX.find(
        root, matching: { AX.string($0, kAXIdentifierAttribute) == "pastepilot-2" })
    else { throw PilotError.message("Fixture fields not found.") }
    try AX.set(billing, kAXFocusedAttribute, kCFBooleanTrue)
    let target = try TargetSnapshot.capture(intent: "", app: app)
    let result = try await JevClient().evaluate(
      source: source, target: target.context, useCache: false)
    guard result.approved,
      let candidate = source.candidates.first(where: { $0.id == result.choice }),
      candidate.text == "invoices@northstar.example"
    else { throw PilotError.message("Live Jev did not approve the fixture billing email.") }
    let edit = try await FieldAction.paste(source.exactText(candidate), into: target)
    print(
      "PASS fixture: live \(result.model), \(result.milliseconds) ms, exact billing email readback")
    try await FieldAction.undo(edit)
    print("PASS fixture: undo restored original value")
    try AX.set(billing, kAXFocusedAttribute, kCFBooleanTrue)
    let stale = try TargetSnapshot.capture(intent: "", app: app)
    try AX.set(sales, kAXFocusedAttribute, kCFBooleanTrue)
    var blocked = false
    do { try stale.validate() } catch { blocked = true }
    guard blocked, AX.string(sales, kAXValueAttribute).isEmpty else {
      throw PilotError.message("Changed-focus guard failed.")
    }
    print("PASS fixture: changed focus rejected; sales field unchanged")

    let document = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/PastePilot-Smoke-\(UUID().uuidString).txt")
    try "Billing email: [replace me]\n".write(to: document, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: document) }
    let configuration = NSWorkspace.OpenConfiguration()
    guard
      let textEditURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "com.apple.TextEdit")
    else {
      throw PilotError.message("TextEdit is not installed.")
    }
    let textEdit = try await NSWorkspace.shared.open(
      [document], withApplicationAt: textEditURL, configuration: configuration)
    try await Task.sleep(for: .milliseconds(700))
    let textRoot = AXUIElementCreateApplication(textEdit.processIdentifier)
    guard let window = AX.element(textRoot, kAXFocusedWindowAttribute),
      let editor = AX.find(
        window, matching: { AX.string($0, kAXRoleAttribute) == kAXTextAreaRole }),
      AX.string(editor, kAXValueAttribute) == "Billing email: [replace me]\n"
    else {
      throw PilotError.message(
        "Disposable TextEdit document was not the focused editor. No edit attempted.")
    }
    try AX.set(editor, kAXFocusedAttribute, kCFBooleanTrue)
    var range = CFRange(location: 15, length: 12)
    guard let selectedRange = AXValueCreate(.cfRange, &range) else {
      throw PilotError.message("Could not construct selection.")
    }
    try AX.set(editor, kAXSelectedTextRangeAttribute, selectedRange)
    let external = try TargetSnapshot.capture(intent: "Billing email", app: textEdit)
    let externalResult = try await JevClient().evaluate(
      source: source,
      target: FieldContext(
        app: external.context.app, role: external.context.role, title: external.context.title,
        help: external.context.help, labels: external.context.labels, intent: "Billing email"),
      useCache: false)
    guard externalResult.approved,
      let selected = source.candidates.first(where: { $0.id == externalResult.choice }),
      selected.text == "invoices@northstar.example"
    else { throw PilotError.message("Jev did not approve the TextEdit selection.") }
    let externalEdit = try await FieldAction.paste(source.exactText(selected), into: external)
    guard AX.string(editor, kAXValueAttribute) == "Billing email: invoices@northstar.example\n"
    else {
      throw PilotError.message("TextEdit exact insertion readback failed.")
    }
    print(
      "PASS TextEdit: live \(externalResult.model), \(externalResult.milliseconds) ms, selected-text insertion readback"
    )
    try await FieldAction.undo(externalEdit)
    print("PASS TextEdit: original text restored")
  }
}
