import AppKit
import AsterCore
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class MissionController {
  var mission = Mission()
  var paused = true
  var showPrediction = true
  var message = "Flight systems ready. Plan your first maneuver."
  var error: String?
  var currentPath: [TrajectoryPoint] = []
  var plannedPath: [TrajectoryPoint] = []
  var previousPath: [TrajectoryPoint] = []
  var burnFlash = false
  var hasSavedMission = false
  private var ticks = 0
  private var lastTick = Date()
  private let directory: URL

  init() {
    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Aster", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let autosave = directory.appendingPathComponent("autosave.json")
      if FileManager.default.fileExists(atPath: autosave.path) {
        mission = try Mission.decode(Data(contentsOf: autosave))
        message = "Last session restored. Flight is paused."
      }
    } catch {
      self.error = "Could not restore the last session: \(error.localizedDescription)"
    }
    hasSavedMission = FileManager.default.fileExists(atPath: savedURL.path)
    refreshPaths()
  }

  var state: FlightState { mission.state }
  var elements: Elements { Orbit.elements(state) }
  var proposed: FlightState {
    Orbit.burn(state, prograde: mission.plannedPrograde, radial: mission.plannedRadial)
  }
  var plannedElements: Elements { Orbit.elements(proposed) }
  var deltaV: Double { (proposed.velocity - state.velocity).magnitude * 1_000 }
  var goalMet: Bool { Orbit.goalMet(state) }
  var savedURL: URL { directory.appendingPathComponent("saved-mission.json") }
  var canBurn: Bool { !state.impacted && deltaV > 0.01 && mission.burns.count < 100 }

  func tick() {
    let now = Date()
    let elapsed = min(max(now.timeIntervalSince(lastTick), 0), 0.1)
    lastTick = now
    guard !paused else { return }
    mission.state = Orbit.advance(state, seconds: elapsed * mission.warp)
    ticks += 1
    if ticks % 15 == 0 { refreshPaths() }
    if ticks % 150 == 0 { persist() }
    if state.impacted {
      paused = true
      message = "Surface contact. Undo the last burn or reset the mission."
      refreshPaths()
      persist()
    }
  }

  func togglePause() {
    guard !state.impacted else { return }
    paused.toggle()
    lastTick = Date()
    if paused { persist() }
  }

  func setPlan(prograde: Double? = nil, radial: Double? = nil) {
    if let prograde, prograde.isFinite { mission.plannedPrograde = min(900, max(-900, prograde)) }
    if let radial, radial.isFinite { mission.plannedRadial = min(500, max(-500, radial)) }
    refreshPaths()
    persist()
  }

  func suggestedBurn() {
    setPlan(prograde: 460, radial: 0)
    showPrediction = true
    message = "Departure recipe loaded: +460 m/s. Inspect the cyan prediction before firing."
  }

  func setWarp(_ value: Double) {
    mission.warp = value
    persist()
  }

  func execute() {
    guard canBurn else { return }
    previousPath = currentPath
    mission.burns.append(
      BurnRecord(before: state, prograde: mission.plannedPrograde, radial: mission.plannedRadial))
    mission.state = proposed
    mission.plannedPrograde = 0
    mission.plannedRadial = 0
    burnFlash = true
    refreshPaths()
    message =
      goalMet
      ? "Objective achieved. Your probe has reached the transfer corridor."
      : "Maneuver executed. New orbit acquired."
    persist()
    Task {
      try? await Task.sleep(for: .seconds(1.4))
      burnFlash = false
    }
  }

  func undoBurn() {
    guard let record = mission.burns.popLast() else { return }
    mission.state = record.before
    mission.plannedPrograde = record.prograde
    mission.plannedRadial = record.radial
    paused = true
    previousPath = []
    message = "Burn undone. Returned to the maneuver point, with your plan restored."
    refreshPaths()
    persist()
  }

  func reset(survey: Bool = false) {
    mission = Mission()
    if survey {
      mission.state = Orbit.burn(Orbit.circular(altitude: 600), prograde: 220, radial: 80)
      mission.preset = "Survey / eccentric orbit"
    }
    paused = true
    previousPath = []
    message =
      "Fresh \(survey ? "survey" : "departure") orbit loaded. Saved checkpoint is unchanged."
    refreshPaths()
    persist()
  }

  func save() {
    do {
      try mission.encoded().write(to: savedURL, options: .atomic)
      hasSavedMission = true
      message = "Mission saved locally. Reload this checkpoint at any time."
    } catch { self.error = "Save failed: \(error.localizedDescription)" }
  }

  func reload() {
    do {
      let loaded = try Mission.decode(Data(contentsOf: savedURL))
      mission = loaded
      paused = true
      previousPath = []
      message = "Saved mission reloaded. Flight is paused."
      refreshPaths()
      persist()
    } catch {
      self.error = "Reload failed; current flight is unchanged. \(error.localizedDescription)"
    }
  }

  func persist() {
    do {
      try mission.encoded().write(
        to: directory.appendingPathComponent("autosave.json"), options: .atomic)
    } catch { self.error = "Autosave failed: \(error.localizedDescription)" }
  }

  func refreshPaths() {
    currentPath = Orbit.prediction(state)
    plannedPath = deltaV > 0.01 ? Orbit.prediction(proposed) : []
  }

  func export() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.commaSeparatedText]
    panel.nameFieldStringValue = "Aster-trajectory.csv"
    panel.title = "Export current orbit"
    panel.message =
      "Numerically propagated trajectory in kilometers and seconds, from the current state."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try Orbit.trajectoryCSV(state).write(to: url, atomically: true, encoding: .utf8)
      message = "Trajectory exported: \(url.lastPathComponent) · 421 samples maximum."
    } catch { self.error = "Export failed: \(error.localizedDescription)" }
  }
}
