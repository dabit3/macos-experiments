import AppKit
import Foundation
import TaskDeckCore

enum CommandRunner {
  static func start() {
    Task { @MainActor in
      do {
        if CommandLine.arguments.contains("--eval") {
          try await evaluate()
        } else {
          try await smoke()
        }
        exit(0)
      } catch {
        print("FAIL: \(error.localizedDescription)")
        exit(1)
      }
    }
    RunLoop.main.run()
  }

  struct EvalCase: Decodable {
    let id: String
    let goal: String
    let title: String
    let text: String
    let expected: Bool
    let conflict: Bool?
  }
  static func evaluate() async throws {
    let data = try Data(contentsOf: Fixtures.directory.appendingPathComponent("held-out.json"))
    let originalCases = try JSONDecoder().decode([EvalCase].self, from: data)
    let holdout = try Data(contentsOf: Fixtures.directory.appendingPathComponent("holdout-v2.json"))
    let cases = originalCases + (try JSONDecoder().decode([EvalCase].self, from: holdout))
    let client = JevClient()
    var correct = 0
    var conflictCorrect = 0
    var conflictTotal = 0
    var timings: [Double] = []
    let start = Date()
    for item in cases {
      let window = WindowEvidence(app: "Held-out evaluation", title: item.title, text: item.text)
      let judgment = try await client.evaluate(
        EvaluationState(goal: item.goal, window: window, today: "2026-09-18"), cached: false)
      timings.append(judgment.milliseconds)
      let pass = judgment.selected == item.expected
      if pass { correct += 1 }
      var conflictPass = true
      if let conflict = item.conflict {
        conflictTotal += 1
        conflictPass = (judgment.contradiction >= 0.65) == conflict
        if conflictPass { conflictCorrect += 1 }
      }
      print(
        "\(pass && conflictPass ? "PASS" : "FAIL") \(item.id) selected=\(judgment.selected) expected=\(item.expected) score=\(String(format: "%.3f", judgment.relevance)) conflict=\(String(format: "%.3f", judgment.contradiction)) conflict_expected=\(item.conflict.map(String.init) ?? "unlabeled") conflict_pass=\(conflictPass) concentration=\(String(format: "%.3f", judgment.confidence)) ms=\(Int(judgment.milliseconds)) model=\(judgment.model)"
      )
    }
    timings.sort()
    print(
      "Selection: \(correct)/\(cases.count); contradiction: \(conflictCorrect)/\(conflictTotal); requests: \(await client.requestCount); median_ms: \(Int(timings[timings.count / 2])); p95_ms: \(Int(timings[min(timings.count - 1, Int(Double(timings.count) * 0.95))])); total_s: \(String(format: "%.2f", Date().timeIntervalSince(start)))"
    )
    guard correct == cases.count, conflictCorrect == conflictTotal else {
      throw DeckError.message(
        "Live evaluation disagreed with labeled expectations; inspect the reported cases.")
    }
  }

  @MainActor
  static func smoke() async throws {
    let native = NativeWindows()
    guard native.trusted else {
      native.requestPermission()
      throw DeckError.message(
        "Accessibility is unavailable. Approve TaskDeck, then rerun --native-smoke.")
    }
    try await Fixtures.open()
    let windows = try native.capture(bundleIDs: ["com.apple.TextEdit"]).filter {
      guard let url = URL(string: $0.document) else { return false }
      return url.standardizedFileURL.path.hasPrefix(
        Fixtures.directory.appendingPathComponent("Desktop").standardizedFileURL.path + "/")
    }
    guard windows.count >= 6 else {
      throw DeckError.message(
        "Expected 6+ separate fixture windows, got \(windows.count). In TextEdit, choose Window → Move Tab to New Window if tabs were grouped."
      )
    }
    print(
      "Captured \(windows.count) real fixture windows; \(windows.filter { !$0.text.isEmpty }.count) expose body text."
    )
    let client = JevClient()
    let start = Date()
    var matches: [(WindowEvidence, Judgment)] = []
    for window in windows {
      let judgment = try await client.evaluate(
        EvaluationState(goal: "Bring back the Atlas launch review", window: window))
      print(
        "WINDOW \(window.title): selected=\(judgment.selected), score=\(judgment.relevance), conflict=\(judgment.contradiction), model=\(judgment.model)"
      )
      if judgment.selected { matches.append((window, judgment)) }
    }
    let expected: Set<String> = [
      "01 - Working notes.txt", "02 - Tuesday checklist.txt", "03 - Review packet.txt",
    ]
    let actual = Set(matches.map { $0.0.title })
    print(
      "Native selection: \(actual == expected ? "PASS" : "FAIL"); \(matches.count) selected; latency \(String(format: "%.2f", Date().timeIntervalSince(start)))s; \(await client.requestCount) requests."
    )
    guard actual == expected else {
      throw DeckError.message("Live native selection differs from fixture expectations.")
    }
    let ids = matches.map { $0.0.id }
    let before = ids.compactMap { native.readFrame(id: $0) }
    native.minimizeFixture(id: ids[0])
    try await Task.sleep(nanoseconds: 400_000_000)
    guard native.readMinimized(id: ids[0]) == true else {
      throw DeckError.message("Could not prepare minimized fixture.")
    }
    let actions = try await native.arrange(ids: ids)
    for action in actions { print(action) }
    try await Task.sleep(nanoseconds: 500_000_000)
    let changed = zip(ids, before).allSatisfy {
      guard let current = native.readFrame(id: $0.0) else { return false }
      return !current.approximatelyEquals($0.1)
    }
    let report = await native.undo()
    for line in report { print(line) }
    try await Task.sleep(nanoseconds: 500_000_000)
    let restored = zip(ids, before).allSatisfy {
      native.readFrame(id: $0.0)?.approximatelyEquals($0.1) == true
    }
    let minimized = native.readMinimized(id: ids[0]) == true
    print(
      "READBACK moved=\(changed) exact_frames_restored=\(restored) minimized_restored=\(minimized)")
    guard changed, restored, minimized else {
      throw DeckError.message("Native readback did not match the required side effects.")
    }
    let recaptured = try native.capture(bundleIDs: ["com.apple.TextEdit"])
    let documents = Set(windows.map(\.document))
    let fixtureRecapture = recaptured.filter { documents.contains($0.document) }
    guard fixtureRecapture.count == windows.count,
      fixtureRecapture.allSatisfy({ !$0.text.isEmpty })
    else {
      throw DeckError.message(
        "Fresh capture lost a restored/minimized fixture or its body evidence.")
    }
    print("RECAPTURE all_\(windows.count)_fixtures_with_body_text=true")
    print(
      "Baseline accounting: 8 fixture windows to inspect, 3 relevant windows to raise and arrange manually. TaskDeck: 1 search submission + 1 Compose action + optional 1 Undo; app scoping/setup excluded. Manual timing was not measured."
    )
  }
}
