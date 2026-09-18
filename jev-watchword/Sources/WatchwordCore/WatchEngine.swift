import Foundation

public enum WatchPhase: String, Codable, Sendable {
  case armed = "Armed"
  case observing = "Observing"
  case candidate = "Candidate"
  case fired = "Fired"
  case needsAttention = "Needs attention"
  case expired = "Expired"
  case cancelled = "Cancelled"

  public var terminal: Bool {
    [.fired, .needsAttention, .expired, .cancelled].contains(self)
  }
}

public struct Snapshot: Equatable, Sendable {
  public let target: String
  public let text: String
  public let capturedAt: Date
  public let sequence: Int

  public init(target: String, text: String, capturedAt: Date = Date(), sequence: Int) {
    self.target = target
    self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    self.capturedAt = capturedAt
    self.sequence = sequence
  }
}

public struct Signals: Codable, Equatable, Sendable {
  public let satisfied: Double
  public let failed: Double
  public let insufficient: Double

  public init(satisfied: Double, failed: Double, insufficient: Double) throws {
    guard [satisfied, failed, insufficient].allSatisfy({ $0.isFinite && (0...1).contains($0) })
    else {
      throw JevError.invalidResponse
    }
    self.satisfied = satisfied
    self.failed = failed
    self.insufficient = insufficient
  }

  public var confirmed: Bool { satisfied >= 0.92 && failed <= 0.08 && insufficient <= 0.08 }
}

public struct EvaluationTicket: Sendable {
  public let runID: UUID
  public let snapshot: Snapshot
  public let baseline: String
}

public struct WatchEngine {
  public private(set) var phase = WatchPhase.armed
  public private(set) var reason = "Baseline captured. Waiting for new visible evidence."
  public private(set) var confirmations = 0
  public private(set) var latest: Snapshot
  public private(set) var signals: Signals?
  public let runID = UUID()
  public let baseline: Snapshot
  public let deadline: Date
  private var candidateAt: Date?
  private var evaluatedText: String?
  private var pendingSequence: Int?
  private var issued = 0
  public let maxRequests: Int

  public init(baseline: Snapshot, timeout: TimeInterval = 300, maxRequests: Int = 120) {
    self.baseline = baseline
    self.latest = baseline
    self.deadline = baseline.capturedAt.addingTimeInterval(timeout)
    self.maxRequests = maxRequests
  }

  public mutating func observe(_ snapshot: Snapshot, now: Date) -> EvaluationTicket? {
    guard !phase.terminal else { return nil }
    guard now < deadline else {
      stop(.expired, "Time limit reached. No follow-up was executed.")
      return nil
    }
    guard snapshot.target == baseline.target else {
      stop(.needsAttention, "The selected target changed. Re-select and arm again.")
      return nil
    }
    guard snapshot.sequence > latest.sequence,
      (0...5).contains(now.timeIntervalSince(snapshot.capturedAt))
    else {
      reason = "Discarded an old or out-of-order observation."
      return nil
    }
    let changed = snapshot.text != latest.text
    latest = snapshot
    if changed {
      confirmations = 0
      candidateAt = nil
      phase = .observing
    }
    guard !snapshot.text.isEmpty else {
      stop(.needsAttention, "The selected window exposes no usable text.")
      return nil
    }
    guard pendingSequence == nil else { return nil }
    guard snapshot.text != baseline.text else {
      phase = .observing
      reason = "Only the arming baseline is visible. Historical completion cannot fire."
      return nil
    }
    if evaluatedText == snapshot.text {
      guard phase == .candidate, let candidateAt,
        now.timeIntervalSince(candidateAt) >= 2
      else {
        if phase != .candidate { reason = "Text unchanged. Watching locally; no API request." }
        return nil
      }
    }
    guard issued < maxRequests else {
      stop(.expired, "Request budget exhausted. No follow-up was executed.")
      return nil
    }
    issued += 1
    pendingSequence = snapshot.sequence
    if phase != .candidate { phase = .observing }
    reason =
      phase == .candidate
      ? "Re-reading stable evidence for a second independent Jev evaluation."
      : "New AX text observed. Evaluating three independent conditions."
    return EvaluationTicket(runID: runID, snapshot: snapshot, baseline: baseline.text)
  }

  public mutating func resolve(
    _ ticket: EvaluationTicket, signals: Signals, current: Snapshot, now: Date
  ) -> Bool {
    guard !phase.terminal, ticket.runID == runID,
      pendingSequence == ticket.snapshot.sequence
    else { return false }
    pendingSequence = nil
    guard now < deadline else {
      stop(.expired, "The deadline passed while Jev was responding.")
      return false
    }
    guard current.target == baseline.target else {
      stop(.needsAttention, "Target identity changed before the action.")
      return false
    }
    guard current.text == ticket.snapshot.text,
      current.sequence > ticket.snapshot.sequence,
      current.sequence >= latest.sequence,
      (0...10).contains(now.timeIntervalSince(ticket.snapshot.capturedAt)),
      (0...2).contains(now.timeIntervalSince(current.capturedAt))
    else {
      confirmations = 0
      candidateAt = nil
      evaluatedText = nil
      phase = .observing
      reason = "Discarded a delayed answer: its evidence is no longer current."
      return false
    }
    latest = current
    self.signals = signals
    evaluatedText = current.text
    if signals.failed >= 0.85 {
      stop(.needsAttention, "Jev detected failure or cancellation. Follow-up suppressed.")
    } else if signals.confirmed {
      confirmations += 1
      if confirmations == 1 {
        phase = .candidate
        candidateAt = now
        reason = "1 of 2 confirmations. A fresh snapshot must still agree after 2 seconds."
      } else {
        phase = .fired
        reason = "2 fresh confirmations; completion ≥92%, failure and insufficient ≤8%. Fired once."
        return true
      }
    } else {
      confirmations = 0
      candidateAt = nil
      phase = .observing
      reason =
        signals.insufficient > 0.08
        ? "Evidence is ambiguous or historical. Waiting for a visible change."
        : "The requested condition is not confirmed. Waiting for a visible change."
    }
    return false
  }

  public mutating func fail(_ message: String) {
    guard !phase.terminal else { return }
    stop(.needsAttention, message)
  }

  public mutating func actionFailed(_ message: String) {
    guard phase == .fired else { return }
    stop(.needsAttention, "Follow-up could not complete: \(message). It will not be retried.")
  }

  public mutating func cancel() {
    guard !phase.terminal else { return }
    stop(.cancelled, "Cancelled by you. Pending responses cannot execute a follow-up.")
  }

  private mutating func stop(_ phase: WatchPhase, _ reason: String) {
    self.phase = phase
    self.reason = reason
    pendingSequence = nil
    candidateAt = nil
  }
}
