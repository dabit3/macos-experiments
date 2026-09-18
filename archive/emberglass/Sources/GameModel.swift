import Combine
import Foundation
import UIKit

enum Commission: Int, CaseIterable, Codable {
  case tide, bloom, spire

  var title: String {
    switch self {
    case .tide: "Tide vessel"
    case .bloom: "Orchid vessel"
    case .spire: "Ember spire"
    }
  }

  var collection: String {
    switch self {
    case .tide: "01 / THE TIDAL COLLECTION"
    case .bloom: "02 / THE BOTANICAL COLLECTION"
    case .spire: "03 / THE ELEMENTAL COLLECTION"
    }
  }

  var subtitle: String {
    switch self {
    case .tide: "A quiet curve. An ocean held in glass."
    case .bloom: "An open lip. A bloom that never fades."
    case .spire: "A slender form. A flame made permanent."
    }
  }

  var radii: [Double] {
    switch self {
    case .tide: [0.38, 0.32, 0.34, 0.52, 0.73, 0.82, 0.72, 0.46]
    case .bloom: [0.78, 0.71, 0.57, 0.61, 0.78, 0.86, 0.70, 0.37]
    case .spire: [0.24, 0.23, 0.27, 0.35, 0.44, 0.54, 0.59, 0.35]
    }
  }
}

enum Stage: String {
  case home, heat, spin, shape, result

  var isPlaying: Bool { self == .heat || self == .spin || self == .shape }
  var duration: Double {
    switch self {
    case .heat: 14
    case .spin: 14
    case .shape: 26
    default: 0
    }
  }

  var step: String {
    switch self {
    case .heat: "01 / GATHER THE FIRE"
    case .spin: "02 / FIND THE BALANCE"
    case .shape: "03 / FOLLOW THE FORM"
    default: ""
    }
  }

  var title: String {
    switch self {
    case .heat: "Heat the glass."
    case .spin: "Keep it centered."
    case .shape: "Trace the curve."
    default: ""
    }
  }
}

struct CraftRules {
  static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }

  static func contourTangents(_ radii: [Double]) -> [Double] {
    guard radii.count > 1 else { return radii.map { _ in 0 } }
    let slopes = zip(radii.dropFirst(), radii).map { $0 - $1 }
    return radii.indices.map { index in
      if index == 0 { return slopes[0] }
      if index == radii.count - 1 { return slopes[index - 1] }
      let before = slopes[index - 1]
      let after = slopes[index]
      return before * after > 0 ? 2 * before * after / (before + after) : 0
    }
  }

  static func heatWindow(at time: Double) -> Double {
    0.54 + 0.15 * sin(time * 0.55)
  }

  static func balanceWindow(at time: Double) -> Double {
    0.5 + 0.23 * sin(time * 0.63)
  }

  static func heatStep(temperature: Double, holding: Bool, delta: Double) -> Double {
    clamp(temperature + (holding ? 0.18 : -0.10) * delta)
  }

  static func proximity(_ value: Double, target: Double, tolerance: Double) -> Double {
    clamp(1 - max(0, abs(value - target) - tolerance) / 0.30)
  }

  static func shapeScore(profile: [Double], touched: Set<Int>, target: [Double]) -> Double {
    guard profile.count == target.count, !target.isEmpty else { return 0 }
    return target.indices.reduce(0) { total, index in
      total + (touched.contains(index) ? clamp(1 - abs(profile[index] - target[index]) / 0.28) : 0)
    } / Double(target.count)
  }

  static func total(heat: Double, spin: Double, shape: Double) -> Int {
    Int((clamp(heat) * 0.28 + clamp(spin) * 0.28 + clamp(shape) * 0.44) * 100)
  }

  static func grade(score: Int) -> String {
    switch score {
    case 90...: "MASTERWORK"
    case 75..<90: "EXQUISITE"
    case 55..<75: "COLLECTIBLE"
    default: "STUDY"
    }
  }
}

struct GalleryPiece: Identifiable, Codable {
  var id = UUID()
  var commission: Commission
  var score: Int
  var heat: Int
  var spin: Int
  var shape: Int
  var profile: [Double]
  var date = Date()
  var collected: Bool { score >= 55 }
  var grade: String { CraftRules.grade(score: score) }
}

struct ProgressArchive: Codable {
  var pieces: [GalleryPiece] = []
  var best = 0
  var unlocked = 0

  mutating func record(_ piece: GalleryPiece) {
    best = max(best, piece.score)
    if piece.collected {
      unlocked = min(2, max(unlocked, piece.commission.rawValue + 1))
    }
    pieces.insert(piece, at: 0)
    pieces = Array(pieces.prefix(24))
  }
}

@MainActor
final class Studio: ObservableObject {
  @Published var stage: Stage = .home
  @Published var commission: Commission = .tide
  @Published var archive = ProgressArchive()
  @Published var paused = false
  @Published var tutorial = false
  @Published var elapsed = 0.0
  @Published var temperature = 0.46
  @Published var holding = false
  @Published var rotation = 0.5
  @Published var profile = Commission.tide.radii.map { $0 * 0.73 }
  @Published var touched = Set<Int>()
  @Published var result: GalleryPiece?
  @Published var haptics: Bool {
    didSet { defaults.set(haptics, forKey: "haptics") }
  }

  private let defaults: UserDefaults
  private var heatTotal = 0.0
  private var spinTotal = 0.0
  private var heat = 0.0
  private var spin = 0.0
  private var sampleDuration = 0.0

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    if let data = defaults.data(forKey: "emberglass.archive"),
      let saved = try? JSONDecoder().decode(ProgressArchive.self, from: data)
    {
      archive = saved
    }
  }

  var remaining: Int { max(0, Int(ceil(stage.duration - elapsed))) }
  var heatTarget: Double { CraftRules.heatWindow(at: elapsed) }
  var spinTarget: Double { CraftRules.balanceWindow(at: elapsed) }
  var liveQuality: Int {
    switch stage {
    case .heat:
      Int(CraftRules.proximity(temperature, target: heatTarget, tolerance: 0.1) * 100)
    case .spin:
      Int(CraftRules.proximity(rotation, target: spinTarget, tolerance: 0.09) * 100)
    case .shape:
      Int(CraftRules.shapeScore(profile: profile, touched: touched, target: commission.radii) * 100)
    default: 0
    }
  }

  func start() {
    result = nil
    heat = 0
    spin = 0
    heatTotal = 0
    spinTotal = 0
    temperature = 0.46
    rotation = 0.5
    profile = commission.radii.map { $0 * 0.73 }
    touched = []
    paused = false
    enter(.heat)
  }

  func enter(_ next: Stage) {
    stage = next
    elapsed = 0
    sampleDuration = 0
    holding = false
    tutorial = next.isPlaying && !defaults.bool(forKey: "learned.\(next.rawValue)")
    feedback()
  }

  func dismissTutorial() {
    defaults.set(true, forKey: "learned.\(stage.rawValue)")
    tutorial = false
  }

  func tick(delta: Double) {
    guard stage.isPlaying, !paused, !tutorial else { return }
    let dt = min(max(0, delta), 0.1)
    elapsed += dt
    sampleDuration += dt
    switch stage {
    case .heat:
      temperature = CraftRules.heatStep(temperature: temperature, holding: holding, delta: dt)
      heatTotal += CraftRules.proximity(temperature, target: heatTarget, tolerance: 0.10) * dt
      if elapsed >= stage.duration {
        heat = heatTotal / sampleDuration
        enter(.spin)
      }
    case .spin:
      spinTotal += CraftRules.proximity(rotation, target: spinTarget, tolerance: 0.09) * dt
      if elapsed >= stage.duration {
        spin = spinTotal / sampleDuration
        enter(.shape)
      }
    case .shape:
      if elapsed >= stage.duration { finish() }
    default: break
    }
  }

  func trace(index: Int, radius: Double) {
    guard stage == .shape, !paused, !tutorial, profile.indices.contains(index) else { return }
    profile[index] = min(0.94, max(0.18, radius))
    if touched.insert(index).inserted { feedback() }
  }

  func finish() {
    guard stage == .shape, !paused, !tutorial else { return }
    let shape = CraftRules.shapeScore(profile: profile, touched: touched, target: commission.radii)
    let piece = GalleryPiece(
      commission: commission, score: CraftRules.total(heat: heat, spin: spin, shape: shape),
      heat: Int(heat * 100), spin: Int(spin * 100), shape: Int(shape * 100), profile: profile
    )
    result = piece
    archive.record(piece)
    if let data = try? JSONEncoder().encode(archive) {
      defaults.set(data, forKey: "emberglass.archive")
    }
    enter(.result)
  }

  func suspend() {
    if stage.isPlaying {
      paused = true
      holding = false
    }
  }

  func home() {
    holding = false
    paused = false
    tutorial = false
    stage = .home
  }

  func feedback() {
    if haptics { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
  }
}
