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

    static func texture(_ name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        let url = Bundle.main.bundleURL.appendingPathComponent("EnvArt").appendingPathComponent(name)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }

    static func terrainNode(rect: CGRect) -> SKNode {
        let root = SKNode()
        root.position = CGPoint(x: rect.midX, y: rect.midY)
        let isWall = rect.height >= max(160, rect.width * 1.8)
        let isCeiling = rect.minY >= 1800 || (rect.width >= 2000 && rect.minY >= 1000)

        let body = SKShapeNode(rectOf: rect.size, cornerRadius: min(6, min(rect.width, rect.height) * 0.08))
        body.fillColor = UIColor(red: 0.09, green: 0.12, blue: 0.16, alpha: 1)
        body.strokeColor = UIColor(red: 0.01, green: 0.015, blue: 0.02, alpha: 1)
        body.lineWidth = 5.5
        body.zPosition = 0
        root.addChild(body)

        if isWall, let wall = texture("wall_ink.png") ?? texture("wall.jpg") {
            dress(root, texture: wall, size: CGSize(width: rect.width + 18, height: rect.height + 12), chunk: 420)
            addDropShadow(to: root, rect: rect)
            return root
        }
        if isCeiling, let ceil = texture("fg_ceil.png") ?? texture("ceiling.jpg") {
            dress(root, texture: ceil, size: CGSize(width: rect.width + 10, height: max(70, rect.height + 8)), chunk: 900)
            return root
        }

        if let plat = texture("platform.png") {
            let capH = min(max(34, rect.height * (rect.height <= 42 ? 1.15 : 0.70)), rect.height + 16)
            let cap = SKNode()
            cap.position = CGPoint(x: 0, y: rect.height * 0.5 - capH * 0.35)
            dress(cap, texture: plat, size: CGSize(width: rect.width + 16, height: capH), chunk: 340)
            root.addChild(cap)
        }
        addDropShadow(to: root, rect: rect)
        return root
    }

    private static func dress(_ parent: SKNode, texture: SKTexture, size: CGSize, chunk: CGFloat) {
        let pieces = max(1, Int(ceil(size.width / max(80, chunk * 0.78))))
        let pw = size.width / CGFloat(pieces)
        let originX = -size.width * 0.5 + pw * 0.5
        for i in 0..<pieces {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: pw + 10, height: size.height)
            node.position = CGPoint(x: originX + CGFloat(i) * pw, y: 0)
            node.zPosition = 3
            if i % 2 == 1 { node.xScale = -abs(node.xScale) }
            parent.addChild(node)
        }
    }

    static func addDropShadow(to root: SKNode, rect: CGRect) {
        guard let shadow = texture("shadow.png") else { return }
        let node = SKSpriteNode(texture: shadow)
        node.size = CGSize(width: rect.width * 1.06, height: max(18, min(56, rect.height * 0.18)))
        node.position = CGPoint(x: 0, y: -rect.height * 0.5 - 7)
        node.zPosition = -2
        root.addChild(node)
    }

    static func addWorldLayers(to scene: SKScene, worldBounds: CGRect) {
        scene.backgroundColor = UIColor(red: 0.02, green: 0.04, blue: 0.07, alpha: 1)
        placeZone(scene, far: "cross_far.jpg", mid: "cross_mid.jpg", x0: worldBounds.minX, x1: 9000, worldBounds: worldBounds)
        placeZone(scene, far: "moss_far.jpg", mid: "moss_mid.jpg", x0: 9000, x1: 15000, worldBounds: worldBounds)
        placeZone(scene, far: "city_far.jpg", mid: "city_mid.jpg", x0: 15000, x1: 20000, worldBounds: worldBounds)
        placeZone(scene, far: "nest_far.jpg", mid: "nest_mid.jpg", x0: 20000, x1: 24000, worldBounds: worldBounds)
        placeZone(scene, far: "void_far.jpg", mid: "void_far.jpg", x0: 24000, x1: worldBounds.maxX, worldBounds: worldBounds)
    }

    private static func placeZone(_ scene: SKScene, far: String, mid: String, x0: CGFloat, x1: CGFloat, worldBounds: CGRect) {
        let slice = CGRect(x: x0, y: worldBounds.minY, width: max(100, x1 - x0), height: worldBounds.height)
        placeNamed(scene, name: far, in: slice, height: worldBounds.height * 1.02, z: -124, alpha: 1)
        placeNamed(scene, name: mid, in: slice, height: worldBounds.height * 0.86, z: -102, alpha: 0.94)
    }

    private static func placeNamed(_ scene: SKScene, name: String, in slice: CGRect, height: CGFloat, z: CGFloat, alpha: CGFloat) {
        let tex = texture(name) ?? KingdomArt.texture(name)
        guard let texture = tex else { return }
        let aspect = texture.size().width / max(1, texture.size().height)
        let width = height * aspect
        var x = slice.minX + width * 0.5
        var flip = false
        while x < slice.maxX + width * 0.2 {
            let node = SKSpriteNode(texture: texture)
            node.size = CGSize(width: width + 6, height: height)
            node.position = CGPoint(x: x, y: slice.midY)
            node.zPosition = z
            node.alpha = alpha
            if flip { node.xScale = -abs(node.xScale) }
            scene.addChild(node)
            x += width * 0.94
            flip.toggle()
        }
    }

    private static func place(_ scene: SKScene, name: String, worldBounds: CGRect, height: CGFloat, z: CGFloat, alpha: CGFloat) {
        placeNamed(scene, name: name, in: worldBounds, height: height, z: z, alpha: alpha)
    }

    static func addForeground(to scene: SKScene, worldBounds: CGRect) {
        guard let camera = scene.camera else { return }
        if camera.childNode(withName: "hkFG") == nil, let tex = texture("fg.png") {
            let n = SKSpriteNode(texture: tex)
            n.name = "hkFG"
            n.size = CGSize(width: 980, height: 210)
            n.position = CGPoint(x: 0, y: -188)
            n.zPosition = 70
            camera.addChild(n)
        }
        if camera.childNode(withName: "hkFGCeil") == nil, let tex = texture("fg_ceil.png") {
            let n = SKSpriteNode(texture: tex)
            n.name = "hkFGCeil"
            n.size = CGSize(width: 980, height: 170)
            n.position = CGPoint(x: 0, y: 205)
            n.zPosition = 70
            camera.addChild(n)
        }
        if let fg = texture("fg.png") {
            var x = worldBounds.minX + 420
            while x < worldBounds.maxX {
                let n = SKSpriteNode(texture: fg)
                n.size = CGSize(width: 620, height: 160)
                n.position = CGPoint(x: x, y: 70)
                n.zPosition = 48
                n.alpha = 0.55
                scene.addChild(n)
                x += 780
            }
        }
    }

    static func addParticles(to scene: SKScene) {
        guard let camera = scene.camera, camera.childNode(withName: "hkSpores") == nil else { return }
        let burst = SKEmitterNode()
        burst.name = "hkSpores"
        burst.particleTexture = texture("spore.png")
        burst.particleBirthRate = 14
        burst.numParticlesToEmit = 0
        burst.particleLifetime = 9
        burst.particleLifetimeRange = 4
        burst.particlePositionRange = CGVector(dx: 900, dy: 420)
        burst.emissionAngle = CGFloat.pi / 2
        burst.emissionAngleRange = 0.6
        burst.particleSpeed = 18
        burst.particleSpeedRange = 10
        burst.particleAlpha = 0.28
        burst.particleAlphaRange = 0.12
        burst.particleAlphaSpeed = -0.02
        burst.particleScale = 0.35
        burst.particleScaleRange = 0.2
        burst.particleColor = UIColor(red: 0.75, green: 0.9, blue: 1, alpha: 1)
        burst.particleColorBlendFactor = 1
        burst.zPosition = 25
        camera.addChild(burst)
    }

    static func attachPlayerLight(to player: SKNode) {
        if player.childNode(withName: "soulLight") != nil { return }
        let light = SKLightNode()
        light.name = "soulLight"
        light.categoryBitMask = 1
        light.falloff = 1.1
        light.ambientColor = UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)
        light.lightColor = UIColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1)
        light.shadowColor = UIColor(red: 0, green: 0, blue: 0.03, alpha: 0.75)
        player.addChild(light)
        if let soul = texture("soul.png") {
            let glow = SKSpriteNode(texture: soul)
            glow.name = "soulGlow"
            glow.size = CGSize(width: 380, height: 380)
            glow.zPosition = -1
            glow.blendMode = .add
            glow.alpha = 0.55
            player.addChild(glow)
        }
    }

    static func installAtmosphere(in scene: SKScene) {
        guard let camera = scene.camera else { return }
        if camera.childNode(withName: "hkDark") == nil, let darkTex = texture("darkness.png") {
            let dark = SKSpriteNode(texture: darkTex)
            dark.name = "hkDark"
            dark.size = CGSize(width: 2600, height: 1500)
            dark.zPosition = 80
            dark.alpha = 0.92
            camera.addChild(dark)
        }
        if camera.childNode(withName: "hkGrade") == nil {
            let grade = SKSpriteNode(color: UIColor(red: 0.02, green: 0.06, blue: 0.12, alpha: 0.22), size: CGSize(width: 2600, height: 1500))
            grade.name = "hkGrade"
            grade.zPosition = 78
            camera.addChild(grade)
        }
        if camera.childNode(withName: "hkRays") == nil, let rays = texture("rays.png") {
            let n = SKSpriteNode(texture: rays)
            n.name = "hkRays"
            n.size = CGSize(width: 520, height: 780)
            n.position = CGPoint(x: -40, y: 30)
            n.zPosition = 22
            n.alpha = 0.32
            n.blendMode = .add
            camera.addChild(n)
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
        let sheetName: String
        let size: CGSize
        switch kind {
        case .groundPatrol:
            sheetName = "enemy_grub.png"
            size = CGSize(width: 78, height: 78)
        case .flying:
            sheetName = "enemy_fly.png"
            size = CGSize(width: 86, height: 86)
        case .aggressive:
            sheetName = "enemy_husk.png"
            size = CGSize(width: 92, height: 92)
        case .passive:
            sheetName = "enemy_grub.png"
            size = CGSize(width: 64, height: 64)
        case .miniBoss:
            sheetName = "enemy_husk.png"
            size = CGSize(width: 128, height: 128)
        case .boss:
            sheetName = "enemy_boss.png"
            size = CGSize(width: 180, height: 180)
        }
        if let sheet = EnvArt.texture(sheetName) {
            let frames: [SKTexture] = (0..<4).map { index in
                let tex = SKTexture(rect: CGRect(x: CGFloat(index) * 0.25, y: 0, width: 0.25, height: 1), in: sheet)
                tex.filteringMode = .linear
                return tex
            }
            let sprite = SKSpriteNode(texture: frames.first)
            sprite.size = size
            sprite.zPosition = 2
            sprite.name = "enemySprite"
            root.addChild(sprite)
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.12)))
        } else {
            let fallback = SKShapeNode(circleOfRadius: 24)
            fallback.fillColor = .red
            fallback.strokeColor = .white
            root.addChild(fallback)
        }
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
