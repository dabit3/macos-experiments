import AppKit
import Foundation
import SwiftUI
import UserNotifications
import WatchwordCore

struct Observation: Identifiable {
  let id = UUID()
  let at: Date
  let text: String
  let signals: Signals?
  let duration: Double?
  let reason: String
}

@MainActor
final class WatchModel: ObservableObject {
  @Published var condition =
    "The export has completed successfully, not merely started, failed or been cancelled."
  @Published var windows: [WindowTarget] = []
  @Published var selectedID = ""
  @Published var actionWindowID = ""
  @Published var followUp = FollowUp.reveal
  @Published var folder: SelectedFolder?
  @Published var phase = WatchPhase.armed
  @Published var reason = "Choose a window. Define what done means."
  @Published var observations: [Observation] = []
  @Published var selectedObservation: UUID?
  @Published var liveText = ""
  @Published var baselineText = ""
  @Published var modelID = "Jev · waiting"
  @Published var requests = 0
  @Published var latency = 0.0
  @Published var confirmations = 0
  @Published var active = false
  @Published var evaluating = false
  @Published var permission = NativeAccess.trusted
  @Published var error: String?
  @Published var limit = 5
  @Published var elapsed = 0.0
  @Published var actionReceipt = ""
  @Published var showBaseline = false
  private var engine: WatchEngine?
  private var loop: Task<Void, Never>?
  private var sequence = 0
  private var generation = UUID()

  var evidence: Observation? {
    observations.first(where: { $0.id == selectedObservation }) ?? observations.first
  }

  var keyAvailable: Bool { (try? JevClient()) != nil }

  func refresh() {
    permission = NativeAccess.trusted
    do {
      let newWindows = try NativeAccess.windows()
      windows = newWindows
      selectedID = newWindows.first?.id ?? ""
      actionWindowID = selectedID
      error = nil
    } catch { self.error = error.localizedDescription }
  }

  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "Use this folder"
    if panel.runModal() == .OK, let url = panel.url {
      do { folder = try SelectedFolder(url: url) } catch { self.error = error.localizedDescription }
    }
  }

  func openFixture() {
    guard let resources = Bundle.main.resourceURL else { return }
    let url = resources.appendingPathComponent("Fixtures/Successful export.command")
    guard NSWorkspace.shared.open(url) else {
      error = "Cannot open the bundled Terminal fixture."
      return
    }
  }

  func arm() {
    guard !active, let target = windows.first(where: { $0.id == selectedID }) else {
      error = "Select an accessible window first."
      return
    }
    let intent = condition.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !intent.isEmpty, intent.count <= 1000 else {
      error = "Use a condition between 1 and 1,000 characters."
      return
    }
    let action = ArmedAction(
      kind: followUp, folder: folder,
      window: windows.first(where: { $0.id == actionWindowID }))
    do {
      let client = try JevClient()
      try action.validate()
      sequence = 0
      let baseline = try NativeAccess.snapshot(target, sequence: sequence)
      engine = WatchEngine(baseline: baseline, timeout: Double(limit) * 60)
      baselineText = baseline.text
      liveText = baseline.text
      observations = []
      selectedObservation = nil
      showBaseline = false
      modelID = "Jev · waiting"
      requests = 0
      confirmations = 0
      latency = 0
      elapsed = 0
      actionReceipt = ""
      error = nil
      active = true
      let run = UUID()
      generation = run
      sync()
      addObservation(
        text: baseline.text, reason: "Arming baseline · excluded from completion evidence")
      loop = Task {
        if action.kind == .notify {
          do {
            guard
              try await UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert, .sound,
              ])
            else {
              throw NativeError.actionFailed
            }
          } catch {
            guard generation == run else { return }
            engine?.fail("Notifications unavailable. Choose a different follow-up.")
            finish()
            return
          }
        }
        while !Task.isCancelled && generation == run && active {
          do {
            try await Task.sleep(for: .seconds(1))
            try Task.checkCancellation()
            sequence += 1
            let current = try NativeAccess.snapshot(target, sequence: sequence)
            elapsed = Date().timeIntervalSince(baseline.capturedAt)
            liveText = current.text
            guard let ticket = engine?.observe(current, now: Date()) else {
              sync()
              if engine?.phase.terminal == true { finish() }
              continue
            }
            evaluating = true
            sync()
            let result = try await client.evaluate(
              EvaluationState(condition: intent, baseline: baseline.text, current: current.text))
            guard generation == run, !Task.isCancelled else { return }
            requests += result.requests
            latency = result.milliseconds
            modelID = result.model
            evaluating = false
            sequence += 1
            let fresh = try NativeAccess.snapshot(target, sequence: sequence)
            liveText = fresh.text
            let fire =
              engine?.resolve(ticket, signals: result.signals, current: fresh, now: Date()) ?? false
            sync()
            addObservation(
              text: current.text, signals: result.signals, duration: result.milliseconds,
              reason: reason)
            if fire {
              do {
                try await action.execute()
                actionReceipt =
                  action.kind == .reveal
                  ? "Finder reveal requested for \(action.folder?.url.lastPathComponent ?? "your folder")."
                  : "\(action.kind.rawValue) requested once."
              } catch { engine?.actionFailed(error.localizedDescription) }
            }
            if engine?.phase.terminal == true { finish() }
          } catch is CancellationError {
            return
          } catch {
            guard generation == run, !Task.isCancelled else { return }
            engine?.fail(error.localizedDescription)
            finish()
          }
        }
      }
    } catch { self.error = error.localizedDescription }
  }

  func cancel() {
    generation = UUID()
    loop?.cancel()
    engine?.cancel()
    finish()
  }

  func sync() {
    guard let engine else { return }
    phase = engine.phase
    reason = engine.reason
    confirmations = engine.confirmations
  }

  func finish() {
    active = false
    evaluating = false
    sync()
  }

  private func addObservation(
    text: String, signals: Signals? = nil, duration: Double? = nil, reason: String
  ) {
    observations.insert(
      Observation(at: Date(), text: text, signals: signals, duration: duration, reason: reason),
      at: 0)
    observations = Array(observations.prefix(30))
    selectedObservation = observations.first?.id
  }

  func startShowcase(folderURL: URL) async {
    refresh()
    guard
      let terminal = windows.first(where: {
        $0.appName == "Terminal" && $0.title.contains("Watchword")
      })
    else {
      error = "Open the Watchword Terminal fixture before --showcase."
      return
    }
    selectedID = terminal.id
    actionWindowID = terminal.id
    followUp = .reveal
    do { folder = try SelectedFolder(url: folderURL) } catch {
      self.error = error.localizedDescription
      return
    }
    arm()
  }
}
