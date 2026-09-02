import SwiftUI
import SpriteKit
import UIKit

struct GameView: UIViewRepresentable {
    let launchMode: DemoLaunchMode

    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)
        skView.backgroundColor = .black
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = false
        skView.isMultipleTouchEnabled = true
        skView.preferredFramesPerSecond = 60

        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        return skView
    }

    func updateUIView(_ skView: SKView, context: Context) {
        guard skView.scene == nil else { return }

        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }
}
