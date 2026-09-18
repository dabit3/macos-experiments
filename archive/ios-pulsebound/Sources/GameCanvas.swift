import SpriteKit
import SwiftUI

struct GameCanvas: UIViewRepresentable {
  let scene: GameScene

  func makeUIView(context: Context) -> PulseSceneView {
    let view = PulseSceneView()
    view.backgroundColor = scene.backgroundColor
    view.preferredFramesPerSecond = 60
    view.accessibilityLabel = "Game field"
    view.accessibilityIdentifier = "game.field"
    let cover = UIView()
    cover.backgroundColor = scene.backgroundColor
    cover.isUserInteractionEnabled = false
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.frame = view.bounds
    view.addSubview(cover)
    scene.onFirstFrame = { [weak cover] in cover?.removeFromSuperview() }
    view.presentScene(scene)
    return view
  }

  func updateUIView(_ view: PulseSceneView, context: Context) {}
}

final class PulseSceneView: SKView {
  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.width > 0, bounds.height > 0 else { return }
    scene?.size = CGSize(width: 760, height: 760 * bounds.height / bounds.width)
  }
}
