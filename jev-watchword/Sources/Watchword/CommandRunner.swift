import AppKit
import Foundation
import WatchwordCore

struct EvalCase: Decodable {
  let id: String
  let condition: String
  let baseline: String
  let current: String
  let expected: String
}

struct EvalRow: Encodable {
  let id: String
  let expected: String
  let actual: String
  let passed: Bool
  let signals: Signals
  let milliseconds: Double
  let model: String
  let requests: Int
}

struct EvalReport: Encodable {
  let runAt: Date
  let cases: Int
  let passed: Int
  let falseFires: Int
  let exactPhraseCorrect: Int
  let medianMilliseconds: Double
  let p95Milliseconds: Double
  let results: [EvalRow]
}

enum CommandError: LocalizedError {
  case usage
  case failed(String)
  var errorDescription: String? {
    switch self {
    case .usage:
      return
        "Use --eval <cases.json>, --list-windows, --snapshot <app> <title>, or --native-smoke <output-folder> [raise]."
    case .failed(let detail): return detail
    }
  }
}

@MainActor
enum CommandRunner {
  static func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
  }

  static func run() async throws {
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: "--eval"), args.indices.contains(index + 1) {
      try await evaluate(URL(fileURLWithPath: args[index + 1]))
    } else if let index = args.firstIndex(of: "--native-smoke"), args.indices.contains(index + 1) {
      try await smoke(
        folder: URL(fileURLWithPath: args[index + 1]),
        raise: args.contains("raise"))
    } else if args.contains("--list-windows") {
      NativeAccess.requestPermission()
      for target in try NativeAccess.windows() { print("\(target.pid)\t\(target.label)") }
    } else if let index = args.firstIndex(of: "--snapshot"), args.indices.contains(index + 2) {
      let targets = try NativeAccess.windows().filter {
        $0.appName == args[index + 1] && $0.title.contains(args[index + 2])
      }
      guard targets.count == 1, let target = targets.first else {
        throw CommandError.failed("Select exactly one matching accessible window.")
      }
      try printJSON(NativeAccess.snapshot(target, sequence: 0).text)
    } else {
      throw CommandError.usage
    }
  }

  static func evaluate(_ url: URL) async throws {
    let cases = try JSONDecoder().decode([EvalCase].self, from: Data(contentsOf: url))
    guard !cases.isEmpty else { throw CommandError.usage }
    let client = try JevClient()
    var results: [EvalRow] = []
    var exactPhraseCorrect = 0
    for item in cases {
      let result = try await client.evaluate(
        EvaluationState(condition: item.condition, baseline: item.baseline, current: item.current))
      let actual =
        result.signals.failed >= 0.85 ? "failure" : result.signals.confirmed ? "fire" : "wait"
      results.append(
        EvalRow(
          id: item.id, expected: item.expected, actual: actual,
          passed: actual == item.expected, signals: result.signals,
          milliseconds: result.milliseconds, model: result.model, requests: result.requests))
      let exactFires = item.current.contains("Export completed successfully")
      if exactFires == (item.expected == "fire") { exactPhraseCorrect += 1 }
    }
    let times = results.map(\.milliseconds).sorted()
    try printJSON(
      EvalReport(
        runAt: Date(), cases: cases.count, passed: results.filter(\.passed).count,
        falseFires: results.filter { $0.actual == "fire" && $0.expected != "fire" }.count,
        exactPhraseCorrect: exactPhraseCorrect,
        medianMilliseconds: times[times.count / 2],
        p95Milliseconds: times[min(times.count - 1, Int(Double(times.count) * 0.95))],
        results: results))
    guard results.allSatisfy(\.passed) else {
      throw CommandError.failed("Evaluation has mismatches; inspect the JSON report.")
    }
  }

  static func smoke(folder url: URL, raise: Bool) async throws {
    NativeAccess.requestPermission()
    let targets = try NativeAccess.windows().filter {
      $0.appName == "Terminal" && $0.title.contains("Watchword")
    }
    guard targets.count == 1, let target = targets.first else {
      throw CommandError.failed(
        "Open exactly one Watchword fixture in Terminal, then start during its lead-in.")
    }
    let action = ArmedAction(
      kind: raise ? .raise : .reveal, folder: try SelectedFolder(url: url), window: target)
    try action.validate()
    let baseline = try NativeAccess.snapshot(target, sequence: 0)
    var engine = WatchEngine(baseline: baseline, timeout: 85)
    let client = try JevClient()
    var sequence = 0
    var evaluations = 0
    var latencies: [Double] = []
    var actualModel = ""
    var trace: [String] = ["BASELINE: \(baseline.text)"]
    var sideEffectVerified = false
    while !engine.phase.terminal {
      try await Task.sleep(for: .seconds(1))
      sequence += 1
      let current = try NativeAccess.snapshot(target, sequence: sequence)
      if let ticket = engine.observe(current, now: Date()) {
        let result = try await client.evaluate(
          EvaluationState(
            condition:
              "The export has completed successfully, not merely started, failed or been cancelled.",
            baseline: baseline.text, current: current.text))
        actualModel = result.model
        evaluations += result.requests
        latencies.append(result.milliseconds)
        sequence += 1
        let fresh = try NativeAccess.snapshot(target, sequence: sequence)
        let fired = engine.resolve(ticket, signals: result.signals, current: fresh, now: Date())
        trace.append(
          "\(engine.phase.rawValue): \(engine.reason)\nAX: \(current.text)\nP(yes): \(result.signals)"
        )
        if fired {
          do {
            try await action.execute()
            try await Task.sleep(for: .seconds(1))
            sideEffectVerified =
              raise
              ? NativeAccess.isFocused(target)
              : try finderSelection() == url.resolvingSymlinksInPath().path
          } catch {
            trace.append("Native action/readback error: \(error.localizedDescription)")
          }
        }
      }
    }
    struct SmokeReport: Encodable {
      let phase: String
      let action: String
      let sideEffectVerified: Bool
      let elapsedSeconds: Double
      let requests: Int
      let model: String
      let latenciesMilliseconds: [Double]
      let trace: [String]
    }
    try printJSON(
      SmokeReport(
        phase: engine.phase.rawValue, action: action.kind.rawValue,
        sideEffectVerified: sideEffectVerified,
        elapsedSeconds: Date().timeIntervalSince(baseline.capturedAt),
        requests: evaluations, model: actualModel, latenciesMilliseconds: latencies, trace: trace))
    guard engine.phase == .fired, sideEffectVerified else {
      throw CommandError.failed("Native smoke did not verify a follow-up. See trace.")
    }
  }

  static func finderSelection() throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
      "-e",
      "tell application \"Finder\" to get POSIX path of ((item 1 of (get selection)) as alias)",
    ]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NativeError.actionFailed }
    let path = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return URL(fileURLWithPath: path).standardizedFileURL.path
  }
}
