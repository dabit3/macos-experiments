import Foundation

enum Module: String, Codable, CaseIterable, Identifiable {
  case oscillator, filter, envelope, output
  var id: String { rawValue }
  var title: String {
    switch self {
    case .oscillator: "Oscillator"
    case .filter: "Low-pass"
    case .envelope: "Envelope"
    case .output: "Output"
    }
  }
  var short: String {
    switch self {
    case .oscillator: "OSC"
    case .filter: "VCF"
    case .envelope: "VCA"
    case .output: "OUT"
    }
  }
}

enum WaveShape: String, Codable, CaseIterable {
  case sine, triangle, saw
}

struct Cable: Codable, Equatable, Identifiable {
  let source: Module
  let destination: Module
  var id: String { "\(source.rawValue)-\(destination.rawValue)" }
}

enum PatchError: Error, LocalizedError, Equatable {
  case invalidPort, occupiedInput, cycle, invalidParameters
  var errorDescription: String? {
    switch self {
    case .invalidPort: "That connection is not possible. Choose an OUT, then an IN."
    case .occupiedInput: "That input already has a cable. Tap its cable below to remove it first."
    case .cycle: "Feedback loop blocked. A patch must flow forward without a cycle."
    case .invalidParameters: "This patch contains unsupported values and could not be loaded."
    }
  }
}

struct Patch: Codable, Equatable, Identifiable {
  var id = UUID()
  var name: String
  var subtitle: String
  var shape: WaveShape = .saw
  var frequency = 220.0
  var cutoff = 1600.0
  var decay = 0.8
  var volume = 0.35
  var cables: [Cable]

  mutating func connect(_ source: Module, to destination: Module) throws {
    guard source != .output, destination != .oscillator, source != destination else {
      throw PatchError.invalidPort
    }
    guard !cables.contains(where: { $0.destination == destination }) else {
      throw PatchError.occupiedInput
    }
    var visited: Set<Module> = []
    func reachesSource(_ node: Module) -> Bool {
      if node == source { return true }
      guard visited.insert(node).inserted else { return false }
      return cables.filter { $0.source == node }.contains { reachesSource($0.destination) }
    }
    guard !reachesSource(destination) else { throw PatchError.cycle }
    cables.append(Cable(source: source, destination: destination))
  }

  func validated() throws -> Patch {
    guard frequency.isFinite, cutoff.isFinite, decay.isFinite, volume.isFinite,
      (40...1000).contains(frequency), (80...12000).contains(cutoff),
      (0.1...3).contains(decay), (0...0.8).contains(volume),
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 40
    else { throw PatchError.invalidParameters }
    var copy = self
    copy.cables = []
    for cable in cables { try copy.connect(cable.source, to: cable.destination) }
    return self
  }

  var signalPath: [Module] {
    var path: [Module] = [.output]
    var current = Module.output
    while let previous = cables.first(where: { $0.destination == current })?.source {
      guard !path.contains(previous) else { return [] }
      path.insert(previous, at: 0)
      current = previous
      if current == .oscillator { return path }
    }
    return []
  }

  static let warm = Patch(
    name: "Peach circuit", subtitle: "A warm, rounded starting point.",
    cables: [
      Cable(source: .oscillator, destination: .filter),
      Cable(source: .filter, destination: .envelope),
      Cable(source: .envelope, destination: .output),
    ])
  static let glass = Patch(
    name: "Glass garden", subtitle: "Pure sine tones. Leave room to breathe.", shape: .sine,
    frequency: 329.63, cutoff: 4800, decay: 1.8, volume: 0.45,
    cables: [
      Cable(source: .oscillator, destination: .envelope),
      Cable(source: .envelope, destination: .output),
    ])
  static let velvet = Patch(
    name: "Velvet current", subtitle: "A soft triangle through a dark filter.", shape: .triangle,
    frequency: 130.81, cutoff: 550, decay: 1.4, volume: 0.5,
    cables: [
      Cable(source: .oscillator, destination: .filter),
      Cable(source: .filter, destination: .output),
    ])
  static let blank = Patch(
    name: "Open canvas", subtitle: "Start with a sound. Follow the signal.", cables: [])
  static let presets: [Patch] = [.warm, .glass, .velvet, .blank]
}

struct PatchLibrary: Codable {
  var current: Patch
  var saved: [Patch]

  func validated() throws -> PatchLibrary {
    _ = try current.validated()
    for patch in saved { _ = try patch.validated() }
    return self
  }
}
