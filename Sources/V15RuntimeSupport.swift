import Foundation
import CoreGraphics
import SpriteKit
import UIKit

final class EnemyHealthBarNode: SKNode {
    private let width: CGFloat = 58
    private let fill = SKSpriteNode(color: .systemRed, size: CGSize(width: 58, height: 6))

    override init() {
        super.init()
        let bg = SKShapeNode(rectOf: CGSize(width: 62, height: 10), cornerRadius: 3)
        bg.fillColor = UIColor(white: 0.03, alpha: 0.9)
        bg.strokeColor = UIColor(white: 1, alpha: 0.75)
        bg.lineWidth = 1
        addChild(bg)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -width * 0.5, y: 0)
        fill.zPosition = 1
        addChild(fill)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateHealthBar(current: Int, max: Int) {
        let ratio = max > 0 ? CGFloat(Swift.max(0, Swift.min(current, max))) / CGFloat(max) : 0
        fill.xScale = ratio
        isHidden = current <= 0
    }
}

enum MovingPlatformRideSupport {
    static func isRiding(playerFrame: CGRect, platformFrame: CGRect, grounded: Bool, tolerance: CGFloat = 8) -> Bool {
        guard grounded else { return false }
        let overlapsX = playerFrame.maxX > platformFrame.minX + 2 && playerFrame.minX < platformFrame.maxX - 2
        let feetNearTop = abs(playerFrame.minY - platformFrame.maxY) <= tolerance
        return overlapsX && feetNearTop
    }

    static func applyPlatformDelta(_ delta: CGVector, to position: CGPoint) -> CGPoint {
        CGPoint(x: position.x + delta.dx, y: position.y + delta.dy)
    }
}

enum PixelCaveArt {
    private static let root = "PixelCave"

    static func texture(_ relativePath: String) -> SKTexture? {
        let url = Bundle.main.bundleURL.appendingPathComponent(root).appendingPathComponent(relativePath)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    static func sprite(_ relativePath: String, size: CGSize, z: CGFloat = 0) -> SKSpriteNode? {
        guard let texture = texture(relativePath) else { return nil }
        let node = SKSpriteNode(texture: texture)
        node.size = size
        node.zPosition = z
        return node
    }

    static func addParallax(to scene: SKScene, worldBounds: CGRect) {
        let layers: [(String, CGFloat, CGFloat)] = [
            ("Example stage layers/bg_01_sky.png", -118, 1.0),
            ("Example stage layers/bg_02_mountains.png", -112, 0.95),
            ("Example stage layers/bg_04_dungeon_b.png", -105, 0.9),
            ("Example stage layers/bg_05_cave_b.png", -98, 0.82),
            ("Example stage layers/bg_06_caveinside_b.png", -90, 0.76),
            ("Example stage layers/bg_07_bgobjects.png", -82, 0.68)
        ]
        let tileHeight: CGFloat = 1550
        let tileWidth = tileHeight * 704.0 / 544.0
        for (path, z, alpha) in layers {
            guard let texture = texture(path) else { continue }
            var x = worldBounds.minX + tileWidth * 0.5
            while x < worldBounds.maxX + tileWidth {
                let node = SKSpriteNode(texture: texture)
                node.size = CGSize(width: tileWidth, height: tileHeight)
                node.position = CGPoint(x: x, y: 790)
                node.zPosition = z
                node.alpha = alpha
                scene.addChild(node)
                x += tileWidth - 2
            }
        }
    }

    static func terrainNode(rect: CGRect) -> SKNode {
        let root = SKNode()
        root.position = CGPoint(x: rect.midX, y: rect.midY)
        let fill = SKShapeNode(rectOf: rect.size)
        fill.fillColor = UIColor(red: 0.075, green: 0.065, blue: 0.085, alpha: 1)
        fill.strokeColor = .clear
        root.addChild(fill)

        let topPath = "Individual PNG files/Tileset/cave_tileset/main_tiles_16x16_32.png"
        let sidePath = "Individual PNG files/Tileset/cave_tileset/main_tiles_16x16_38.png"
        let unit: CGFloat = 48
        if let topTexture = texture(topPath) {
            let count = Swift.max(1, Int(ceil(rect.width / unit)))
            for i in 0..<count {
                let node = SKSpriteNode(texture: topTexture)
                node.size = CGSize(width: unit, height: unit)
                node.position = CGPoint(x: -rect.width * 0.5 + unit * (CGFloat(i) + 0.5), y: rect.height * 0.5 - unit * 0.5)
                node.zPosition = 2
                root.addChild(node)
            }
        }
        if rect.height > 100, let sideTexture = texture(sidePath) {
            let count = Swift.max(1, Int(ceil(rect.height / unit)))
            for i in 0..<count {
                for x in [-rect.width * 0.5 + unit * 0.5, rect.width * 0.5 - unit * 0.5] {
                    let node = SKSpriteNode(texture: sideTexture)
                    node.size = CGSize(width: unit, height: unit)
                    node.position = CGPoint(x: x, y: -rect.height * 0.5 + unit * (CGFloat(i) + 0.5))
                    node.zPosition = 1
                    root.addChild(node)
                }
            }
        }
        return root
    }

    static func spikeNode(rect: CGRect) -> SKNode {
        let root = SKNode()
        root.position = CGPoint(x: rect.midX, y: rect.midY)
        let unit: CGFloat = 46
        let path = "Individual PNG files/Tileset/object_misc/objects_misc_16.png"
        if let texture = texture(path) {
            let count = Swift.max(1, Int(ceil(rect.width / unit)))
            for i in 0..<count {
                let node = SKSpriteNode(texture: texture)
                node.size = CGSize(width: unit, height: Swift.max(40, rect.height + 16))
                node.position = CGPoint(x: -rect.width * 0.5 + unit * (CGFloat(i) + 0.5), y: 4)
                node.zPosition = 12
                root.addChild(node)
            }
        }
        return root
    }

    static func checkpointNode(active: Bool) -> SKNode {
        let root = SKNode()
        if let sprite = sprite("Individual PNG files/Tileset/object_misc/objects_misc_9.png", size: CGSize(width: 72, height: 64), z: 2) {
            root.addChild(sprite)
        }
        let glow = SKShapeNode(circleOfRadius: 34)
        glow.fillColor = UIColor.cyan.withAlphaComponent(active ? 0.28 : 0.08)
        glow.strokeColor = UIColor.cyan.withAlphaComponent(active ? 0.95 : 0.35)
        glow.lineWidth = 2
        glow.zPosition = 1
        root.addChild(glow)
        root.alpha = active ? 1 : 0.65
        return root
    }

    static func movingPlatformNode(size: CGSize, horizontal: Bool) -> SKNode {
        let root = SKNode()
        let body = terrainNode(rect: CGRect(x: -size.width * 0.5, y: -size.height * 0.5, width: size.width, height: Swift.max(size.height, 42)))
        body.position = .zero
        root.addChild(body)
        let arrow = SKLabelNode(fontNamed: "AvenirNext-Bold")
        arrow.text = horizontal ? "\u2194" : "\u2195"
        arrow.fontSize = 22
        arrow.fontColor = .white
        arrow.position = CGPoint(x: 0, y: 18)
        arrow.zPosition = 8
        root.addChild(arrow)
        return root
    }

    static func interactionNode(kind: InteractionKind, rect: CGRect) -> SKNode {
        let root = SKNode()
        switch kind {
        case .lever, .shortcutLever:
            root.addChild(LeverArt.node())
        case .door, .shortcutDoor:
            if let texture = texture("Individual PNG files/Tileset/object_misc/objects_misc_0.png") {
                let rows = Swift.max(2, Int(ceil(rect.height / 48)))
                for i in 0..<rows {
                    let sprite = SKSpriteNode(texture: texture)
                    sprite.size = CGSize(width: Swift.max(60, rect.width + 20), height: 48)
                    sprite.position = CGPoint(x: 0, y: -rect.height * 0.5 + 24 + CGFloat(i) * 48)
                    root.addChild(sprite)
                }
            }
        case .breakableWall:
            let body = terrainNode(rect: CGRect(x: -rect.width * 0.5, y: -rect.height * 0.5, width: rect.width, height: rect.height))
            root.addChild(body)
            let crack = SKShapeNode(path: {
                let p = CGMutablePath(); p.move(to: CGPoint(x: -8, y: 65)); p.addLine(to: CGPoint(x: 7, y: 25)); p.addLine(to: CGPoint(x: -4, y: 2)); p.addLine(to: CGPoint(x: 12, y: -32)); p.addLine(to: CGPoint(x: -6, y: -68)); return p
            }())
            crack.strokeColor = .white; crack.lineWidth = 3; crack.zPosition = 8; root.addChild(crack)
        case .hiddenPassage:
            let outline = SKShapeNode(rectOf: rect.size, cornerRadius: 8)
            outline.strokeColor = UIColor.cyan.withAlphaComponent(0.7)
            outline.fillColor = UIColor.cyan.withAlphaComponent(0.05)
            outline.lineWidth = 2
            root.addChild(outline)
        }
        return root
    }

    static func enemyNode(kind: EnemyTestKind) -> SKNode {
        let root = SKNode()
        let color: String
        let title: String
        switch kind {
        case .groundPatrol: color = "brown"; title = "\u041f\u0410\u0422\u0420\u0423\u041b\u042c\u041d\u042b\u0419"
        case .flying: color = "violet"; title = "\u041b\u0415\u0422\u0410\u042e\u0429\u0418\u0419"
        case .aggressive: color = "red"; title = "\u0410\u0413\u0420\u0415\u0421\u0421\u0418\u0412\u041d\u042b\u0419"
        }
        var frames: [SKTexture] = []
        for i in 0..<5 {
            if let t = texture("Individual PNG files/Monster/scorpion-\(color)/scorpion-\(color)-\(i).png") { frames.append(t) }
        }
        if let first = frames.first {
            let sprite = SKSpriteNode(texture: first)
            sprite.size = CGSize(width: kind == .flying ? 74 : 78, height: kind == .flying ? 74 : 78)
            sprite.zPosition = 2
            root.addChild(sprite)
            if frames.count > 1 { sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12))) }
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = title
        label.fontSize = 11
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 52)
        label.zPosition = 5
        root.addChild(label)
        return root
    }

    static func exitNode() -> SKNode {
        let root = SKNode()
        if let sprite = sprite("Individual PNG files/Tileset/object_misc/objects_misc_7.png", size: CGSize(width: 90, height: 72), z: 2) { root.addChild(sprite) }
        let ring = SKShapeNode(circleOfRadius: 48)
        ring.strokeColor = .systemCyan
        ring.lineWidth = 4
        ring.glowWidth = 6
        ring.zPosition = 1
        root.addChild(ring)
        return root
    }
}
