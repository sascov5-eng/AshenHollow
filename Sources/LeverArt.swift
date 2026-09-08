import Foundation
import SpriteKit
import UIKit

enum LeverArt {
    static func node(active: Bool = false) -> SKNode {
        let root = SKNode()
        let textureName = active ? "luma_lever_on.png" : "luma_lever_off.png"
        if let texture = EnvArt.texture(textureName) {
            let sprite = SKSpriteNode(texture: texture)
            sprite.name = "lumaLever"
            sprite.size = CGSize(width: 74, height: 92)
            sprite.position = CGPoint(x: 0, y: 9)
            sprite.zPosition = 4
            root.addChild(sprite)
        } else {
            let fallback = SKShapeNode(rectOf: CGSize(width: 38, height: 62), cornerRadius: 8)
            fallback.fillColor = UIColor(red: 0.72, green: 0.50, blue: 0.22, alpha: 1)
            fallback.strokeColor = UIColor(red: 0.95, green: 0.76, blue: 0.40, alpha: 1)
            fallback.lineWidth = 2
            root.addChild(fallback)
        }
        return root
    }

    static func setActive(_ active: Bool, on root: SKNode) {
        guard let sprite = root.childNode(withName: "lumaLever") as? SKSpriteNode else { return }
        if let texture = EnvArt.texture(active ? "luma_lever_on.png" : "luma_lever_off.png") {
            sprite.texture = texture
        }
    }
}
