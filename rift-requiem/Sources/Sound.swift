import AVFoundation
import Combine

@MainActor
final class Sound: ObservableObject {
    static let shared = Sound()
    @Published var muted = false {
        didSet { music?.volume = muted ? 0 : 0.22 }
    }
    private var music: AVAudioPlayer?
    private var voices: [AVAudioPlayer] = []

    func start() {
        guard music == nil else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let url = Bundle.main.url(forResource: "cathedral-riff", withExtension: "wav") else { return }
        music = try? AVAudioPlayer(contentsOf: url)
        music?.numberOfLoops = -1
        music?.volume = muted ? 0 : 0.22
        music?.play()
    }

    func play(_ name: String) {
        guard !muted, let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        voices.removeAll { !$0.isPlaying }
        voices.append(player)
        player.volume = 0.65
        player.play()
    }
}
