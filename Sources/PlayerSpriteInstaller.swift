import SpriteKit
import UIKit

@MainActor
enum PlayerSpriteInstaller {
    private static let spriteName = "player_run"
    private static let markerName = "playerSpriteV03"

    static func installWhenReady(in scene: SKScene, attempt: Int = 0) {
        if install(in: scene) { return }
        guard attempt < 20 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            installWhenReady(in: scene, attempt: attempt + 1)
        }
    }

    @discardableResult
    static func install(in scene: SKScene) -> Bool {
        if scene.childNode(withName: "//\(markerName)") != nil { return true }
        guard let player = findPlayerNode(in: scene) else { return false }

        guard let imageURL = Bundle.main.url(forResource: spriteName, withExtension: "png"),
              let image = UIImage(contentsOfFile: imageURL.path),
              let cgImage = image.cgImage else {
            return false
        }

        let sheet = SKTexture(cgImage: cgImage)
        sheet.filteringMode = .linear
        let frames = makeFrames(from: sheet)
        guard frames.count == 8 else { return false }

        player.fillColor = .clear
        player.strokeColor = .clear

        let visualHost: SKNode
        if let existing = player.children.first {
            visualHost = existing
            for child in existing.children {
                child.isHidden = true
            }
        } else {
            visualHost = player
        }

        let sprite = SKSpriteNode(texture: frames[0])
        sprite.name = markerName
        sprite.size = CGSize(width: 92, height: 92)
        sprite.position = CGPoint(x: 0, y: 10)
        sprite.zPosition = 10
        sprite.isHidden = false
        visualHost.addChild(sprite)

        var lastX = player.position.x
        var frameAccumulator: CGFloat = 0
        var frameIndex = 0

        sprite.run(
            SKAction.customAction(withDuration: 60 * 60 * 24) { node, elapsed in
                guard let sprite = node as? SKSpriteNode else { return }

                let dx = player.position.x - lastX
                lastX = player.position.x

                if abs(dx) > 0.08 {
                    sprite.xScale = dx >= 0 ? 1 : -1
                    let current = CGFloat(elapsed)
                    if current - frameAccumulator >= 0.085 {
                        frameAccumulator = current
                        frameIndex = (frameIndex + 1) % frames.count
                        sprite.texture = frames[frameIndex]
                    }
                } else {
                    frameIndex = 0
                    sprite.texture = frames[0]
                }
            },
            withKey: "playerSpriteAnimationV03"
        )

        return true
    }

    private static func findPlayerNode(in scene: SKScene) -> SKShapeNode? {
        var stack = scene.children
        while let node = stack.popLast() {
            if let shape = node as? SKShapeNode,
               shape.zPosition >= 49,
               shape.zPosition <= 51,
               shape.frame.width >= 35,
               shape.frame.width <= 55,
               shape.frame.height >= 55,
               shape.frame.height <= 75 {
                return shape
            }
            stack.append(contentsOf: node.children)
        }
        return nil
    }

    private static func makeFrames(from sheet: SKTexture) -> [SKTexture] {
        var frames: [SKTexture] = []
        for row in 0..<2 {
            for column in 0..<4 {
                let rect = CGRect(
                    x: CGFloat(column) * 0.25,
                    y: row == 0 ? 0.5 : 0,
                    width: 0.25,
                    height: 0.5
                )
                let texture = SKTexture(rect: rect, in: sheet)
                texture.filteringMode = .linear
                frames.append(texture)
            }
        }
        return frames
    }
}
