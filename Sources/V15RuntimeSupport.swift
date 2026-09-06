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

enum EnvArt {
    private static var cache: [String: SKTexture] = [:]
    private static let lightMask: UInt32 = 1

    static func texture(_ name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        let url = Bundle.main.bundleURL.appendingPathComponent("EnvArt").appendingPathComponent(name)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }

    static func lit(_ node: SKSpriteNode, castsShadow: Bool = true) {
        node.lightingBitMask = lightMask
        node.shadowedBitMask = lightMask
        if castsShadow { node.shadowCastBitMask = lightMask }
    }

    static func span(_ parent: SKNode, texture: SKTexture, size: CGSize, z: CGFloat, maxPiece: CGFloat, castsShadow: Bool) {
        let pieces = max(1, Int(ceil(size.width / max(120, maxPiece))))
        let pw = size.width / CGFloat(pieces)
        let originX = -size.width * 0.5 + pw * 0.5
        for i in 0..<pieces {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: pw + 2, height: size.height + 1)
            node.position = CGPoint(x: originX + CGFloat(i) * pw, y: 0)
            node.zPosition = z
            lit(node, castsShadow: castsShadow)
            parent.addChild(node)
        }
    }

    static func terrainNode(rect: CGRect) -> SKNode {
        let root = SKNode()
        root.position = CGPoint(x: rect.midX, y: rect.midY)
        let isWall = rect.height >= max(160, rect.width * 1.8)
        let isCeiling = rect.minY >= 1800 || (rect.width >= 2000 && rect.minY >= 1000)

        if isWall, let wall = texture("wall.jpg") ?? texture("wall.png") {
            span(root, texture: wall, size: rect.size, z: 1, maxPiece: 900, castsShadow: true)
            addDropShadow(to: root, rect: rect)
            return root
        }
        if isCeiling, let ceiling = texture("ceiling.jpg") ?? texture("ceiling.png") {
            span(root, texture: ceiling, size: rect.size, z: 1, maxPiece: 2200, castsShadow: true)
            return root
        }

        if let body = texture("fill.jpg") ?? texture("fill.png") {
            span(root, texture: body, size: rect.size, z: 0, maxPiece: 1600, castsShadow: false)
        } else {
            let fillNode = SKShapeNode(rectOf: rect.size)
            fillNode.fillColor = UIColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
            fillNode.strokeColor = .clear
            root.addChild(fillNode)
        }

        if let ground = texture("ground.jpg") ?? texture("floor.png") {
            let capH = min(max(24, rect.height * (rect.height <= 40 ? 1 : 0.52)), rect.height)
            let cap = SKNode()
            cap.position = CGPoint(x: 0, y: rect.height * 0.5 - capH * 0.5)
            span(cap, texture: ground, size: CGSize(width: rect.width, height: capH), z: 3, maxPiece: 2200, castsShadow: true)
            root.addChild(cap)
        }

        if rect.height > 80, let ceiling = texture("ceiling.jpg") ?? texture("ceiling.png") {
            let capH = min(42, rect.height * 0.32)
            let cap = SKNode()
            cap.position = CGPoint(x: 0, y: -rect.height * 0.5 + capH * 0.5)
            span(cap, texture: ceiling, size: CGSize(width: rect.width, height: capH), z: 2, maxPiece: 2200, castsShadow: false)
            root.addChild(cap)
        }
        addDropShadow(to: root, rect: rect)
        return root
    }

    static func addDropShadow(to root: SKNode, rect: CGRect) {
        guard let shadow = texture("shadow.png") else { return }
        let node = SKSpriteNode(texture: shadow)
        node.size = CGSize(width: rect.width * 1.08, height: max(22, min(70, rect.height * 0.22)))
        node.position = CGPoint(x: 0, y: -rect.height * 0.5 - 8)
        node.zPosition = -2
        node.alpha = 0.9
        root.addChild(node)
    }

    static func addWorldLayers(to scene: SKScene, worldBounds: CGRect) {
        scene.backgroundColor = UIColor(red: 0.004, green: 0.006, blue: 0.01, alpha: 1)
        layer(scene, name: "far.jpg", worldBounds: worldBounds, height: worldBounds.height * 1.05, z: -124, alpha: 1)
        layer(scene, name: "mid.jpg", worldBounds: worldBounds, height: worldBounds.height * 0.92, z: -108, alpha: 0.92)
        layer(scene, name: "chamber.jpg", worldBounds: worldBounds, height: worldBounds.height * 0.78, z: -96, alpha: 0.55)
        layer(scene, name: "near.jpg", worldBounds: worldBounds, height: worldBounds.height * 0.70, z: -78, alpha: 0.42)
    }

    private static func layer(_ scene: SKScene, name: String, worldBounds: CGRect, height: CGFloat, z: CGFloat, alpha: CGFloat) {
        guard let texture = texture(name) else { return }
        let aspect = texture.size().width / max(1, texture.size().height)
        let width = height * aspect
        var x = worldBounds.minX + width * 0.5
        var flip = false
        while x < worldBounds.maxX + width * 0.4 {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: width + 8, height: height)
            node.position = CGPoint(x: x, y: worldBounds.midY + (z + 100) * 0.4)
            node.zPosition = z
            node.alpha = alpha
            if flip { node.xScale = -abs(node.xScale) }
            lit(node, castsShadow: false)
            scene.addChild(node)
            x += width * 0.92
            flip.toggle()
        }
    }

    static func attachPlayerLight(to player: SKNode) {
        if player.childNode(withName: "soulLight") != nil { return }
        let light = SKLightNode()
        light.name = "soulLight"
        light.categoryBitMask = lightMask
        light.falloff = 0.85
        light.ambientColor = UIColor(red: 0.03, green: 0.04, blue: 0.055, alpha: 1)
        light.lightColor = UIColor(red: 0.62, green: 0.82, blue: 1.0, alpha: 1)
        light.shadowColor = UIColor(red: 0, green: 0, blue: 0.02, alpha: 0.88)
        player.addChild(light)
    }

    static func installAtmosphere(in scene: SKScene) {
        guard let camera = scene.camera else { return }
        if camera.childNode(withName: "hkDark") == nil, let darkTex = texture("darkness.png") {
            let dark = SKSpriteNode(texture: darkTex)
            dark.name = "hkDark"
            dark.size = CGSize(width: 3000, height: 1800)
            dark.zPosition = 850
            camera.addChild(dark)
        }
        if camera.childNode(withName: "hkGrade") == nil {
            let grade = SKSpriteNode(color: UIColor(red: 0.02, green: 0.04, blue: 0.07, alpha: 0.32), size: CGSize(width: 3000, height: 1800))
            grade.name = "hkGrade"
            grade.zPosition = 840
            camera.addChild(grade)
        }
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
        EnvArt.addWorldLayers(to: scene, worldBounds: worldBounds)
    }

    static func terrainNode(rect: CGRect) -> SKNode {
        EnvArt.terrainNode(rect: rect)
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
        arrow.text = horizontal ? String(utf16CodeUnits: [0x2194], count: 1) : String(utf16CodeUnits: [0x2195], count: 1)
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
        case .groundPatrol: color = "brown"; title = String(utf16CodeUnits: [0x041F, 0x0410, 0x0422, 0x0420, 0x0423, 0x041B, 0x042C, 0x041D, 0x042B, 0x0419], count: 10)
        case .flying: color = "violet"; title = String(utf16CodeUnits: [0x041B, 0x0415, 0x0422, 0x0410, 0x042E, 0x0429, 0x0418, 0x0419], count: 8)
        case .aggressive: color = "red"; title = String(utf16CodeUnits: [0x0410, 0x0413, 0x0420, 0x0415, 0x0421, 0x0421, 0x0418, 0x0412, 0x041D, 0x042B, 0x0419], count: 11)
        }
        var frames: [SKTexture] = []
        for i in 0..<5 {
            if let t = texture("Individual PNG files/Monster/scorpion-" + color + "/scorpion-" + color + "-" + String(i) + ".png") { frames.append(t) }
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
