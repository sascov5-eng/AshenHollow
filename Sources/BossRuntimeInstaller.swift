import SpriteKit
import UIKit

private final class V21BossProjectile {
    let node: SKShapeNode
    var controller: ProjectileController
    let sourceX: CGFloat

    init(node: SKShapeNode, controller: ProjectileController, sourceX: CGFloat) {
        self.node = node
        self.controller = controller
        self.sourceX = sourceX
    }
}

private final class V21BossRuntime {
    var controller = BossController()
    let node: SKNode
    let body: SKShapeNode
    let hpFill: SKSpriteNode
    let statusLabel: SKLabelNode
    let attackTell: SKShapeNode
    let bossTitle: SKLabelNode

    var lastElapsed: CGFloat = 0
    var playerHitboxWasActive = false
    var playerSwingID = 0
    var lastAcceptedPlayerSwingID = -1
    var previousStage: BossPatternStage = .idle
    var patternIndex = 0
    var chargeDirection: CGFloat = -1
    var didDamageThisCommit = false
    var projectiles: [V21BossProjectile] = []
    var defeatCounted = false

    init(
        node: SKNode,
        body: SKShapeNode,
        hpFill: SKSpriteNode,
        statusLabel: SKLabelNode,
        attackTell: SKShapeNode,
        bossTitle: SKLabelNode
    ) {
        self.node = node
        self.body = body
        self.hpFill = hpFill
        self.statusLabel = statusLabel
        self.attackTell = attackTell
        self.bossTitle = bossTitle
    }
}

enum BossRuntimeInstaller {
    static func clear(from scene: SKScene) {
        scene.childNode(withName: "v21BossRoot")?.removeFromParent()
        scene.childNode(withName: "v21BossProjectileRoot")?.removeFromParent()
        scene.camera?.childNode(withName: "v21BossHUD")?.removeFromParent()
    }

    static func spawn(
        spawn: EnemySpawn,
        physicalOriginX: CGFloat,
        roomWidth: CGFloat,
        on scene: SKScene,
        context: V21RuntimeContext
    ) {
        clear(from: scene)
        guard spawn.archetype == .boss,
              let player = scene.childNode(withName: "player"),
              let camera = scene.camera else {
            return
        }

        let bossRoot = SKNode()
        bossRoot.name = "v21BossRoot"
        bossRoot.zPosition = 46
        scene.addChild(bossRoot)

        let projectileRoot = SKNode()
        projectileRoot.name = "v21BossProjectileRoot"
        projectileRoot.zPosition = 48
        scene.addChild(projectileRoot)

        let node = SKNode()
        node.name = "ashWarden"
        node.position = CGPoint(
            x: physicalOriginX + CGFloat(spawn.position.x),
            y: CGFloat(spawn.position.y)
        )
        bossRoot.addChild(node)

        let body = SKShapeNode(
            rectOf: CGSize(width: 80, height: 92),
            cornerRadius: 15
        )
        body.fillColor = UIColor(red: 0.28, green: 0.12, blue: 0.18, alpha: 1)
        body.strokeColor = UIColor(red: 0.95, green: 0.38, blue: 0.22, alpha: 0.85)
        body.lineWidth = 3
        node.addChild(body)

        let core = SKShapeNode(circleOfRadius: 13)
        core.fillColor = UIColor(red: 1.0, green: 0.36, blue: 0.14, alpha: 0.92)
        core.strokeColor = .clear
        core.position = CGPoint(x: 0, y: 8)
        body.addChild(core)

        let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        statusLabel.text = "ASH WARDEN"
        statusLabel.fontSize = 10
        statusLabel.fontColor = UIColor(white: 0.96, alpha: 0.88)
        statusLabel.position = CGPoint(x: 0, y: 62)
        statusLabel.verticalAlignmentMode = .center
        node.addChild(statusLabel)

        let attackTell = SKShapeNode(
            rectOf: CGSize(width: 112, height: 58),
            cornerRadius: 10
        )
        attackTell.fillColor = UIColor(red: 1.0, green: 0.08, blue: 0.05, alpha: 0.20)
        attackTell.strokeColor = UIColor(red: 1.0, green: 0.42, blue: 0.20, alpha: 0.95)
        attackTell.lineWidth = 3
        attackTell.position = CGPoint(x: -68, y: 0)
        attackTell.alpha = 0
        node.addChild(attackTell)

        let hud = SKNode()
        hud.name = "v21BossHUD"
        hud.zPosition = 1300
        hud.position = CGPoint(x: 0, y: scene.size.height * 0.5 - 74)
        camera.addChild(hud)

        let bossTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bossTitle.text = "ASH WARDEN  20/20"
        bossTitle.fontSize = 13
        bossTitle.fontColor = UIColor(red: 1.0, green: 0.74, blue: 0.58, alpha: 0.96)
        bossTitle.position = CGPoint(x: 0, y: 14)
        bossTitle.verticalAlignmentMode = .center
        hud.addChild(bossTitle)

        let hpBackground = SKSpriteNode(
            color: UIColor(white: 0.04, alpha: 0.92),
            size: CGSize(width: 248, height: 13)
        )
        hud.addChild(hpBackground)

        let hpFill = SKSpriteNode(
            color: UIColor(red: 0.82, green: 0.18, blue: 0.14, alpha: 1),
            size: CGSize(width: 240, height: 7)
        )
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -120, y: 0)
        hud.addChild(hpFill)

        let runtime = V21BossRuntime(
            node: node,
            body: body,
            hpFill: hpFill,
            statusLabel: statusLabel,
            attackTell: attackTell,
            bossTitle: bossTitle
        )

        func refreshBossHUD() {
            runtime.hpFill.xScale = CGFloat(runtime.controller.hp) / 20.0
            runtime.bossTitle.text = "ASH WARDEN  \(runtime.controller.hp)/20"
            if runtime.controller.phase == .two {
                runtime.body.fillColor = UIColor(red: 0.48, green: 0.10, blue: 0.13, alpha: 1)
                core.fillColor = UIColor(red: 1.0, green: 0.68, blue: 0.14, alpha: 1)
                runtime.bossTitle.fontColor = UIColor(red: 1.0, green: 0.40, blue: 0.25, alpha: 1)
            }
        }

        func spawnVolley() {
            let count = runtime.controller.volleyProjectileCount
            let direction: CGFloat = player.position.x >= runtime.node.position.x ? 1 : -1
            let offsets: [CGFloat]
            if count >= 5 {
                offsets = [-30, -15, 0, 15, 30]
            } else {
                offsets = [-20, 0, 20]
            }
            let speed: CGFloat = runtime.controller.phase == .two ? 335 : 290

            for offset in offsets.prefix(count) {
                let shot = SKShapeNode(ellipseOf: CGSize(width: 20, height: 12))
                shot.fillColor = UIColor(red: 1.0, green: 0.35, blue: 0.12, alpha: 0.96)
                shot.strokeColor = UIColor(red: 1.0, green: 0.78, blue: 0.32, alpha: 0.85)
                shot.lineWidth = 1.5
                shot.position = CGPoint(
                    x: runtime.node.position.x + direction * 48,
                    y: runtime.node.position.y + offset
                )
                projectileRoot.addChild(shot)

                runtime.projectiles.append(
                    V21BossProjectile(
                        node: shot,
                        controller: ProjectileController(
                            x: Double(shot.position.x),
                            velocityX: Double(direction * speed),
                            damage: 1,
                            lifetime: 3.4
                        ),
                        sourceX: runtime.node.position.x
                    )
                )
            }
        }

        let updateAction = SKAction.customAction(withDuration: 1_000_000) { _, elapsed in
            let dt: CGFloat
            if runtime.lastElapsed == 0 {
                dt = 1.0 / 60.0
            } else {
                dt = min(max(elapsed - runtime.lastElapsed, 0), 1.0 / 30.0)
            }
            runtime.lastElapsed = elapsed

            let playerRect = CGRect(
                x: player.position.x - 18,
                y: player.position.y - 30,
                width: 36,
                height: 60
            )

            let attackHitboxNode = player.childNode(withName: "attackHitbox")
            let playerHitboxActive = (attackHitboxNode?.alpha ?? 0) > 0.5
            if playerHitboxActive && !runtime.playerHitboxWasActive {
                runtime.playerSwingID += 1
            }
            runtime.playerHitboxWasActive = playerHitboxActive

            if playerHitboxActive,
               runtime.lastAcceptedPlayerSwingID != runtime.playerSwingID,
               let attackHitboxNode {
                let center = CGPoint(
                    x: player.position.x + attackHitboxNode.position.x,
                    y: player.position.y + attackHitboxNode.position.y
                )
                let attackRect = CGRect(
                    x: center.x - 31,
                    y: center.y - 21,
                    width: 62,
                    height: 42
                )
                let bossRect = CGRect(
                    x: runtime.node.position.x - 39,
                    y: runtime.node.position.y - 45,
                    width: 78,
                    height: 90
                )
                if attackRect.intersects(bossRect) {
                    runtime.lastAcceptedPlayerSwingID = runtime.playerSwingID
                    let oldPhase = runtime.controller.phase
                    _ = runtime.controller.applyPlayerHit(damage: 1)
                    refreshBossHUD()

                    let direction: CGFloat = runtime.node.position.x >= player.position.x ? 1 : -1
                    runtime.node.position.x += direction * 4
                    runtime.node.position.x = max(
                        physicalOriginX + 42,
                        min(physicalOriginX + roomWidth - 42, runtime.node.position.x)
                    )

                    runtime.body.removeAction(forKey: "bossHitFlash")
                    runtime.body.run(
                        SKAction.sequence([
                            SKAction.fadeAlpha(to: 0.42, duration: 0.04),
                            SKAction.fadeAlpha(to: 1.0, duration: 0.07)
                        ]),
                        withKey: "bossHitFlash"
                    )

                    if oldPhase != runtime.controller.phase && runtime.controller.phase == .two {
                        runtime.statusLabel.text = "PHASE II"
                        runtime.node.run(
                            SKAction.sequence([
                                SKAction.scale(to: 1.08, duration: 0.10),
                                SKAction.scale(to: 1.0, duration: 0.16)
                            ])
                        )
                    }

                    if !runtime.controller.isAlive {
                        if !runtime.defeatCounted {
                            runtime.defeatCounted = true
                            context.combatStatus.markEnemyDefeated()
                        }
                        runtime.attackTell.alpha = 0
                        runtime.statusLabel.text = "DEFEATED"
                        runtime.bossTitle.text = "ASH WARDEN — DEFEATED"
                        for projectile in runtime.projectiles {
                            projectile.node.removeFromParent()
                        }
                        runtime.projectiles.removeAll()
                        runtime.node.run(
                            SKAction.group([
                                SKAction.fadeOut(withDuration: 0.45),
                                SKAction.scale(to: 0.76, duration: 0.45)
                            ])
                        )
                        return
                    }
                }
            }

            guard runtime.controller.isAlive else { return }

            if runtime.controller.stage == .idle {
                let patterns: [BossPattern] = [.slash, .charge, .volley]
                let pattern = patterns[runtime.patternIndex % patterns.count]
                runtime.patternIndex += 1
                _ = runtime.controller.begin(pattern: pattern)
                runtime.previousStage = .idle
            }

            let stageBeforeUpdate = runtime.controller.stage
            runtime.controller.update(dt: Double(dt))
            let stage = runtime.controller.stage
            let pattern = runtime.controller.currentPattern

            if stageBeforeUpdate != stage {
                if stage == .committed {
                    runtime.didDamageThisCommit = false
                    if pattern == .charge {
                        runtime.chargeDirection = player.position.x >= runtime.node.position.x ? 1 : -1
                    } else if pattern == .volley {
                        spawnVolley()
                    }
                }
                runtime.previousStage = stageBeforeUpdate
            }

            switch stage {
            case .idle:
                runtime.attackTell.alpha = 0
                runtime.statusLabel.text = runtime.controller.phase == .two ? "PHASE II" : "READY"

            case .telegraph:
                runtime.attackTell.alpha = 0.34
                runtime.statusLabel.text = "WINDUP \(patternName(pattern))"
                let facing: CGFloat = player.position.x >= runtime.node.position.x ? 1 : -1
                runtime.attackTell.position.x = facing * 68

            case .committed:
                guard let pattern else { break }
                switch pattern {
                case .slash:
                    let facing: CGFloat = player.position.x >= runtime.node.position.x ? 1 : -1
                    runtime.attackTell.position.x = facing * 68
                    runtime.attackTell.alpha = 1
                    runtime.statusLabel.text = "SLASH"
                    let slashRect = CGRect(
                        x: runtime.node.position.x + facing * 68 - 56,
                        y: runtime.node.position.y - 29,
                        width: 112,
                        height: 58
                    )
                    if !runtime.didDamageThisCommit && slashRect.intersects(playerRect) {
                        runtime.didDamageThisCommit = true
                        context.damageInbox.enqueue(
                            damage: 2,
                            sourceX: Double(runtime.node.position.x)
                        )
                    }

                case .charge:
                    runtime.attackTell.alpha = 0.55
                    runtime.statusLabel.text = "CHARGE"
                    runtime.node.position.x += runtime.chargeDirection * (runtime.controller.phase == .two ? 330 : 285) * dt
                    runtime.node.position.x = max(
                        physicalOriginX + 42,
                        min(physicalOriginX + roomWidth - 42, runtime.node.position.x)
                    )
                    let bossRect = CGRect(
                        x: runtime.node.position.x - 40,
                        y: runtime.node.position.y - 46,
                        width: 80,
                        height: 92
                    )
                    if !runtime.didDamageThisCommit && bossRect.intersects(playerRect) {
                        runtime.didDamageThisCommit = true
                        context.damageInbox.enqueue(
                            damage: 2,
                            sourceX: Double(runtime.node.position.x)
                        )
                    }

                case .volley:
                    runtime.attackTell.alpha = 0.65
                    runtime.statusLabel.text = "ASH VOLLEY"
                }

            case .recovery:
                runtime.attackTell.alpha = 0
                runtime.statusLabel.text = "RECOVER"
            }

            if !runtime.projectiles.isEmpty {
                for index in stride(from: runtime.projectiles.count - 1, through: 0, by: -1) {
                    let projectile = runtime.projectiles[index]
                    projectile.controller.update(dt: Double(dt))
                    projectile.node.position.x = CGFloat(projectile.controller.x)

                    if projectile.controller.isActive {
                        let projectileRect = CGRect(
                            x: projectile.node.position.x - 10,
                            y: projectile.node.position.y - 6,
                            width: 20,
                            height: 12
                        )
                        if projectileRect.intersects(playerRect),
                           projectile.controller.consumeOnPlayerContact() {
                            context.damageInbox.enqueue(
                                damage: projectile.controller.damage,
                                sourceX: Double(projectile.sourceX)
                            )
                        }
                    }

                    if projectile.node.position.x < physicalOriginX - 20 ||
                       projectile.node.position.x > physicalOriginX + roomWidth + 20 {
                        projectile.controller.deactivate()
                    }

                    if !projectile.controller.isActive {
                        projectile.node.removeFromParent()
                        runtime.projectiles.remove(at: index)
                    }
                }
            }
        }

        bossRoot.run(updateAction, withKey: "v21BossCombat")
    }

    private static func patternName(_ pattern: BossPattern?) -> String {
        guard let pattern else { return "" }
        switch pattern {
        case .slash: return "SLASH"
        case .charge: return "CHARGE"
        case .volley: return "VOLLEY"
        }
    }
}
