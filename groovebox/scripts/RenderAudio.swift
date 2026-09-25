import Foundation

@main
struct RenderAudio {
  static func main() throws {
    let folder = URL(
      fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/audio")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let pattern = Pattern.presets[0]
    let samples = WaveExport.samples(pattern: pattern)
    try WaveExport.wav(samples).write(
      to: folder.appendingPathComponent("Midnight-circuit-112bpm.wav"))
    for drum in Drum.allCases {
      try WaveExport.wav(DrumSynth.voice(drum)).write(
        to: folder.appendingPathComponent("\(drum.name).wav"))
    }
    let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
    print("Rendered 2 bars at \(Int(pattern.bpm)) BPM + 0.55 s tail")
    print("Frames: \(samples.count); seconds: \(Double(samples.count) / 48_000)")
    print("Peak: \(samples.map(abs).max()!); RMS: \(rms)")
    guard rms > 0.01 else { throw CocoaError(.fileWriteUnknown) }
  }
}
