import SwiftUI
import SpriteKit

struct GameView: View {
    let launchMode: DemoLaunchMode

    @State private var scene: GameScene

    init(launchMode: DemoLaunchMode) {
        self.launchMode = launchMode

        let gameScene = GameScene(
            size: CGSize(width: 844, height: 390)
        )
        gameScene.scaleMode = .resizeFill
        _scene = State(initialValue: gameScene)
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()
            .background(Color.black)

            Text("V24 BUILD TEST")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.85))
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
        .onAppear {
            installRuntimeWhenReady()
        }
    }

    private func installRuntimeWhenReady(attemptsRemaining: Int = 20) {
        guard V21RuntimeBootstrap.context(from: scene) == nil else {
            return
        }

        guard scene.childNode(withName: "player") != nil else {
            guard attemptsRemaining > 0 else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                installRuntimeWhenReady(attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        V21RuntimeBootstrap.install(on: scene, launchMode: launchMode)
    }
}
