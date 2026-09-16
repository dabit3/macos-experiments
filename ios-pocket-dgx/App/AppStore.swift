import Combine
import SwiftUI
import UIKit

enum Screen: Equatable {
  case title
  case rig
}

/// App-level state: which screen is up, persisted stats and the live scene.
final class AppStore: ObservableObject {
  @Published var screen: Screen = .title
  @Published var stats: RigStats
  @Published var kind: RigKind
  @Published var scene: RigScene?
  @Published var sharing: UIImage?
  @Published var caption = Lore.caption(seed: Int(Date().timeIntervalSince1970))
  @Published var toast: String?

  let audio = SynthAudio()
  private var pendingTokens: Double = 0
  private var toastTask: Task<Void, Never>?
  private static let key = "pocketdgx.stats"

  init() {
    let saved =
      UserDefaults.standard.data(forKey: Self.key).flatMap {
        try? JSONDecoder().decode(RigStats.self, from: $0)
      }
      ?? RigStats()
    stats = saved
    kind = saved.lastKind
    audio.enabled = saved.sound
  }

  var sound: Bool {
    get { stats.sound }
    set {
      stats.sound = newValue
      audio.enabled = newValue
      if newValue { audio.tick() }
      save()
    }
  }

  func enter(_ kind: RigKind) {
    self.kind = kind
    stats.lastKind = kind
    let scene = RigScene(kind: kind, scale: 1, audio: audio)
    scene.onPowerToggle = { [weak self] phase in
      guard let self else { return }
      if phase == .booting {
        self.stats.powerOns += 1
        self.save()
      }
    }
    scene.onScaleChanged = { [weak self] scale in
      guard let self else { return }
      if scale > self.stats.largestScale {
        self.stats.largestScale = scale
      }
    }
    scene.onSimulation = { [weak self] simulation in
      guard let self else { return }
      self.stats.record(simulation)
      let delta = simulation.totalTokens - self.pendingTokens
      if delta > 0 { self.stats.totalTokens += delta }
      self.pendingTokens = simulation.totalTokens
    }
    pendingTokens = 0
    self.scene = scene
    audio.tick()
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { screen = .rig }
    save()
  }

  func leave() {
    scene?.pause()
    audio.setFan(0)
    save()
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { screen = .title }
    scene = nil
    caption = Lore.caption(seed: Int(Date().timeIntervalSince1970))
  }

  func swap() {
    let next: RigKind = kind == .rack ? .card : .rack
    kind = next
    stats.lastKind = next
    scene?.swapKind(next)
    pendingTokens = 0
    save()
    show(next.title.uppercased())
  }

  func photo() {
    scene?.snapshot { [weak self] image in
      guard let self, let image else {
        self?.show("Snapshot failed")
        return
      }
      self.stats.photos += 1
      self.save()
      self.sharing = Watermark.apply(to: image, caption: self.caption)
    }
  }

  func show(_ text: String) {
    toastTask?.cancel()
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = text }
    toastTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 1_600_000_000)
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.3)) { toast = nil }
    }
  }

  func save() {
    if let data = try? JSONEncoder().encode(stats) {
      UserDefaults.standard.set(data, forKey: Self.key)
    }
  }
}

/// Stamps a subtle caption and signature strip onto shared photos.
enum Watermark {
  static func apply(to image: UIImage, caption: String) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: image.size)
    return renderer.image { context in
      image.draw(at: .zero)
      let width = image.size.width
      let height = image.size.height
      let barHeight = height * 0.07
      let rect = CGRect(x: 0, y: height - barHeight, width: width, height: barHeight)
      context.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
      context.cgContext.fill(rect)
      context.cgContext.setFillColor(ProceduralTextures.green.cgColor)
      context.cgContext.fill(CGRect(x: 0, y: height - barHeight, width: width, height: 3))
      let title = "POCKET DGX" as NSString
      let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: barHeight * 0.38, weight: .heavy),
        .foregroundColor: ProceduralTextures.green,
        .kern: barHeight * 0.05,
      ]
      title.draw(
        at: CGPoint(x: width * 0.04, y: height - barHeight * 0.72), withAttributes: titleAttributes)
      let captionAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: barHeight * 0.26, weight: .medium),
        .foregroundColor: UIColor(white: 0.9, alpha: 1),
      ]
      let captionSize = (caption as NSString).size(withAttributes: captionAttributes)
      (caption as NSString).draw(
        at: CGPoint(
          x: width * 0.96 - captionSize.width, y: height - barHeight * 0.5 - captionSize.height / 2),
        withAttributes: captionAttributes)
    }
  }
}
