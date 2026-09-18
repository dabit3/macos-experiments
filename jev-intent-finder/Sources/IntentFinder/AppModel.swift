import AppKit
import Foundation
import IntentCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  static let signature =
    "the signed agreement that allows cancellation without cause, not the draft"
  @Published var query = signature { didSet { if query != oldValue { invalidate() } } }
  @Published var scope: URL?
  @Published var documents: [Document] = []
  @Published var results: [RankedDocument] = []
  @Published var selection: Set<String> = []
  @Published var notices: [String] = []
  @Published var activity = "Choose a scope, then describe the file you need."
  @Published var busy = false
  @Published var elapsed = 0.0
  @Published var requests = 0
  @Published var completed = 0
  @Published var baseline = false
  @Published var error: String?
  @Published var finderSelection = ""
  private var generation = UUID()
  private var searchedIdentity: SearchIdentity?
  private var task: Task<Void, Never>?
  private let client = JevClient()
  private var requestStart = 0

  var current: SearchIdentity { SearchIdentity(generation: generation, query: query) }
  var actionable: Bool { !busy && searchedIdentity == current && !selection.isEmpty }
  var selected: [Document] { displayed.filter { selection.contains($0.id) }.map(\.document) }
  var focused: RankedDocument? { displayed.first { selection.contains($0.id) } }
  var matches: [RankedDocument] { results.filter(\.accepted) }
  var model: String { results.compactMap { $0.judgment?.model }.first ?? "jev-latest" }
  var displayed: [RankedDocument] {
    if baseline {
      return results.sorted {
        let left = Documents.filenameOverlap(query: query, document: $0.document)
        let right = Documents.filenameOverlap(query: query, document: $1.document)
        return left == right ? $0.document.name < $1.document.name : left > right
      }
    }
    return Ranking.sorted(results)
  }

  func invalidate() {
    task?.cancel()
    generation = UUID()
    searchedIdentity = nil
    busy = false
    results = []
    selection = []
    completed = 0
    requests = 0
    elapsed = 0
    activity = "Intent changed. Search to evaluate the new meaning."
  }

  func load(_ url: URL) {
    invalidate()
    scope = url
    error = nil
    do {
      let scan = try Documents.scan(url)
      documents = scan.documents
      notices = scan.notices
      activity = "\(documents.count) documents ready · no keyword prefilter"
    } catch {
      self.error = error.localizedDescription
      documents = []
    }
  }

  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.prompt = "Use this scope"
    if panel.runModal() == .OK, let url = panel.url { load(url) }
  }

  func demo() {
    let path = ProcessInfo.processInfo.environment["INTENTFINDER_DEMO_DIR"]
    let url =
      path.map { URL(fileURLWithPath: $0) }
      ?? Bundle.main.resourceURL?.appendingPathComponent("Demo Vault")
    if let url { load(url) }
  }

  func finderScope() {
    do {
      let folder = try FinderActions.currentFolder()
      let selection = try FinderActions.currentSelection()
      load(folder)
      finderSelection =
        selection.isEmpty
        ? "Finder selection is empty"
        : "Finder selected: " + selection.map(\.lastPathComponent).joined(separator: ", ")
    } catch { self.error = error.localizedDescription }
  }

  func search() {
    guard let scope, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    load(scope)
    guard !documents.isEmpty else { return }
    let identity = current
    let docs = documents
    let intent = query
    searchedIdentity = identity
    busy = true
    baseline = false
    activity = "Reading meaning · up to 4 requests in flight"
    let start = Date()
    task = Task {
      do {
        let startingRequests = await client.requestCount
        guard self.current == identity else { return }
        requestStart = startingRequests
        let ranked = try await Ranking.search(documents: docs, query: intent, client: client) {
          result in
          await self.receive(result, identity: identity, start: start)
        }
        let finalRequests = await client.requestCount
        guard self.current == identity else { return }
        results = ranked
        requests = finalRequests - startingRequests
        selection = Set(ranked.first.map { [$0.id] } ?? [])
        busy = false
        elapsed = Date().timeIntervalSince(start)
        let failed = results.filter { $0.error != nil }.count
        activity =
          failed > 0
          ? "\(failed) unavailable · inspect errors before relying on results"
          : matches.isEmpty
            ? "No strong match · review evidence or change the intent"
            : "\(matches.count) strong \(matches.count == 1 ? "match" : "matches") · ready for Finder"
      } catch {
        guard self.current == identity else { return }
        busy = false
        self.error = error.localizedDescription
      }
    }
  }

  func receive(_ result: RankedDocument, identity: SearchIdentity, start: Date) async {
    let count = await client.requestCount
    guard current == identity else { return }
    results.append(result)
    completed += 1
    requests = count - requestStart
    elapsed = Date().timeIntervalSince(start)
    activity = "Evaluated \(completed) of \(documents.count) · \(result.document.name)"
  }

  func cancel() {
    invalidate()
    activity = "Cancelled. No stale result can act."
  }

  func act(_ action: String, all: Bool = false) {
    guard let identity = searchedIdentity, !busy else { return }
    do {
      let docs = all ? matches.map(\.document) : selected
      switch action {
      case "reveal": try FinderActions.reveal(docs, identity: identity, current: current)
      case "open":
        if let doc = docs.first {
          try FinderActions.open(doc, identity: identity, current: current)
        }
      default:
        if let doc = docs.first {
          try FinderActions.quickLook(doc, identity: identity, current: current)
        }
      }
      activity =
        action == "reveal"
        ? "Sent \(docs.count) stable file URL(s) to real Finder" : "Opened selected document"
    } catch { self.error = error.localizedDescription }
  }
}
