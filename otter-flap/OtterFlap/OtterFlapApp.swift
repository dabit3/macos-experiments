import SwiftUI
import SpriteKit

@main
struct OtterFlapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBarHidden()
        }
    }
}

struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: GameScene(size: proxy.size))
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
