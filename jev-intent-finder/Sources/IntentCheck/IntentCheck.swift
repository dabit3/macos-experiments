import AppKit
import Foundation
import IntentCore

@main
struct IntentCheck {
  @MainActor
  static func main() async {
    do {
      let args = Array(CommandLine.arguments.dropFirst())
      guard let command = args.first else {
        throw FinderError(
          "Usage: intent-check fixtures <folder> | eval | benchmark <folder> | native-smoke <folder>"
        )
      }
      switch command {
      case "fixtures":
        guard args.count == 2 else { throw FinderError("Supply an output folder.") }
        try Fixtures.write(to: URL(fileURLWithPath: args[1], isDirectory: true))
        print("Wrote 30 synthetic native documents.")
      case "eval": try await evaluate()
      case "benchmark":
        guard args.count == 2 else { throw FinderError("Supply the demo vault folder.") }
        try await benchmark(URL(fileURLWithPath: args[1]))
      case "native-smoke":
        guard args.count == 2 else { throw FinderError("Supply the disposable demo vault folder.") }
        try await nativeSmoke(URL(fileURLWithPath: args[1]))
      default: throw FinderError("Unknown command.")
      }
    } catch {
      print("ERROR: \(error.localizedDescription)")
      exit(1)
    }
  }

  static func evaluate() async throws {
    let cases = try Fixtures.heldOut()
    let client = JevClient()
    let start = Date()
    var passed = 0
    var falsePositives = 0
    var timings: [Double] = []
    var models = Set<String>()
    var requests = 0
    for batchStart in stride(from: 0, to: cases.count, by: 4) {
      try await withThrowingTaskGroup(of: (EvaluationCase, Judgment).self) { group in
        for example in cases[batchStart..<min(batchStart + 4, cases.count)] {
          group.addTask {
            (example, try await client.evaluate(query: example.query, text: example.text))
          }
        }
        for try await (example, answer) in group {
          let correct = answer.accepted == example.accept
          if correct { passed += 1 }
          if answer.accepted && !example.accept { falsePositives += 1 }
          timings.append(answer.milliseconds)
          models.insert(answer.model)
          requests += answer.requests
          print(
            String(
              format:
                "%@ %@ expected=%@ got=%@ relevance=%.3f requirements=%.3f contradiction=%.3f %.0fms",
              correct ? "PASS" : "FAIL", example.id, String(example.accept),
              String(answer.accepted),
              answer.relevance, answer.requirements, answer.contradiction, answer.milliseconds))
        }
      }
    }
    let ordered = timings.sorted()
    print(
      String(
        format:
          "LIVE EVAL %d/%d; false positives=%d; requests=%d; wall=%.2fs; p50=%.0fms; p95=%.0fms; models=%@",
        passed, cases.count, falsePositives, requests, Date().timeIntervalSince(start),
        ordered[ordered.count / 2],
        ordered[min(ordered.count - 1, Int(Double(ordered.count) * 0.95))],
        models.sorted().joined(separator: ",")))
    guard passed == cases.count else {
      throw FinderError("Evaluation misses above are real model outcomes.")
    }
  }

  static func benchmark(_ folder: URL) async throws {
    let scan = try Documents.scan(folder)
    guard scan.documents.count == 30 else {
      throw FinderError("Benchmark requires all 30 vault documents.")
    }
    let queries: [(String, Set<String>)] = [
      (
        "the signed agreement that allows cancellation without cause, not the draft",
        ["scan_0042.pdf"]
      ),
      (
        "customer interviews that mention a workaround, excluding internal planning",
        ["recording_11.txt", "untitled_06.rtf", "asset_82.pdf"]
      ),
      (
        "receipts for equipment, not subscriptions",
        ["IMG_8821.pdf", "doc_19.rtf", "scan_0104.pdf"]
      ),
      ("paid invoice for a lunar rover delivered in 2035", []),
    ]
    let client = JevClient()
    var correct = 0
    for (query, expected) in queries {
      let start = Date()
      let ranked = try await Ranking.search(documents: scan.documents, query: query, client: client)
      { _ in }
      let found = Set(ranked.filter(\.accepted).map { $0.document.name })
      let baseline = scan.documents.sorted {
        let a = Documents.filenameOverlap(query: query, document: $0)
        let b = Documents.filenameOverlap(query: query, document: $1)
        return a == b ? $0.name < $1.name : a > b
      }
      let baselineFirst = baseline.firstIndex { expected.contains($0.name) }.map { $0 + 1 }
      if found == expected { correct += 1 }
      print("\nINTENT: \(query)")
      print("Jev accepted: \(found.sorted()); expected: \(expected.sorted())")
      print(
        "Jev top: \(ranked.first?.document.name ?? "none"); filename-overlap top: \(baseline.first?.name ?? "none")"
      )
      if let baselineFirst {
        print(
          "First correct file: filename rank \(baselineFirst), Jev rank \(ranked.firstIndex { expected.contains($0.document.name) }.map { $0 + 1 } ?? 0). Sequential baseline inspection avoids at most \(baselineFirst - 1) wrong opens before first hit; this is a rank-derived count, not timed human behavior."
        )
      }
      print(
        String(
          format: "wall=%.2fs; HTTP requests=%d; rejected=%d; errors=%d; model=%@",
          Date().timeIntervalSince(start),
          ranked.compactMap(\.judgment).reduce(0) { $0 + $1.requests },
          ranked.filter { !$0.accepted }.count, ranked.filter { $0.error != nil }.count,
          ranked.compactMap { $0.judgment?.model }.first ?? "none"))
    }
    print("\nVAULT exact-set success \(correct)/\(queries.count)")
    guard correct == queries.count else {
      throw FinderError("Vault outcome differs from labels; inspect the report.")
    }
  }

  @MainActor
  static func nativeSmoke(_ folder: URL) async throws {
    let first = try Documents.extract(folder.appendingPathComponent("scan_0042.pdf"))
    let second = try Documents.extract(folder.appendingPathComponent("IMG_8821.pdf"))
    let identity = SearchIdentity(generation: UUID(), query: "disposable fixture native smoke")
    try FinderActions.reveal([first], identity: identity, current: identity)
    try await assertFinderSelection([first.url])
    print("PASS native single-file reveal + Finder selection readback: scan_0042.pdf")
    try FinderActions.reveal([first, second], identity: identity, current: identity)
    try await assertFinderSelection([first.url, second.url])
    print("PASS native multi-file reveal + Finder selection readback: 2 exact URLs")
    let scope = try FinderActions.currentFolder()
    guard scope.standardizedFileURL == folder.standardizedFileURL else {
      throw FinderError("Wrong active Finder scope.")
    }
    print("PASS real Finder current-folder readback")
  }

  @MainActor
  static func assertFinderSelection(_ expected: [URL]) async throws {
    for _ in 0..<12 {
      try await Task.sleep(for: .milliseconds(250))
      let actual = try FinderActions.currentSelection()
      if Set(actual.map(\.standardizedFileURL)) == Set(expected.map(\.standardizedFileURL)) {
        return
      }
    }
    throw FinderError("Finder selection readback did not match the requested URLs.")
  }
}
