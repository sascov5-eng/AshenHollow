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
                .onAppear {
                    PlayerSpriteInstaller.installWhenReady(in: scene)
                }

            Text("VERSION 0.4 • SPRITE TEST")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.85))
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }
}
