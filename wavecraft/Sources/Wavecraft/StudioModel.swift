import AVFoundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WavecraftCore

struct PeakBin {
  let low: Float
  let high: Float
}

struct Revision {
  let project: Project
  let label: String
}

enum PlaybackError: LocalizedError {
  case outputUnavailable

  var errorDescription: String? {
    "The audio output could not start. Choose an available output in System Settings → Sound, then try again."
  }
}

@MainActor
final class StudioModel: ObservableObject {
  @Published var project: Project
  @Published var bins: [[PeakBin]] = []
  @Published var peak: Float = 0
  @Published var rms: Double = 0
  @Published var clipped = 0
  @Published var playhead = 0.0
  @Published var playing = false
  @Published var zoom = 1.0
  @Published var gainDB = 3.0
  @Published var notice = "Ready to shape something."
  @Published var error: String?
  @Published var undoStack: [Revision] = []
  @Published var redoStack: [Revision] = []
  @Published var history = ["Session opened"]
  @Published var lastExport: URL?
  private var player: AVAudioPlayer?
  private var playbackOffset = 0.0
  private let projectURL: URL

  var audio: AudioDocument { project.audio }
  var start: Double { project.selectionStart }
  var end: Double { project.selectionEnd }
  var hasSelection: Bool { end - start >= 1 / audio.sampleRate }
  var selectionDuration: Double { max(0, end - start) }

  init() {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ]
    .appendingPathComponent("Wavecraft", isDirectory: true)
    projectURL = support.appendingPathComponent("Session.wavecraft")
    project = Project(audio: SampleKind.tide.generate())
    do {
      try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: projectURL.path) {
        project = try Project.load(from: projectURL)
        notice = "Your last session, restored."
      }
    } catch {
      self.error = "Couldn't restore the session: \(error.localizedDescription)"
    }
    refreshAnalysis()
  }

  func refreshAnalysis() {
    peak = audio.peak
    rms = audio.rms
    clipped = audio.clippedCount
    let stride = max(1, audio.frameCount / 4096)
    bins = audio.channels.map { channel in
      Swift.stride(from: 0, to: channel.count, by: stride).map { lower in
        let samples = channel[lower..<min(lower + stride, channel.count)]
        return PeakBin(low: samples.min() ?? 0, high: samples.max() ?? 0)
      }
    }
  }

  func persist() {
    do { try project.save(to: projectURL) } catch {
      self.error = "Couldn't save the session: \(error.localizedDescription)"
    }
  }

  func select(_ start: Double, _ end: Double, save: Bool = true) {
    project.selectionStart = max(0, min(audio.duration, min(start, end)))
    project.selectionEnd = max(0, min(audio.duration, max(start, end)))
    if save { persist() }
  }

  func selectAll() { select(0, audio.duration) }

  func seek(_ time: Double) {
    stop()
    playhead = max(0, min(audio.duration, time))
  }

  func setSelection(startText: String, endText: String) {
    guard let start = Double(startText), let end = Double(endText),
      start.isFinite, end.isFinite, start >= 0, end > start, end <= audio.duration
    else {
      error =
        "Enter a start and end between 0 and \(String(format: "%.3f", audio.duration)) seconds. The end must follow the start."
      return
    }
    select(start, end)
    notice = "Precise range selected."
  }

  func edit(_ label: String, operation: (inout AudioDocument, Range<Int>) throws -> Void) {
    stop()
    do {
      let range = try audio.frameRange(start: start, end: end)
      var updated = audio
      try operation(&updated, range)
      checkpoint(label)
      project.audio = updated
      if label == "Trim to selection" {
        select(0, updated.duration, save: false)
        playhead = 0
        zoom = 1
      }
      finish(label)
    } catch { self.error = error.localizedDescription }
  }

  func trim() { edit("Trim to selection") { try $0.trim(to: $1) } }
  func fadeIn() { edit("Fade in") { try $0.fade($1, fadeIn: true) } }
  func fadeOut() { edit("Fade out") { try $0.fade($1, fadeIn: false) } }
  func applyGain() {
    let db = gainDB
    edit(String(format: "Gain %+.1f dB", db)) { try $0.gain($1, decibels: db) }
  }

  private func checkpoint(_ label: String) {
    undoStack.append(Revision(project: project, label: label))
    if undoStack.count > 20 { undoStack.removeFirst() }
    redoStack.removeAll()
  }

  private func finish(_ label: String) {
    history.append(label)
    if history.count > 6 { history.removeFirst() }
    notice = label + " · saved"
    refreshAnalysis()
    persist()
  }

  func undo() {
    guard let previous = undoStack.popLast() else { return }
    stop()
    redoStack.append(Revision(project: project, label: previous.label))
    project = previous.project
    playhead = min(playhead, audio.duration)
    finish("Undo · " + previous.label)
  }

  func redo() {
    guard let next = redoStack.popLast() else { return }
    stop()
    undoStack.append(Revision(project: project, label: next.label))
    project = next.project
    playhead = min(playhead, audio.duration)
    finish("Redo · " + next.label)
  }

  func loadSample(_ kind: SampleKind) {
    stop()
    checkpoint("Load " + kind.rawValue)
    project = Project(audio: kind.generate())
    playhead = 0
    zoom = 1
    finish("Loaded " + kind.rawValue)
  }

  func togglePlayback(selection: Bool = false) {
    if playing {
      stop()
      return
    }
    do {
      let from = selection && hasSelection ? start : (playhead >= audio.duration ? 0 : playhead)
      let to = selection && hasSelection ? end : audio.duration
      let range = try audio.frameRange(start: from, end: to)
      player = try AVAudioPlayer(data: audio.wavData(range: range))
      playbackOffset = Double(range.lowerBound) / audio.sampleRate
      guard player?.prepareToPlay() == true, player?.play() == true else {
        throw PlaybackError.outputUnavailable
      }
      playing = true
      notice = selection && hasSelection ? "Auditioning selection" : "Playing"
    } catch { self.error = "Playback failed: \(error.localizedDescription)" }
  }

  func stop() {
    if let player, playing { playhead = playbackOffset + player.currentTime }
    player?.stop()
    playing = false
  }

  func tick() {
    guard playing, let player else { return }
    if player.isPlaying {
      playhead = playbackOffset + player.currentTime
    } else {
      playhead = min(audio.duration, playbackOffset + player.duration)
      playing = false
      notice = "Playback complete"
    }
  }

  func importAudio() {
    guard let window = NSApp.keyWindow else { return }
    stop()
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.wav, .aiff]
    panel.allowsMultipleSelection = false
    panel.message = "Open mono or stereo WAV / AIFF · up to 120 seconds"
    panel.beginSheetModal(for: window) { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      self?.loadAudio(from: url)
    }
  }

  private func loadAudio(from url: URL) {
    do {
      let file = try AVAudioFile(
        forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
      let format = file.processingFormat
      guard (1...2).contains(format.channelCount), file.length > 0,
        Double(file.length) / format.sampleRate <= 120, format.sampleRate <= 192_000
      else { throw AudioError.unsupported }
      guard
        let buffer = AVAudioPCMBuffer(
          pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))
      else {
        throw AudioError.invalidAudio
      }
      try file.read(into: buffer)
      guard let samples = buffer.floatChannelData else { throw AudioError.invalidAudio }
      let channels = (0..<Int(format.channelCount)).map {
        Array(UnsafeBufferPointer(start: samples[$0], count: Int(buffer.frameLength)))
      }
      let imported = try AudioDocument(
        name: url.deletingPathExtension().lastPathComponent,
        sampleRate: format.sampleRate, channels: channels)
      stop()
      checkpoint("Import audio")
      project = Project(audio: imported)
      playhead = 0
      zoom = 1
      finish("Imported " + imported.name)
    } catch { self.error = "Couldn't open audio: \(error.localizedDescription)" }
  }

  func exportAudio() {
    guard let window = NSApp.keyWindow else { return }
    stop()
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.wav]
    panel.nameFieldStringValue = audio.name + " — edited.wav"
    panel.message = "Export full edited audio · 16-bit PCM WAV · \(Int(audio.sampleRate)) Hz"
    panel.beginSheetModal(for: window) { [weak self] response in
      guard let self, response == .OK, let url = panel.url else { return }
      do {
        try audio.wavData().write(to: url, options: .atomic)
        lastExport = url
        notice = "Exported \(url.lastPathComponent)"
      } catch { self.error = "Couldn't export: \(error.localizedDescription)" }
    }
  }
}
