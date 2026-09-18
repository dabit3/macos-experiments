import AppKit
import ApplicationServices
import Foundation
import MenuLensCore

struct EvaluationFile: Decodable {
  let pools: [String: [MenuCandidate]]
  let cases: [EvaluationCase]
}

struct EvaluationCase: Decodable {
  let name: String
  let goal: String
  let pool: String
  let expected: String?
  let disabled: [String]?
  let checked: [String]?
}

struct EvaluationResult: Encodable {
  let name: String
  let goal: String
  let expected: String?
  let actual: String?
  let passed: Bool
  let ranking: Ranking
}

struct EvaluationReport: Encodable {
  let mode = "LIVE JEV / synthetic held-out menu contexts / no OS actions"
  let timestamp = Date()
  let passed: Int
  let total: Int
  let results: [EvaluationResult]
}

struct MenuDump: Encodable {
  let context: MenuContext
  let candidates: [MenuCandidate]
  let truncated: Bool
}

struct NativeReport: Encodable {
  let app: String
  let intent: String
  let command: String
  let result: String
  let readback: String
  let verified: Bool
  let ranking: Ranking
}

@MainActor
enum CommandLineRunner {
  static func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
  }

  static func run(_ arguments: [String]) async -> Int32 {
    do {
      switch arguments.first {
      case "--permission":
        NativeMenus.requestPermission()
        print("Accessibility trusted: \(NativeMenus.trusted)")
      case "--inspect":
        guard arguments.count == 2,
          let app = NSRunningApplication.runningApplications(withBundleIdentifier: arguments[1])
            .first
        else {
          throw LensError.message(
            "Usage: --inspect com.apple.TextEdit (app and document must already be open)")
        }
        app.activate()
        try await Task.sleep(nanoseconds: 300_000_000)
        let snapshot = try NativeMenus.capture(app)
        try printJSON(
          MenuDump(
            context: snapshot.context, candidates: snapshot.candidates,
            truncated: snapshot.truncated))
      case "--eval":
        guard arguments.count == 2 else {
          throw LensError.message("Usage: --eval Fixtures/evaluations.json")
        }
        return try await evaluate(URL(fileURLWithPath: arguments[1]))
      case "--native-smoke":
        guard arguments.count == 2 else {
          throw LensError.message("Usage: --native-smoke textedit|finder")
        }
        try await smoke(arguments[1])
      default:
        throw LensError.message(
          "Options: --permission, --inspect BUNDLE_ID, --eval JSON_PATH, --native-smoke textedit|finder, --showcase"
        )
      }
      return 0
    } catch {
      fputs("MenuLens: \(error.localizedDescription)\n", stderr)
      return 1
    }
  }

  static func evaluate(_ url: URL) async throws -> Int32 {
    let input = try JSONDecoder().decode(EvaluationFile.self, from: Data(contentsOf: url))
    var results: [EvaluationResult] = []
    let client = JevClient()
    for example in input.cases {
      guard let pool = input.pools[example.pool] else {
        throw LensError.message("Missing evaluation pool.")
      }
      let candidates = pool.map { candidate in
        MenuCandidate(
          id: candidate.id, path: candidate.path,
          enabled: !(example.disabled ?? []).contains(candidate.id),
          checked: (example.checked ?? []).contains(candidate.id),
          shortcut: candidate.shortcut, permitted: candidate.permitted
        )
      }
      let context = MenuContext(
        app: example.pool,
        bundleID: example.pool == "TextEdit" ? "com.apple.TextEdit" : "com.apple.finder",
        window: example.pool == "TextEdit" ? "Dispatch.rtf" : "Launch Assets",
        selection: example.pool == "TextEdit" ? "meet me at the northern lighthouse" : "",
        focusedRole: example.pool == "TextEdit" ? "AXTextArea" : "AXOutline"
      )
      let ranking = try await client.rank(
        goal: example.goal, context: context, candidates: candidates)
      let passed = ranking.routeID == example.expected
      results.append(
        EvaluationResult(
          name: example.name, goal: example.goal, expected: example.expected,
          actual: ranking.routeID, passed: passed, ranking: ranking
        ))
      fputs(
        "\(passed ? "PASS" : "FAIL") \(example.name): \(ranking.routeID ?? "none") / \(ranking.milliseconds) ms\n",
        stderr)
    }
    let passed = results.filter(\.passed).count
    try printJSON(EvaluationReport(passed: passed, total: results.count, results: results))
    return passed == results.count ? 0 : 1
  }

  static func smokeDirectory() throws -> URL {
    let root = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/MenuLens/Smoke", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  static func waitForApp(_ bundleID: String) async throws -> NSRunningApplication {
    for _ in 0..<40 {
      if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
        app.activate()
        try await Task.sleep(nanoseconds: 500_000_000)
        return app
      }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw LensError.message("The fixture app did not open.")
  }

  static func prepareTextEdit() async throws -> MenuSnapshot {
    guard NativeMenus.trusted else {
      throw LensError.message(
        "Accessibility permission is required. Run --permission and enable MenuLens.")
    }
    let directory = try smokeDirectory()
    guard let source = Bundle.main.url(forResource: "Dispatch", withExtension: "rtf") else {
      throw LensError.message("Run through run.sh so the fixture is bundled.")
    }
    let document = directory.appendingPathComponent("Dispatch.rtf")
    try FileManager.default.copyItem(at: source, to: document)
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    let app = try await NSWorkspace.shared.open(
      [document], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
      configuration: configuration
    )
    try await Task.sleep(nanoseconds: 600_000_000)
    let application = AXUIElementCreateApplication(app.processIdentifier)
    guard let focus = AX.element(application, kAXFocusedUIElementAttribute) else {
      throw LensError.message("TextEdit has no focused text field.")
    }
    let text = AX.string(focus, kAXValueAttribute) as NSString
    let location = text.range(of: "meet me at the northern lighthouse")
    guard location.location != NSNotFound else {
      throw LensError.message("TextEdit fixture text not found in focused AX element.")
    }
    var range = CFRange(location: location.location, length: location.length)
    guard let value = AXValueCreate(.cfRange, &range),
      AXUIElementSetAttributeValue(focus, kAXSelectedTextRangeAttribute as CFString, value)
        == .success
    else { throw LensError.message("Could not select the disposable fixture phrase through AX.") }
    return try NativeMenus.capture(app)
  }

  static func prepareFinder() async throws -> MenuSnapshot {
    guard NativeMenus.trusted else {
      throw LensError.message("Accessibility permission is required.")
    }
    let directory = try smokeDirectory().appendingPathComponent("Launch Assets", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for (index, name) in [
      "01 Brief.txt", "02 Sketch.txt", "03 Launch notes.txt", "04 Review.txt",
      "05 Final handoff.txt",
    ].enumerated() {
      let url = directory.appendingPathComponent(name)
      try Data("Synthetic MenuLens asset \(index). No personal information.\n".utf8).write(to: url)
      try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -Double((5 - index) * 86400))],
        ofItemAtPath: url.path
      )
    }
    NSWorkspace.shared.open(directory)
    let app = try await waitForApp("com.apple.finder")
    try await Task.sleep(nanoseconds: 500_000_000)
    return try NativeMenus.capture(app)
  }

  static func smoke(_ kind: String) async throws {
    let snapshot: MenuSnapshot
    let goal: String
    switch kind {
    case "textedit":
      snapshot = try await prepareTextEdit()
      goal = "make these words all caps"
    case "finder":
      snapshot = try await prepareFinder()
      goal = "sort these files by when they were last changed, not when they were opened"
    default: throw LensError.message("Use textedit or finder.")
    }
    let ranking = try await JevClient().rank(
      goal: goal, context: snapshot.context, candidates: snapshot.candidates)
    guard let route = ranking.routeID,
      let chosen = ranking.commands.first(where: { $0.id == route })
    else {
      throw LensError.message("Jev returned no clear command for the native smoke.")
    }
    guard
      (kind == "textedit"
        && chosen.candidate.path == ["Edit", "Transformations", "Make Upper Case"])
        || (kind == "finder" && chosen.candidate.path == ["View", "Sort By", "Date Modified"])
    else {
      throw LensError.message(
        "Live decision did not select the expected fixture action: \(chosen.candidate.breadcrumb)")
    }
    let outcome = try await NativeMenus.execute(chosen.candidate, snapshot: snapshot)
    let application = AXUIElementCreateApplication(snapshot.pid)
    let readback: String
    let verified: Bool
    if kind == "textedit" {
      guard let focus = AX.element(application, kAXFocusedUIElementAttribute) else {
        throw LensError.message("Readback focus missing.")
      }
      readback = AX.string(focus, kAXSelectedTextAttribute)
      verified = readback == "MEET ME AT THE NORTHERN LIGHTHOUSE"
    } else {
      guard let app = NSRunningApplication(processIdentifier: snapshot.pid) else {
        throw LensError.message("Finder exited.")
      }
      let after = try NativeMenus.capture(app)
      let command = after.candidates.first { $0.path == chosen.candidate.path }
      verified = command?.checked == true
      readback = "\(chosen.candidate.breadcrumb) checked=\(command?.checked == true)"
    }
    try printJSON(
      NativeReport(
        app: snapshot.context.app, intent: goal, command: chosen.candidate.breadcrumb,
        result: outcome,
        readback: readback, verified: verified, ranking: ranking
      ))
    if !verified {
      throw LensError.message(
        "AXPress completed but native readback did not verify the intended effect.")
    }
  }
}
