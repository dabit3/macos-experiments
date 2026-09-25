import Foundation

enum PhaseKind: String, Codable, CaseIterable, Identifiable {
  case work, rest
  var id: String { rawValue }
  var title: String { rawValue.capitalized }
}

struct Interval: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var kind: PhaseKind
  var seconds: Int
}

struct Routine: Identifiable, Codable, Equatable {
  var id = UUID()
  var name: String
  var subtitle: String
  var rounds: Int
  var intervals: [Interval]
  var isExample = false

  var totalSeconds: Int { intervals.reduce(0) { $0 + $1.seconds } * rounds }
  var workSeconds: Int {
    intervals.filter { $0.kind == .work }.reduce(0) { $0 + $1.seconds } * rounds
  }
  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (1...30).contains(rounds) && !intervals.isEmpty && intervals.count <= 12
      && intervals.contains { $0.kind == .work }
      && intervals.allSatisfy {
        (1...3600).contains($0.seconds)
          && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
  }
  static var blank: Routine {
    Routine(
      name: "", subtitle: "Your pace. Your practice.", rounds: 2,
      intervals: [
        Interval(name: "Work", kind: .work, seconds: 30),
        Interval(name: "Recover", kind: .rest, seconds: 15),
      ])
  }
  static let examples = [
    Routine(
      name: "Quick spark", subtitle: "A little effort. A fresh start.", rounds: 6,
      intervals: [
        Interval(name: "Move with intent", kind: .work, seconds: 30),
        Interval(name: "Catch your breath", kind: .rest, seconds: 15),
      ], isExample: true),
    Routine(
      name: "Steady strength", subtitle: "Stay present in every rep.", rounds: 4,
      intervals: [
        Interval(name: "Controlled movement", kind: .work, seconds: 45),
        Interval(name: "Reset", kind: .rest, seconds: 15),
      ], isExample: true),
    Routine(
      name: "Find your rhythm", subtitle: "Try the timer in thirty seconds.", rounds: 2,
      intervals: [
        Interval(name: "Find your pace", kind: .work, seconds: 10),
        Interval(name: "Release", kind: .rest, seconds: 5),
      ], isExample: true),
  ]
}

struct WorkoutRecord: Identifiable, Codable {
  var id: UUID
  var name: String
  var date: Date
  var activeSeconds: Double
  var workSeconds: Double
  var completedPhases: Int
  var totalPhases: Int
  var skippedPhases: Int
  var completed: Bool
  var rounds: Int
}

struct Session: Identifiable, Codable {
  var id = UUID()
  var routine: Routine
  var startedAt: Date
  var phaseStartedAt: Date
  var index = 0
  var paused = false
  var pausedElapsed: Double = 0
  var activeSeconds: Double = 0
  var workSeconds: Double = 0
  var completedPhases = 0
  var skippedPhases = 0
  var skippedIndices: [Int]?
  var finished = false
  var endedEarly = false
  var endedAt: Date?

  init(routine: Routine, now: Date) {
    self.routine = routine
    startedAt = now
    phaseStartedAt = now
  }

  var phaseCount: Int { routine.intervals.count * routine.rounds }
  var phase: Interval { routine.intervals[min(index, phaseCount - 1) % routine.intervals.count] }
  var round: Int { min(index / routine.intervals.count + 1, routine.rounds) }
  var nextPhase: Interval? {
    index + 1 < phaseCount ? routine.intervals[(index + 1) % routine.intervals.count] : nil
  }
  func elapsed(at now: Date) -> Double {
    finished
      ? 0
      : min(
        Double(phase.seconds),
        max(0, paused ? pausedElapsed : now.timeIntervalSince(phaseStartedAt)))
  }
  func remaining(at now: Date) -> Int {
    finished ? 0 : max(0, Int(ceil(Double(phase.seconds) - elapsed(at: now))))
  }
  func totalActive(at now: Date) -> Double { activeSeconds + elapsed(at: now) }

  mutating func synchronize(at now: Date) {
    guard !paused, !finished else { return }
    while now.timeIntervalSince(phaseStartedAt) >= Double(phase.seconds), !finished {
      let duration = Double(phase.seconds)
      consume(duration)
      completedPhases += 1
      index += 1
      phaseStartedAt = phaseStartedAt.addingTimeInterval(duration)
      if index == phaseCount {
        finished = true
        endedAt = phaseStartedAt
      }
    }
  }
  mutating func pause(at now: Date) {
    synchronize(at: now)
    guard !finished, !paused else { return }
    pausedElapsed = elapsed(at: now)
    paused = true
  }
  mutating func resume(at now: Date) {
    guard paused, !finished else { return }
    phaseStartedAt = now.addingTimeInterval(-pausedElapsed)
    paused = false
  }
  mutating func skip(at now: Date) {
    synchronize(at: now)
    guard !finished else { return }
    consume(elapsed(at: now))
    skippedIndices = (skippedIndices ?? []) + [index]
    skippedPhases += 1
    index += 1
    pausedElapsed = 0
    phaseStartedAt = now
    if index == phaseCount {
      finished = true
      endedAt = now
    }
  }
  mutating func end(at now: Date) {
    synchronize(at: now)
    guard !finished else { return }
    consume(elapsed(at: now))
    finished = true
    endedEarly = true
    endedAt = now
  }
  private mutating func consume(_ seconds: Double) {
    activeSeconds += seconds
    if phase.kind == .work { workSeconds += seconds }
  }
  var record: WorkoutRecord {
    WorkoutRecord(
      id: id, name: routine.name, date: endedAt ?? startedAt,
      activeSeconds: activeSeconds, workSeconds: workSeconds,
      completedPhases: completedPhases, totalPhases: phaseCount,
      skippedPhases: skippedPhases, completed: !endedEarly, rounds: routine.rounds)
  }
}

func clock(_ seconds: Int) -> String {
  String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
}

func durationLabel(_ seconds: Int) -> String {
  seconds < 60
    ? "\(seconds)s"
    : seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60)m \(seconds % 60)s"
}
