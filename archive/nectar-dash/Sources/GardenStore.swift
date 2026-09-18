import Combine
import SwiftUI
import UIKit

enum GardenScreen { case home, playing, result }

struct PollenParticle: Identifiable {
  let id = UUID()
  let point: GardenPoint
  let color: BloomColor
  let created: Double
}

struct HazardFeedback {
  let hazard: Hazard
  let created: Double
}

@MainActor
final class GardenStore: ObservableObject {
  @Published var screen = GardenScreen.home
  @Published var rules = GardenRules(mode: .meadow(1))
  @Published var progress: GardenProgress
  @Published var selectedStage = 1
  @Published var paused = false
  @Published var showTutorial = false
  @Published var showSettings = false
  @Published var toast = "Follow the flowers. Find your flow."
  @Published var toastAge = 0.0
  @Published var beeVisual = GardenPoint.hive
  @Published var flightPath: [GardenPoint] = []
  @Published var particles: [PollenParticle] = []
  @Published var hazardFeedback: HazardFeedback?
  @Published var clock = 0.0
  @Published var waveAge = 10.0
  @Published var haptics: Bool {
    didSet { defaults.set(haptics, forKey: "nectar.haptics") }
  }
  @Published var calmMotion: Bool {
    didSet { defaults.set(calmMotion, forKey: "nectar.calmMotion") }
  }
  private let defaults: UserDefaults
  private var flightElapsed = 0.0
  private var flightDuration = 0.0
  private var lastFrame = ProcessInfo.processInfo.systemUptime
  private var timer: AnyCancellable?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let savedProgress = GardenProgress.load(from: defaults)
    progress = savedProgress
    selectedStage = savedProgress.unlockedStage
    haptics = defaults.object(forKey: "nectar.haptics") as? Bool ?? true
    calmMotion = defaults.bool(forKey: "nectar.calmMotion")
    timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
      .autoconnect().sink { [weak self] _ in
        guard let self else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - self.lastFrame
        self.lastFrame = now
        self.step(elapsed)
      }
  }

  var isFlying: Bool { !flightPath.isEmpty }

  func start(_ mode: GardenMode) {
    lastFrame = ProcessInfo.processInfo.systemUptime
    rules = GardenRules(mode: mode)
    beeVisual = .hive
    flightPath = []
    particles = []
    hazardFeedback = nil
    paused = false
    showTutorial = !defaults.bool(forKey: "nectar.tutorialSeen")
    toast = "Begin with a gold bloom · look for 1"
    toastAge = 0
    waveAge = 10
    screen = .playing
  }

  func dismissTutorial() {
    lastFrame = ProcessInfo.processInfo.systemUptime
    defaults.set(true, forKey: "nectar.tutorialSeen")
    showTutorial = false
  }

  func home() {
    screen = .home
    flightPath = []
    paused = false
    selectedStage = progress.unlockedStage
  }

  func sendFlight(_ points: [GardenPoint]) {
    guard screen == .playing, !paused, !showTutorial, !isFlying, rules.end == nil,
      let end = points.last
    else { return }
    var clean = points.map {
      GardenPoint(x: min(0.96, max(0.04, $0.x)), y: min(0.95, max(0.04, $0.y)))
    }
    clean[0] = rules.bee
    if clean.count < 2 { clean = [rules.bee, end] }
    let distance = zip(clean, clean.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
    guard distance > 0.015 else { return }
    guard distance < 2.4 else {
      announce("A little shorter! Draw one flight at a time.")
      return
    }
    flightPath = clean
    flightElapsed = 0
    flightDuration = max(0.35, distance * 1.7)
  }

  func tap(_ point: GardenPoint) { sendFlight([rules.bee, point]) }

  func announce(_ text: String) {
    toast = text
    toastAge = 0
    UIAccessibility.post(notification: .announcement, argument: text)
  }

  func step(_ delta: Double) {
    guard !paused, !showSettings else { return }
    clock += delta
    guard screen == .playing, !showTutorial else { return }
    rules.tick(delta)
    toastAge += delta
    waveAge += delta
    particles.removeAll { clock - $0.created > 1.5 }
    if let feedback = hazardFeedback, clock - feedback.created > 2.5 {
      hazardFeedback = nil
    }
    if isFlying {
      flightElapsed += delta
      let amount = min(1, flightElapsed / flightDuration)
      beeVisual = position(on: flightPath, amount: amount)
      if amount >= 1 {
        let color = rules.expected
        let event = rules.fly(along: flightPath)
        if event == .web || event == .wind {
          let kind: HazardKind = event == .web ? .web : .wind
          if let hazard = rules.hazards.first(where: {
            $0.kind == kind && GardenRules.touches($0, along: flightPath)
          }) {
            hazardFeedback = HazardFeedback(hazard: hazard, created: clock)
          }
        }
        flightPath = []
        beeVisual = rules.bee
        respond(to: event, color: color)
      }
    }
    if rules.end != nil {
      flightPath = []
      progress.record(rules)
      progress.save(to: defaults)
      screen = .result
    }
  }

  private func position(on points: [GardenPoint], amount: Double) -> GardenPoint {
    let segments = zip(points, points.dropFirst()).map { $0.distance(to: $1) }
    let total = segments.reduce(0, +)
    var remaining = total * amount
    for index in segments.indices {
      if remaining <= segments[index] {
        return points[index].interpolated(
          to: points[index + 1], amount: remaining / max(0.0001, segments[index]))
      }
      remaining -= segments[index]
    }
    return points.last ?? .hive
  }

  private func respond(to event: FlightEvent, color: BloomColor) {
    switch event {
    case .bloom, .blossomWave:
      particles.append(PollenParticle(point: rules.bee, color: color, created: clock))
      if event == .blossomWave {
        waveAge = 0
        announce("BLOSSOM WAVE · +30 bonus! Return to the hive.")
      } else {
        announce(
          rules.pollen == 3
            ? "Chain ×2! Keep going, or bank at the hive."
            : "Lovely. Next: \(rules.expected.name) \(rules.expected.mark)")
      }
      if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    case .bank(let points):
      announce("+\(points) honey safely banked · start with Gold 1")
      if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    case .web:
      announce("Tangled! Pollen lost. Trace around the web.")
      if haptics { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    case .wind: announce("Headwind! −5 seconds. Fly around or wait for a lull.")
    case .wrongColor:
      announce("Wrong bloom · −3s. Follow \(rules.expected.name) \(rules.expected.mark).")
    case .emptyHive: announce("Your hive is safe. Find a Gold 1 bloom.")
    case .full: announce("Pollen satchel full! Return to the hive to bank.")
    case .resting: announce("This bloom is resting. Find another \(rules.expected.name).")
    case .missed: announce("Land on a numbered bloom, or return to the hive.")
    }
  }
}
