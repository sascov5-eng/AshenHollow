import SpriteKit
import UIKit

private enum ApproachAtmosphereNames {
    static let action = "approachAtmosphereRuntime"
    static let root = "approachAtmosphereRoot"
    static let far = "approachAtmosphereFar"
    static let mid = "approachAtmosphereMid"
    static let haze = "approachAtmosphereHaze"
    static let vignette = "approachAtmosphereVignette"
}

enum ApproachAtmosphereInstaller {
    static func install(on scene: SKScene, context: V21RuntimeContext) {
        scene.removeAction(forKey: ApproachAtmosphereNames.action)
        clear(from: scene)

        var lastRoomID: RoomID?

        let action = SKAction.customAction(withDuration: 1_000_000) { node, _ in
            guard let scene = node as? SKScene else { return }
            let roomID = context.activeRoomID

            if roomID != lastRoomID {
                lastRoomID = roomID
                if roomID == .approach {
                    build(on: scene)
                } else {
                    clear(from: scene)
                }
            }

            guard roomID == .approach else { return }

            // The first room teaches by composition and light rather than tutorial copy.
            scene.childNode(withName: "//v24OnboardingPrompt")?.isHidden = true
            updateParallax(on: scene)
        }

        scene.run(action, withKey: ApproachAtmosphereNames.action)
    }

    static func clear(from scene: SKScene) {
        scene.childNode(withName: ApproachAtmosphereNames.root)?.removeFromParent()
        scene.camera?.childNode(withName: ApproachAtmosphereNames.vignette)?.removeFromParent()
    }

    private static func build(on scene: SKScene) {
        clear(from: scene)

        let roomWidth = 1200.0
        let roomHeight = 560.0
        let layout = ApproachAtmosphereLayout.make(roomWidth: roomWidth, roomHeight: roomHeight)

        let root = SKNode()
        root.name = ApproachAtmosphereNames.root
        root.zPosition = -48
        scene.addChild(root)

        let backdrop = SKShapeNode(
            rectOf: CGSize(width: CGFloat(roomWidth + 320), height: CGFloat(roomHeight + 180))
        )
        backdrop.fillColor = UIColor(red: 0.018, green: 0.022, blue: 0.032, alpha: 1)
        backdrop.strokeColor = .clear
        backdrop.position = CGPoint(x: CGFloat(roomWidth * 0.5), y: CGFloat(roomHeight * 0.5))
        backdrop.zPosition = 0
        root.addChild(backdrop)

        let upperVoid = SKShapeNode(
            rectOf: CGSize(width: CGFloat(roomWidth + 360), height: 210),
            cornerRadius: 50
        )
        upperVoid.fillColor = UIColor(red: 0.012, green: 0.014, blue: 0.022, alpha: 0.98)
        upperVoid.strokeColor = .clear
        upperVoid.position = CGPoint(x: CGFloat(roomWidth * 0.5), y: CGFloat(roomHeight - 34))
        upperVoid.zPosition = 1
        root.addChild(upperVoid)

        let farRoot = SKNode()
        farRoot.name = ApproachAtmosphereNames.far
        farRoot.zPosition = 3
        root.addChild(farRoot)
        buildFarStructures(layout.farStructures, in: farRoot)

        let midRoot = SKNode()
        midRoot.name = ApproachAtmosphereNames.mid
        midRoot.zPosition = 8
        root.addChild(midRoot)
        buildMidStructures(layout.midStructures, in: midRoot)

        buildStartShelter(layout.startShelter, in: root)
        buildJumpBeacon(layout.jumpBeacon, in: root)
        buildEnemyPool(layout.enemyPool, in: root)
        buildDropShaft(layout.dropShaft, in: root)
        buildForegroundDebris(layout.foregroundDebris, in: root)

        let hazeRoot = SKNode()
        hazeRoot.name = ApproachAtmosphereNames.haze
        hazeRoot.zPosition = 18
        root.addChild(hazeRoot)
        buildFog(layout.fogBands, in: hazeRoot)
        buildAsh(layout.ashSeeds, in: hazeRoot)

        buildCeilingFragments(roomWidth: roomWidth, roomHeight: roomHeight, in: root)
        buildVignette(on: scene)
        updateParallax(on: scene)
    }

    private static func buildFarStructures(
        _ blocks: [ApproachAtmosphereLayout.Block],
        in parent: SKNode
    ) {
        for (index, block) in blocks.enumerated() {
            let body = makeBlock(
                block,
                fill: UIColor(red: 0.052, green: 0.058, blue: 0.078, alpha: 0.96),
                stroke: UIColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 0.24),
                lineWidth: 1
            )
            body.name = "farRuin_\(index)"
            parent.addChild(body)

            let cap = SKShapeNode(
                rectOf: CGSize(width: CGFloat(block.width * 1.16), height: 14),
                cornerRadius: 3
            )
            cap.fillColor = UIColor(red: 0.068, green: 0.075, blue: 0.098, alpha: 0.92)
            cap.strokeColor = .clear
            cap.position = CGPoint(
                x: CGFloat(block.centerX + (index.isMultiple(of: 2) ? -5 : 7)),
                y: CGFloat(block.centerY + block.height * 0.47)
            )
            cap.zRotation = CGFloat(block.rotation * -0.55)
            parent.addChild(cap)
        }

        // Broken bridge silhouette high in the room, intentionally unreachable.
        let bridge = SKShapeNode(rectOf: CGSize(width: 560, height: 24), cornerRadius: 7)
        bridge.fillColor = UIColor(red: 0.048, green: 0.052, blue: 0.071, alpha: 0.94)
        bridge.strokeColor = .clear
        bridge.position = CGPoint(x: 610, y: 418)
        bridge.zRotation = -0.025
        parent.addChild(bridge)

        let bridgeGap = SKShapeNode(rectOf: CGSize(width: 112, height: 58), cornerRadius: 8)
        bridgeGap.fillColor = UIColor(red: 0.018, green: 0.022, blue: 0.032, alpha: 1)
        bridgeGap.strokeColor = .clear
        bridgeGap.position = CGPoint(x: 735, y: 414)
        parent.addChild(bridgeGap)
    }

    private static func buildMidStructures(
        _ blocks: [ApproachAtmosphereLayout.Block],
        in parent: SKNode
    ) {
        for (index, block) in blocks.enumerated() {
            let body = makeBlock(
                block,
                fill: UIColor(red: 0.075, green: 0.079, blue: 0.098, alpha: 0.92),
                stroke: UIColor(red: 0.20, green: 0.22, blue: 0.26, alpha: 0.30),
                lineWidth: 1.4
            )
            body.name = "midRuin_\(index)"
            parent.addChild(body)

            if index % 2 == 0 {
                let crack = SKShapeNode(rectOf: CGSize(width: 4, height: CGFloat(block.height * 0.56)), cornerRadius: 2)
                crack.fillColor = UIColor(red: 0.025, green: 0.028, blue: 0.038, alpha: 0.72)
                crack.strokeColor = .clear
                crack.position = CGPoint(
                    x: CGFloat(block.centerX + block.width * 0.12),
                    y: CGFloat(block.centerY + block.height * 0.03)
                )
                crack.zRotation = CGFloat(0.10 * (index.isMultiple(of: 4) ? 1 : -1))
                parent.addChild(crack)
            }
        }
    }

    private static func buildStartShelter(
        _ block: ApproachAtmosphereLayout.Block,
        in parent: SKNode
    ) {
        let shadow = SKShapeNode(
            rectOf: CGSize(width: CGFloat(block.width), height: CGFloat(block.height)),
            cornerRadius: CGFloat(block.cornerRadius)
        )
        shadow.fillColor = UIColor(red: 0.014, green: 0.018, blue: 0.027, alpha: 0.90)
        shadow.strokeColor = UIColor(red: 0.12, green: 0.15, blue: 0.19, alpha: 0.28)
        shadow.lineWidth = 2
        shadow.position = CGPoint(x: CGFloat(block.centerX), y: CGFloat(block.centerY))
        shadow.zPosition = 10
        parent.addChild(shadow)

        for offset in [-76.0, 68.0] {
            let pillar = SKShapeNode(rectOf: CGSize(width: 28, height: 242), cornerRadius: 7)
            pillar.fillColor = UIColor(red: 0.085, green: 0.09, blue: 0.11, alpha: 0.94)
            pillar.strokeColor = UIColor(white: 0.28, alpha: 0.18)
            pillar.lineWidth = 1.5
            pillar.position = CGPoint(x: CGFloat(block.centerX + offset), y: 183)
            pillar.zRotation = offset < 0 ? -0.035 : 0.045
            pillar.zPosition = 12
            parent.addChild(pillar)
        }

        let roof = SKShapeNode(rectOf: CGSize(width: 220, height: 34), cornerRadius: 8)
        roof.fillColor = UIColor(red: 0.09, green: 0.095, blue: 0.115, alpha: 0.94)
        roof.strokeColor = UIColor(white: 0.30, alpha: 0.18)
        roof.lineWidth = 1.5
        roof.position = CGPoint(x: CGFloat(block.centerX - 4), y: 304)
        roof.zRotation = -0.035
        roof.zPosition = 12
        parent.addChild(roof)

        let safeGlow = SKShapeNode(ellipseOf: CGSize(width: 196, height: 66))
        safeGlow.fillColor = UIColor(red: 0.22, green: 0.44, blue: 0.57, alpha: 0.065)
        safeGlow.strokeColor = .clear
        safeGlow.position = CGPoint(x: 124, y: 96)
        safeGlow.zPosition = 13
        parent.addChild(safeGlow)
    }

    private static func buildJumpBeacon(
        _ block: ApproachAtmosphereLayout.Block,
        in parent: SKNode
    ) {
        let beam = SKShapeNode(
            rectOf: CGSize(width: CGFloat(block.width * 0.66), height: CGFloat(block.height)),
            cornerRadius: 54
        )
        beam.fillColor = UIColor(red: 0.26, green: 0.55, blue: 0.70, alpha: 0.055)
        beam.strokeColor = .clear
        beam.position = CGPoint(x: CGFloat(block.centerX), y: CGFloat(block.centerY + 8))
        beam.zPosition = 14
        parent.addChild(beam)
        beam.run(
            SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.55, duration: 2.4),
                    SKAction.fadeAlpha(to: 1.0, duration: 2.8)
                ])
            )
        )

        let floorGlow = SKShapeNode(ellipseOf: CGSize(width: CGFloat(block.width), height: 54))
        floorGlow.fillColor = UIColor(red: 0.30, green: 0.66, blue: 0.82, alpha: 0.10)
        floorGlow.strokeColor = UIColor(red: 0.42, green: 0.72, blue: 0.86, alpha: 0.08)
        floorGlow.lineWidth = 2
        floorGlow.position = CGPoint(x: CGFloat(block.centerX), y: 92)
        floorGlow.zPosition = 15
        parent.addChild(floorGlow)

        let fracture = SKShapeNode(rectOf: CGSize(width: 84, height: 7), cornerRadius: 3)
        fracture.fillColor = UIColor(red: 0.34, green: 0.66, blue: 0.78, alpha: 0.24)
        fracture.strokeColor = .clear
        fracture.position = CGPoint(x: 445, y: 169)
        fracture.zRotation = -0.11
        fracture.zPosition = 15
        parent.addChild(fracture)
    }

    private static func buildEnemyPool(
        _ block: ApproachAtmosphereLayout.Block,
        in parent: SKNode
    ) {
        let pool = SKShapeNode(
            ellipseOf: CGSize(width: CGFloat(block.width), height: CGFloat(block.height))
        )
        pool.fillColor = UIColor(red: 0.48, green: 0.17, blue: 0.12, alpha: 0.075)
        pool.strokeColor = UIColor(red: 0.62, green: 0.24, blue: 0.16, alpha: 0.07)
        pool.lineWidth = 2
        pool.position = CGPoint(x: CGFloat(block.centerX), y: CGFloat(block.centerY))
        pool.zPosition = 15
        parent.addChild(pool)

        let ember = SKShapeNode(ellipseOf: CGSize(width: 104, height: 32))
        ember.fillColor = UIColor(red: 0.68, green: 0.23, blue: 0.13, alpha: 0.065)
        ember.strokeColor = .clear
        ember.position = CGPoint(x: 790, y: 89)
        ember.zPosition = 16
        parent.addChild(ember)
        ember.run(
            SKAction.repeatForever(
                SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.48, duration: 1.7),
                    SKAction.fadeAlpha(to: 1.0, duration: 2.1)
                ])
            )
        )
    }

    private static func buildDropShaft(
        _ block: ApproachAtmosphereLayout.Block,
        in parent: SKNode
    ) {
        let void = SKShapeNode(
            rectOf: CGSize(width: CGFloat(block.width), height: CGFloat(block.height)),
            cornerRadius: CGFloat(block.cornerRadius)
        )
        void.fillColor = UIColor(red: 0.004, green: 0.006, blue: 0.010, alpha: 0.98)
        void.strokeColor = UIColor(red: 0.09, green: 0.12, blue: 0.15, alpha: 0.30)
        void.lineWidth = 2
        void.position = CGPoint(x: CGFloat(block.centerX), y: CGFloat(block.centerY))
        void.zPosition = 12
        parent.addChild(void)

        let leftEdge = SKShapeNode(rectOf: CGSize(width: 28, height: CGFloat(block.height * 1.18)), cornerRadius: 6)
        leftEdge.fillColor = UIColor(red: 0.085, green: 0.09, blue: 0.105, alpha: 0.96)
        leftEdge.strokeColor = UIColor(white: 0.26, alpha: 0.16)
        leftEdge.lineWidth = 1
        leftEdge.position = CGPoint(x: CGFloat(block.centerX - block.width * 0.54), y: CGFloat(block.centerY + 20))
        leftEdge.zRotation = -0.025
        leftEdge.zPosition = 13
        parent.addChild(leftEdge)

        for index in 0..<4 {
            let streak = SKShapeNode(rectOf: CGSize(width: 4, height: CGFloat(92 + index * 18)), cornerRadius: 2)
            streak.fillColor = UIColor(red: 0.20, green: 0.38, blue: 0.47, alpha: 0.06 + CGFloat(index) * 0.012)
            streak.strokeColor = .clear
            streak.position = CGPoint(x: CGFloat(block.centerX - 58 + Double(index) * 34), y: CGFloat(block.centerY - 18))
            streak.zPosition = 13
            parent.addChild(streak)
        }
    }

    private static func buildForegroundDebris(
        _ blocks: [ApproachAtmosphereLayout.Block],
        in parent: SKNode
    ) {
        for (index, block) in blocks.enumerated() {
            let debris = makeBlock(
                block,
                fill: UIColor(red: 0.115, green: 0.12, blue: 0.14, alpha: 0.96),
                stroke: UIColor(white: 0.34, alpha: 0.16),
                lineWidth: 1
            )
            debris.name = "foregroundDebris_\(index)"
            debris.zPosition = 22
            parent.addChild(debris)
        }
    }

    private static func buildFog(
        _ bands: [ApproachAtmosphereLayout.FogBand],
        in parent: SKNode
    ) {
        for (index, band) in bands.enumerated() {
            let fog = SKShapeNode(
                ellipseOf: CGSize(width: CGFloat(band.width), height: CGFloat(band.height))
            )
            fog.name = "fogBand_\(index)"
            fog.fillColor = UIColor(red: 0.22, green: 0.27, blue: 0.31, alpha: CGFloat(band.alpha))
            fog.strokeColor = .clear
            fog.position = CGPoint(x: 600, y: CGFloat(band.centerY))
            fog.zPosition = CGFloat(index)
            parent.addChild(fog)

            let travel = SKAction.moveBy(x: CGFloat(band.drift), y: 0, duration: 6.8 + Double(index) * 1.4)
            travel.timingMode = .easeInEaseOut
            fog.run(SKAction.repeatForever(SKAction.sequence([travel, travel.reversed()])))
        }
    }

    private static func buildAsh(
        _ seeds: [ApproachAtmosphereLayout.AshSeed],
        in parent: SKNode
    ) {
        for (index, seed) in seeds.enumerated() {
            let ash = SKShapeNode(circleOfRadius: CGFloat(seed.radius))
            ash.name = "ash_\(index)"
            ash.fillColor = UIColor(red: 0.68, green: 0.72, blue: 0.74, alpha: CGFloat(seed.alpha))
            ash.strokeColor = .clear
            ash.position = CGPoint(x: CGFloat(seed.x), y: CGFloat(seed.y))
            ash.zPosition = 6
            parent.addChild(ash)

            let drift = SKAction.moveBy(x: CGFloat(seed.driftX), y: CGFloat(seed.driftY), duration: seed.duration)
            drift.timingMode = .easeInEaseOut
            let fade = SKAction.fadeOut(withDuration: seed.duration)
            let travel = SKAction.group([drift, fade])
            let reset = SKAction.group([
                SKAction.moveBy(x: CGFloat(-seed.driftX), y: CGFloat(-seed.driftY), duration: 0),
                SKAction.fadeAlpha(to: CGFloat(seed.alpha), duration: 0)
            ])
            ash.run(
                SKAction.repeatForever(
                    SKAction.sequence([
                        SKAction.wait(forDuration: seed.delay),
                        travel,
                        reset
                    ])
                )
            )
        }
    }

    private static func buildCeilingFragments(
        roomWidth: Double,
        roomHeight: Double,
        in parent: SKNode
    ) {
        let fragments: [(Double, Double, Double, Double, Double)] = [
            (90, 506, 180, 52, -0.04),
            (286, 526, 120, 38, 0.06),
            (520, 512, 210, 44, -0.025),
            (790, 531, 142, 36, 0.055),
            (1010, 505, 230, 50, -0.045),
            (1172, 532, 98, 38, 0.07)
        ]

        for item in fragments {
            let node = SKShapeNode(rectOf: CGSize(width: item.2, height: item.3), cornerRadius: 7)
            node.fillColor = UIColor(red: 0.075, green: 0.078, blue: 0.095, alpha: 0.97)
            node.strokeColor = UIColor(white: 0.25, alpha: 0.12)
            node.lineWidth = 1
            node.position = CGPoint(x: item.0, y: item.1)
            node.zRotation = item.4
            node.zPosition = 20
            parent.addChild(node)
        }

        _ = roomWidth
        _ = roomHeight
    }

    private static func buildVignette(on scene: SKScene) {
        guard let camera = scene.camera else { return }

        let root = SKNode()
        root.name = ApproachAtmosphereNames.vignette
        root.zPosition = 720
        camera.addChild(root)

        let visibleWidth = max(scene.size.width * camera.xScale, 1300)
        let visibleHeight = max(scene.size.height * camera.yScale, 600)
        let edgeWidth = visibleWidth * 0.22
        let edgeHeight = visibleHeight * 0.18

        func edge(size: CGSize, position: CGPoint, alpha: CGFloat) {
            let node = SKShapeNode(rectOf: size)
            node.fillColor = UIColor(white: 0, alpha: alpha)
            node.strokeColor = .clear
            node.position = position
            root.addChild(node)
        }

        edge(
            size: CGSize(width: edgeWidth, height: visibleHeight * 1.2),
            position: CGPoint(x: -visibleWidth * 0.5 + edgeWidth * 0.5, y: 0),
            alpha: 0.19
        )
        edge(
            size: CGSize(width: edgeWidth, height: visibleHeight * 1.2),
            position: CGPoint(x: visibleWidth * 0.5 - edgeWidth * 0.5, y: 0),
            alpha: 0.22
        )
        edge(
            size: CGSize(width: visibleWidth * 1.2, height: edgeHeight),
            position: CGPoint(x: 0, y: visibleHeight * 0.5 - edgeHeight * 0.5),
            alpha: 0.18
        )
        edge(
            size: CGSize(width: visibleWidth * 1.2, height: edgeHeight),
            position: CGPoint(x: 0, y: -visibleHeight * 0.5 + edgeHeight * 0.5),
            alpha: 0.12
        )
    }

    private static func updateParallax(on scene: SKScene) {
        guard let root = scene.childNode(withName: ApproachAtmosphereNames.root),
              let camera = scene.camera else {
            return
        }

        let layout = ApproachAtmosphereLayout.make(roomWidth: 1200, roomHeight: 560)
        let cameraOffset = Double(camera.position.x) - 600.0

        root.childNode(withName: ApproachAtmosphereNames.far)?.position.x = CGFloat(
            cameraOffset * (1.0 - layout.farParallax)
        )
        root.childNode(withName: ApproachAtmosphereNames.mid)?.position.x = CGFloat(
            cameraOffset * (1.0 - layout.midParallax)
        )
        root.childNode(withName: ApproachAtmosphereNames.haze)?.position.x = CGFloat(
            cameraOffset * (1.0 - layout.hazeParallax)
        )
    }

    private static func makeBlock(
        _ block: ApproachAtmosphereLayout.Block,
        fill: UIColor,
        stroke: UIColor,
        lineWidth: CGFloat
    ) -> SKShapeNode {
        let node = SKShapeNode(
            rectOf: CGSize(width: CGFloat(block.width), height: CGFloat(block.height)),
            cornerRadius: CGFloat(block.cornerRadius)
        )
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        node.position = CGPoint(x: CGFloat(block.centerX), y: CGFloat(block.centerY))
        node.zRotation = CGFloat(block.rotation)
        return node
    }
}
