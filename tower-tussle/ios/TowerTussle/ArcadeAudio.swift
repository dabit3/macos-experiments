import AVFoundation
import UIKit

enum ArcadeAudio {
    enum Cue: String, CaseIterable { case tap, deploy, victory, defeat }

    private static let players: [Cue: AVAudioPlayer] = {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        return Dictionary(uniqueKeysWithValues: Cue.allCases.compactMap { cue in
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.prepareToPlay()
            return (cue, player)
        })
    }()

    static var enabled = true

    static func play(_ cue: Cue) {
        if enabled {
            let player = players[cue]
            player?.currentTime = 0
            player?.play()
        }
        if cue == .tap { UISelectionFeedbackGenerator().selectionChanged() }
        if cue == .deploy { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
}
