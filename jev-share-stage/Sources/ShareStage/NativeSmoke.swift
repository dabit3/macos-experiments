import AppKit
import ApplicationServices
import StageCore

@MainActor
enum NativeSmoke {
  static func run(model: StageModel) async {
    var checks: [String: Bool] = [:]
    guard AXReader.trusted else {
      print("NATIVE_SMOKE_BLOCKED: grant Accessibility to ShareStage and rerun.")
      fflush(stdout)
      return
    }
    model.selectDemoWindows()
    checks["fourDisposableTextEditWindows"] = model.selectedRows.count == 4
    model.analyze()
    while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
    checks["allFourReadThroughAccessibility"] =
      model.selectedRows.filter { $0.evidence?.complete == true }.count == 4
    checks["externalTwoKeepTwoCover"] =
      model.keepCount == 2 && model.suggestedCount == 2 && model.reviewCount == 0
    model.stageSuggested()
    try? await Task.sleep(nanoseconds: 200_000_000)
    checks["twoOpaqueVisibleNativePanels"] =
      model.overlays.panels.count == 2
      && model.overlays.panels.values.allSatisfy {
        $0.isOpaque && $0.isVisible && $0.alphaValue == 1
      }
    checks["exactCoverageAtObservedRectangles"] = model.selectedRows.filter(\.covered).allSatisfy {
      row in
      guard let frame = AXReader.frame(row.target), let panel = model.overlays.panels[row.id] else {
        return false
      }
      return panel.frame == frame
    }
    let windows =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [NSDictionary] ?? []
    let serverIDs = Set(
      windows.compactMap { ($0.object(forKey: kCGWindowNumber) as? NSNumber)?.intValue })
    checks["windowServerReadback"] = model.overlays.panels.values.allSatisfy {
      serverIDs.contains($0.windowNumber)
    }

    if let row = model.selectedRows.first(where: { $0.covered }),
      let original = AXReader.frame(row.target)
    {
      var point = CGPoint(
        x: original.minX + 35,
        y: (NSScreen.screens.first?.frame.height ?? 0) - original.maxY + 30)
      var size = CGSize(width: original.width + 20, height: original.height + 20)
      if let position = AXValueCreate(.cgPoint, &point),
        let dimensions = AXValueCreate(.cgSize, &size)
      {
        let moved =
          AXUIElementSetAttributeValue(
            row.target.element, kAXPositionAttribute as CFString, position) == .success
        let resized =
          AXUIElementSetAttributeValue(row.target.element, kAXSizeAttribute as CFString, dimensions)
          == .success
        model.poll()
        checks["moveResizeFollow"] =
          moved && resized && model.overlays.panels[row.id]?.frame == AXReader.frame(row.target)
          && AXReader.frame(row.target) != original
      }
      if let textArea = findTextArea(row.target.element),
        let originalText = AXReader.string(textArea, kAXValueAttribute)
      {
        let edit = AXUIElementSetAttributeValue(
          textArea, kAXValueAttribute as CFString,
          (originalText + "\nChanged after preflight.") as CFString)
        for _ in 0..<5 { model.poll() }
        checks["changedTextBecomesReview"] =
          edit == .success
          && model.rows.first(where: { $0.id == row.id })?.verdict(audience: model.audience)
            == .review
        checks["changedWindowKeepsExistingCover"] = model.overlays.panels[row.id]?.isVisible == true
        AXUIElementSetAttributeValue(
          textArea, kAXValueAttribute as CFString, originalText as CFString)
      }
      model.reveal(row.id)
      checks["perWindowReveal"] = model.overlays.panels[row.id] == nil && model.coverCount == 1
    }
    let heldPanels = Array(model.overlays.panels.values)
    model.restore()
    checks["restoreClosesEveryPanel"] =
      model.overlays.panels.isEmpty && heldPanels.allSatisfy { !$0.isVisible }
    model.audience = StageModel.internalAudience
    checks["audienceChangeInvalidatesAllVerdicts"] = model.selectedRows.allSatisfy {
      $0.judgment == nil
    }
    model.analyze()
    while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
    checks["sameContentInternalAllKeep"] = model.keepCount == 4 && model.suggestedCount == 0
    for row in model.selectedRows {
      if let answer = row.judgment?.response.answers {
        print(
          "INTERNAL \(row.target.title): \(row.verdict(audience: model.audience).rawValue)"
            + " relevance=\(answer.relevance.score) mismatch=\(answer.mismatch.noul)"
            + " policyConflict=\(answer.policyConflict.noul)")
      }
    }
    model.audience = StageModel.externalAudience
    model.analyze()
    while model.busy { try? await Task.sleep(nanoseconds: 100_000_000) }
    model.stageSuggested()
    do {
      let data = try JSONEncoder().encode(checks)
      print("NATIVE_SMOKE " + String(decoding: data, as: UTF8.self))
      print(
        "NATIVE_SMOKE \(checks.values.allSatisfy { $0 } && checks.count >= 12 ? "PASS" : "FAIL")")
      fflush(stdout)
    } catch { print(error.localizedDescription) }
  }

  private static func findTextArea(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }
    if AXReader.string(element, kAXRoleAttribute) == kAXTextAreaRole { return element }
    for child in AXReader.elements(element, kAXChildrenAttribute) ?? [] {
      if let result = findTextArea(child, depth: depth + 1) { return result }
    }
    return nil
  }
}
