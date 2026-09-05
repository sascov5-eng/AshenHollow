import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .background(Color.black)

            Text("v1.1 • PLAYER SCALE • 480PX VISUAL")
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.88))
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }
}
