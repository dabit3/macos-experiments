import AppKit
import ApplicationServices
import Darwin
import StageCore

@MainActor
enum IdentitySmoke {
  static func run(model: StageModel) async {
    guard AXReader.trusted else {
      print("IDENTITY_SMOKE_BLOCKED: grant Accessibility to ShareStage.")
      exit(1)
    }
    model.selectDemoWindows()
    guard model.selectedRows.count == 4,
      let target = model.selectedRows.first?.target,
      AXReader.windows(pid: target.pid, appName: "TextEdit").count == 4
    else {
      print("IDENTITY_SMOKE_BLOCKED: exactly four disposable TextEdit fixtures are required.")
      exit(1)
    }
    model.analyze()
    while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
    var checks: [String: Bool] = [
      "liveJudgmentsBeforeTimeout": model.selectedRows.allSatisfy { $0.judgment != nil }
    ]
    model.cover(target.id)
    let panel = model.overlays.panels[target.id]
    let rectangle = panel?.frame
    let fingerprint = AXReader.capture(target).fingerprint
    let pid = target.pid
    Thread.detachNewThread {
      usleep(5_000_000)
      kill(pid, SIGCONT)
    }
    let stopped = kill(pid, SIGSTOP) == 0
    let status = AXReader.identityStatus(target)
    checks["timeoutIsUnavailableNotMissing"] = stopped && status == .unavailable(.cannotComplete)
    checks["unavailableRejectsFreshAction"] = !AXReader.isCurrent(target)
    model.poll()
    checks["timeoutInvalidatesEveryJudgment"] = model.selectedRows.allSatisfy {
      $0.judgment == nil && $0.verdict(audience: model.audience) == .review
    }
    checks["existingPanelRetainedAtObservedRectangle"] =
      panel?.isVisible == true && panel?.frame == rectangle
      && model.overlays.panels[target.id] === panel
    checks["errorCodeAndRecoveryVisible"] = model.selectedRows.allSatisfy {
      $0.note.contains("AX -25204") && $0.note.contains("retry Analyze")
    }
    model.stageSuggested()
    checks["noNewPanelFromUnavailableVerdict"] = model.overlays.panels.count == 1
    kill(pid, SIGCONT)
    try? await Task.sleep(nanoseconds: 100_000_000)
    checks["sameRetainedTargetRecovers"] = AXReader.identityStatus(target) == .current
    checks["sameEvidenceAfterResume"] = AXReader.capture(target).fingerprint == fingerprint
    let nonWindow = WindowTarget(
      pid: pid, element: AXUIElementCreateApplication(pid),
      appName: "TextEdit", title: "Diagnostic non-window")
    checks["confirmedNonMemberStillMissing"] = AXReader.identityStatus(nonWindow) == .missing
    model.poll()
    checks["recoveryDoesNotResurrectVerdicts"] = model.selectedRows.allSatisfy {
      $0.judgment == nil
    }
    model.analyze()
    while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
    checks["explicitReanalysisRecovers"] = model.selectedRows.allSatisfy {
      guard let evidence = $0.evidence, let judgment = $0.judgment else { return false }
      return judgment.isFresh(evidence, audience: model.audience)
    }
    model.restore()
    checks["restoreStillRemovesPanel"] =
      model.overlays.panels.isEmpty && panel?.isVisible == false
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(checks) {
      print("IDENTITY_SMOKE " + String(decoding: data, as: UTF8.self))
    }
    let passed = checks.values.allSatisfy { $0 }
    print("IDENTITY_SMOKE \(passed ? "PASS" : "FAIL")")
    fflush(stdout)
    exit(passed ? 0 : 1)
  }
}
