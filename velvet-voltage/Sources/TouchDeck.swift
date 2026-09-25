import SwiftUI
import UIKit

/// Full-table multitouch surface: the left half drives the left flipper, the right half the
/// right flipper, and while the ball is waiting a downward drag pulls the plunger.
struct TouchDeck: UIViewRepresentable {
  @ObservedObject var game: GameSession

  func makeUIView(context: Context) -> DeckView {
    let view = DeckView()
    view.game = game
    return view
  }

  func updateUIView(_ view: DeckView, context: Context) {
    view.game = game
    if game.paused || game.screen != .playing { view.releaseAll() }
  }

  final class DeckView: UIView {
    weak var game: GameSession?
    private var sides: [UITouch: Bool] = [:]
    private var plungerTouch: UITouch?
    private var plungerOrigin = CGPoint.zero

    override init(frame: CGRect) {
      super.init(frame: frame)
      isMultipleTouchEnabled = true
      backgroundColor = .clear
      isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let game, game.screen == .playing, !game.paused else { return }
      for touch in touches {
        let point = touch.location(in: self)
        if !game.inFlight, plungerTouch == nil {
          plungerTouch = touch
          plungerOrigin = point
          continue
        }
        let left = point.x < bounds.midX
        sides[touch] = left
        game.setFlipper(left: left, pressed: true)
      }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let game, let plungerTouch, touches.contains(plungerTouch) else { return }
      let travel = plungerTouch.location(in: self).y - plungerOrigin.y
      game.pullPlunger(travel / 140)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
      for touch in touches {
        if touch == plungerTouch {
          plungerTouch = nil
          if let game, !game.inFlight {
            let travel = touch.location(in: self).y - plungerOrigin.y
            game.launch(power: travel < 12 ? 1 : min(1, travel / 140))
          }
        } else if let left = sides.removeValue(forKey: touch) {
          game?.setFlipper(left: left, pressed: false)
        }
      }
    }

    func releaseAll() {
      for left in Set(sides.values) { game?.setFlipper(left: left, pressed: false) }
      sides.removeAll()
      plungerTouch = nil
    }
  }
}
