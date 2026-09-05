import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        return scene
    }()

    @State private var diagnostic = "CHECKING"

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .background(Color.black)

            Text("v0.5 • SPRITE RESOURCE DIAGNOSTIC • \(diagnostic)")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundColor(diagnostic.contains("FAIL") || diagnostic.contains("MISSING") ? .red : .yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.88))
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
        .onAppear {
            diagnostic = SpriteResourceDiagnostic.status()
        }
    }
}
