import Foundation

public enum AudioError: LocalizedError {
  case invalidAudio
  case emptySelection
  case unsupported

  public var errorDescription: String? {
    switch self {
    case .invalidAudio: "The audio is empty or contains invalid samples."
    case .emptySelection: "Drag across the waveform to select a range first."
    case .unsupported: "Use mono or stereo audio, up to 120 seconds and 192 kHz."
    }
  }
}

public struct AudioDocument: Codable, Equatable, Sendable {
  public var name: String
  public let sampleRate: Double
  public var channels: [[Float]]

  public init(name: String, sampleRate: Double, channels: [[Float]]) throws {
    guard sampleRate.isFinite, sampleRate >= 8000, sampleRate <= 192_000,
      (1...2).contains(channels.count)
    else { throw AudioError.unsupported }
    guard let first = channels.first, !first.isEmpty,
      channels.allSatisfy({ $0.count == first.count && $0.allSatisfy(\.isFinite) })
    else { throw AudioError.invalidAudio }
    guard Double(first.count) / sampleRate <= 120 else { throw AudioError.unsupported }
    self.name = name
    self.sampleRate = sampleRate
    self.channels = channels
  }

  public var frameCount: Int { channels.first?.count ?? 0 }
  public var duration: Double { Double(frameCount) / sampleRate }
  public var peak: Float { channels.reduce(0) { max($0, $1.map { abs($0) }.max() ?? 0) } }
  public var clippedCount: Int { channels.reduce(0) { $0 + $1.filter { abs($0) > 1 }.count } }
  public var rms: Double {
    let count = channels.count * frameCount
    guard count > 0 else { return 0 }
    return sqrt(
      channels.reduce(0.0) { sum, channel in
        sum + channel.reduce(0.0) { $0 + Double($1) * Double($1) }
      } / Double(count))
  }

  public func validated() throws -> AudioDocument {
    try AudioDocument(name: name, sampleRate: sampleRate, channels: channels)
  }

  public func frameRange(start: Double, end: Double) throws -> Range<Int> {
    guard start.isFinite, end.isFinite else { throw AudioError.emptySelection }
    let lower = Int((max(0, min(duration, start)) * sampleRate).rounded())
    let upper = Int((max(0, min(duration, end)) * sampleRate).rounded())
    guard upper > lower else { throw AudioError.emptySelection }
    return min(lower, frameCount)..<min(upper, frameCount)
  }

  public mutating func trim(to range: Range<Int>) throws {
    try check(range)
    channels = channels.map { Array($0[range]) }
  }

  public mutating func fade(_ range: Range<Int>, fadeIn: Bool) throws {
    try check(range)
    guard range.count > 1 else { throw AudioError.emptySelection }
    for channel in channels.indices {
      for (offset, frame) in range.enumerated() {
        let phase = Float(offset) / Float(range.count - 1)
        channels[channel][frame] *= fadeIn ? phase : 1 - phase
      }
    }
  }

  public mutating func gain(_ range: Range<Int>, decibels: Double) throws {
    try check(range)
    guard decibels.isFinite, (-24...24).contains(decibels) else {
      throw AudioError.invalidAudio
    }
    let multiplier = Float(pow(10, decibels / 20))
    for channel in channels.indices {
      for frame in range { channels[channel][frame] *= multiplier }
    }
  }

  private func check(_ range: Range<Int>) throws {
    guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= frameCount else {
      throw AudioError.emptySelection
    }
  }

  public func wavData(range: Range<Int>? = nil) throws -> Data {
    let frames = range ?? 0..<frameCount
    try check(frames)
    let channelCount = UInt16(channels.count)
    let dataSize = UInt32(frames.count * channels.count * 2)
    var result = Data()
    func text(_ string: String) { result.append(contentsOf: string.utf8) }
    func word<T: FixedWidthInteger>(_ value: T) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { result.append(contentsOf: $0) }
    }
    text("RIFF")
    word(dataSize + 36)
    text("WAVEfmt ")
    word(UInt32(16))
    word(UInt16(1))
    word(channelCount)
    word(UInt32(sampleRate))
    word(UInt32(sampleRate) * UInt32(channelCount) * 2)
    word(channelCount * 2)
    word(UInt16(16))
    text("data")
    word(dataSize)
    for frame in frames {
      for channel in channels {
        let sample = max(-1, min(1, channel[frame]))
        word(Int16((sample * 32767).rounded()))
      }
    }
    return result
  }
}

public struct Project: Codable, Sendable {
  public var version: Int = 1
  public var audio: AudioDocument
  public var selectionStart: Double
  public var selectionEnd: Double

  public init(audio: AudioDocument, selectionStart: Double = 0, selectionEnd: Double = 0) {
    self.audio = audio
    self.selectionStart = selectionStart
    self.selectionEnd = selectionEnd
  }

  public func save(to url: URL) throws {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    try encoder.encode(self).write(to: url, options: .atomic)
  }

  public static func load(from url: URL) throws -> Project {
    let result = try PropertyListDecoder().decode(Project.self, from: Data(contentsOf: url))
    guard result.version == 1, result.selectionStart.isFinite, result.selectionEnd.isFinite,
      result.selectionStart >= 0, result.selectionEnd >= result.selectionStart,
      result.selectionEnd <= result.audio.duration
    else { throw AudioError.invalidAudio }
    _ = try result.audio.validated()
    return result
  }
}
