import Foundation
import StageCore

enum Evaluation {
  struct Example: Decodable {
    let id: String
    let audience: String
    let text: String
    let expected: Verdict
  }
  struct Result: Encodable {
    let id: String
    let expected: Verdict
    let actual: Verdict?
    let passed: Bool
    let milliseconds: Double?
    let mismatch: Double?
    let policyConflict: Double?
    let relevance: Double?
    let model: String?
    let error: String?
  }
  struct Report: Encodable {
    let timestamp: Date
    let total: Int
    let passed: Int
    let wallMilliseconds: Double
    let results: [Result]
  }
  static func run() async {
    do {
      guard let index = CommandLine.arguments.firstIndex(of: "--live-eval"),
        CommandLine.arguments.count > index + 1
      else {
        throw NSError(domain: "Pass the path to Fixtures/eval.json", code: 1)
      }
      let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
      let examples = try JSONDecoder().decode([Example].self, from: Data(contentsOf: url))
      let start = Date()
      var results: [Result] = []
      for offset in stride(from: 0, to: examples.count, by: 3) {
        let batch = Array(examples[offset..<min(offset + 3, examples.count)])
        await withTaskGroup(of: Result.self) { group in
          for example in batch {
            group.addTask {
              let evidence = Evidence(
                identity: example.id, title: "Held-out window",
                text: example.text, complete: true)
              do {
                let judgment = try await JevClient().evaluate(evidence, audience: example.audience)
                let verdict = judgment.verdict(for: evidence, audience: example.audience)
                let a = judgment.response.answers
                return Result(
                  id: example.id, expected: example.expected, actual: verdict,
                  passed: verdict == example.expected, milliseconds: judgment.milliseconds,
                  mismatch: a.mismatch.noul, policyConflict: a.policyConflict.noul,
                  relevance: a.relevance.score, model: judgment.response.model, error: nil)
              } catch {
                return Result(
                  id: example.id, expected: example.expected, actual: nil,
                  passed: false, milliseconds: nil, mismatch: nil, policyConflict: nil,
                  relevance: nil, model: nil, error: error.localizedDescription)
              }
            }
          }
          for await result in group { results.append(result) }
        }
      }
      let report = Report(
        timestamp: Date(), total: results.count, passed: results.filter(\.passed).count,
        wallMilliseconds: Date().timeIntervalSince(start) * 1000,
        results: results.sorted { $0.id < $1.id })
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      print(String(decoding: try encoder.encode(report), as: UTF8.self))
      if report.passed != report.total { exit(1) }
    } catch {
      fputs("Evaluation failed: \(error.localizedDescription)\n", stderr)
      exit(1)
    }
  }
}
