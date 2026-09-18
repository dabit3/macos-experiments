import AppKit
import StageCore
import SwiftUI

struct WindowRow: Identifiable {
  let target: WindowTarget
  var id: UUID { target.id }
  var selected = false
  var evidence: Evidence?
  var judgment: Judgment?
  var note = "Select to include. Text has not been read."
  var covered = false

  func verdict(audience: String) -> Verdict {
    guard let evidence, let judgment else { return .review }
    return judgment.verdict(for: evidence, audience: audience)
  }
}

@MainActor
final class StageModel: ObservableObject {
  static let externalAudience =
    "External Atlas customer demo. Show the public product roadmap and public onboarding materials. Pricing negotiation, internal retrospective and unreleased launch dates are not for this audience."
  static let internalAudience =
    "Internal Atlas account team planning. This team is authorized to see the public roadmap, pricing negotiation and internal retrospective. Discuss the Atlas account plan and product demo. Unreleased launch dates may be discussed internally."

  @Published var audience = StageModel.externalAudience {
    didSet { if oldValue != audience { invalidateAudience() } }
  }
  @Published var apps: [AppChoice] = []
  @Published var rows: [WindowRow] = []
  @Published var focused: UUID?
  @Published var busy = false
  @Published var activity = "Choose an app, then select the windows you want to stage."
  @Published var trusted = AXReader.trusted
  @Published var requests = 0
  @Published var elapsed: Double = 0
  @Published var modelID = "Jev · not run yet"
  @Published var appPID: pid_t = 0
  let overlays = OverlayManager()
  private var generation = UUID()
  private var work: Task<Void, Never>?
  private var timer: Timer?
  private var ticks = 0
  private var cache: [String: Judgment] = [:]

  init() {
    refreshApps()
    timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.poll() }
    }
  }

  var selectedRows: [WindowRow] { rows.filter(\.selected) }
  var coverCount: Int { rows.filter(\.covered).count }
  var suggestedCount: Int {
    selectedRows.filter { $0.verdict(audience: audience) == .cover && !$0.covered }.count
  }
  var keepCount: Int { selectedRows.filter { $0.verdict(audience: audience) == .keep }.count }
  var reviewCount: Int { selectedRows.filter { $0.verdict(audience: audience) == .review }.count }

  func refreshApps() {
    apps = AXReader.apps()
    trusted = AXReader.trusted
  }

  func loadWindows() {
    guard !busy, let app = apps.first(where: { $0.id == appPID }) else { return }
    trusted = AXReader.trusted
    guard trusted else {
      activity = "Accessibility permission is required to list selected-app windows."
      return
    }
    let found = AXReader.windows(pid: app.id, appName: app.name)
    for target in found {
      if !rows.contains(where: {
        $0.target.pid == target.pid && CFEqual($0.target.element, target.element)
      }) {
        rows.append(WindowRow(target: target))
      }
    }
    activity =
      found.isEmpty
      ? "No readable windows in \(app.name)."
      : "Added \(found.count) windows from \(app.name). Choose what Jev may read."
  }

  func select(_ id: UUID, value: Bool) {
    guard let index = rows.firstIndex(where: { $0.id == id }), !busy else { return }
    rows[index].selected = value
    if !value {
      overlays.remove(id)
      rows[index].covered = false
      rows[index].evidence = nil
      rows[index].judgment = nil
      rows[index].note = "Out of scope. Text has been discarded."
    }
  }

  private func invalidateAudience() {
    generation = UUID()
    work?.cancel()
    busy = false
    for index in rows.indices where rows[index].selected {
      rows[index].judgment = nil
      rows[index].note = "Audience changed. Analyze again; existing covers stay in place."
    }
    activity = "New audience, new decisions. Prior verdicts are invalid."
  }

  func analyze() {
    guard !busy, !selectedRows.isEmpty,
      !audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    work?.cancel()
    let token = UUID()
    generation = token
    let context = audience
    busy = true
    requests = 0
    elapsed = 0
    let start = Date()
    var inputs: [(UUID, Evidence)] = []
    for index in rows.indices where rows[index].selected {
      let evidence = AXReader.capture(rows[index].target)
      rows[index].evidence = evidence
      rows[index].judgment = nil
      rows[index].note =
        evidence.complete
        ? "Waiting for Jev…" : "Review: empty, unreadable, or truncated AX evidence."
      if evidence.complete { inputs.append((rows[index].id, evidence)) }
    }
    activity = "Evaluating \(inputs.count) windows · at most 3 requests in flight"
    work = Task {
      for offset in stride(from: 0, to: inputs.count, by: 3) {
        guard generation == token, !Task.isCancelled else { return }
        let batch = Array(inputs[offset..<min(offset + 3, inputs.count)])
        let cached = cache
        await withTaskGroup(of: EvaluationResult.self) { group in
          for (id, evidence) in batch {
            let key = context + evidence.fingerprint
            group.addTask {
              do {
                if let hit = cached[key] {
                  return EvaluationResult(id: id, judgment: hit, error: nil, cached: true)
                }
                let result = try await JevClient().evaluate(evidence, audience: context)
                return EvaluationResult(id: id, judgment: result, error: nil, cached: false)
              } catch {
                return EvaluationResult(
                  id: id, judgment: nil, error: error.localizedDescription, cached: false)
              }
            }
          }
          for await result in group {
            guard generation == token, !Task.isCancelled,
              let index = rows.firstIndex(where: { $0.id == result.id })
            else { continue }
            if let judgment = result.judgment {
              let fresh = AXReader.capture(rows[index].target)
              rows[index].evidence = fresh
              requests += result.cached ? 0 : judgment.requests
              modelID = judgment.response.model
              if judgment.isFresh(fresh, audience: audience) {
                rows[index].judgment = judgment
                rows[index].note =
                  result.cached
                  ? "Exact-state cache · \(Int(judgment.milliseconds)) ms original request"
                  : "Live Jev · \(Int(judgment.milliseconds)) ms · AX text"
                cache[context + fresh.fingerprint] = judgment
                if cache.count > 100 { cache.removeAll() }
              } else {
                rows[index].note = "Window changed during evaluation. Review required."
              }
            } else {
              rows[index].note = result.error ?? "No result."
            }
            elapsed = Date().timeIntervalSince(start) * 1000
          }
        }
      }
      guard generation == token else { return }
      busy = false
      elapsed = Date().timeIntervalSince(start) * 1000
      activity =
        "Preflight complete · \(keepCount) keep · \(suggestedCount) cover · \(reviewCount) review"
    }
  }

  func stageSuggested() {
    for row in selectedRows where row.verdict(audience: audience) == .cover && !row.covered {
      cover(row.id, requireVerdict: true)
    }
    activity = "\(coverCount) native covers placed. Restore all is always available."
  }

  func cover(_ id: UUID, requireVerdict: Bool = false) {
    guard let index = rows.firstIndex(where: { $0.id == id }), rows[index].selected else { return }
    let target = rows[index].target
    let evidence = AXReader.capture(target)
    if requireVerdict {
      guard let j = rows[index].judgment, j.isFresh(evidence, audience: audience),
        j.verdict(for: evidence, audience: audience) == .cover
      else {
        rows[index].judgment = nil
        rows[index].note = StageError.stale.localizedDescription
        return
      }
    }
    guard AXReader.isCurrent(target), let frame = AXReader.frame(target) else {
      rows[index].judgment = nil
      rows[index].note = "Target unavailable. No panel placed."
      return
    }
    rows[index].evidence = evidence
    overlays.cover(target, frame: frame) { [weak self] in self?.reveal(id) }
    rows[index].covered = true
  }

  func reveal(_ id: UUID) {
    overlays.remove(id)
    if let index = rows.firstIndex(where: { $0.id == id }) { rows[index].covered = false }
  }

  func restore() {
    overlays.restore()
    for index in rows.indices { rows[index].covered = false }
    activity = "Desktop restored. No documents or app state were modified."
  }

  func clearScope() {
    work?.cancel()
    generation = UUID()
    busy = false
    restore()
    rows.removeAll()
    cache.removeAll()
    focused = nil
  }

  func poll() {
    trusted = AXReader.trusted
    ticks += 1
    for index in rows.indices where rows[index].selected {
      let row = rows[index]
      if !AXReader.isCurrent(row.target) {
        overlays.remove(row.id)
        rows[index].covered = false
        rows[index].judgment = nil
        rows[index].note = "Window closed or identity lost. Review required."
        continue
      }
      if row.covered {
        if let frame = AXReader.frame(row.target) {
          overlays.move(row.id, frame: frame)
        } else {
          reveal(row.id)
        }
      }
      if ticks % 5 == 0, row.evidence != nil, !busy {
        let fresh = AXReader.capture(row.target)
        if fresh.fingerprint != row.evidence?.fingerprint {
          rows[index].evidence = fresh
          rows[index].judgment = nil
          rows[index].note = "Window text changed or became unreadable. Analyze again."
        }
      }
    }
  }

  func selectDemoWindows() {
    refreshApps()
    guard let app = apps.first(where: { $0.name == "TextEdit" }) else {
      activity = "Open the TextEdit demo fixtures first."
      return
    }
    appPID = app.id
    loadWindows()
    for index in rows.indices where rows[index].target.title.hasPrefix("ShareStage —") {
      rows[index].selected = true
    }
  }
}

private struct EvaluationResult: @unchecked Sendable {
  let id: UUID
  let judgment: Judgment?
  let error: String?
  let cached: Bool
}
