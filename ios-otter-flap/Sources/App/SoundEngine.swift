import AVFoundation
import UIKit

enum Sound {
    case flap, score, crash, splash
}

/// Tiny synthesizer: every effect is generated on the fly, no audio assets.
@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
    private var ready = false
    var enabled = true

    func play(_ sound: Sound) {
        haptic(sound)
        guard enabled, let format, start() else { return }
        let duration = switch sound {
        case .flap: 0.09
        case .score: 0.22
        case .crash: 0.2
        case .splash: 0.35
        }
        let frames = AVAudioFrameCount(44100 * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData else { return }
        buffer.frameLength = frames
        var noise: UInt32 = 22222
        for i in 0 ..< Int(frames) {
            let t = Double(i) / 44100
            let progress = Double(i) / Double(frames)
            let value: Double
            switch sound {
            case .flap:
                let f = 380 + 520 * progress
                value = sin(2 * .pi * f * t) * (1 - progress) * 0.14
            case .score:
                let f = progress < 0.4 ? 988.0 : 1318.5
                value = sin(2 * .pi * f * t) * exp(-t * 9) * 0.13
            case .crash:
                value = sin(2 * .pi * (140 - 80 * progress) * t) * (1 - progress) * 0.25
            case .splash:
                noise = noise &* 1_664_525 &+ 1_013_904_223
                let white = Double(noise >> 8) / Double(1 << 24) * 2 - 1
                value = white * sin(.pi * progress) * exp(-t * 6) * 0.12
            }
            samples[0][i] = Float(value)
        }
        player.scheduleBuffer(buffer)
    }

    private func start() -> Bool {
        if !ready {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                ready = true
            } catch { return false }
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        if !player.isPlaying {
            player.play()
        }
        return true
    }

    private func haptic(_ sound: Sound) {
        switch sound {
        case .flap: UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        case .score: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
        case .crash: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .splash: break
        }
    }
}
