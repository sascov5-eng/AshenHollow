import SpriteKit
import UIKit

private final class V21LiveProjectile {
    let node: SKShapeNode
    var controller: ProjectileController
    let y: CGFloat
    let sourceX: CGFloat

    init(node: SKShapeNode, controller: ProjectileController, y: CGFloat, sourceX: CGFloat) {
        self.node = node
        self.controller = controller
        self.y = y
        self.sourceX = sourceX
    }
}

private final class V21LiveEnemy {
    let spawn: EnemySpawn
    let node: SKNode
    let body: SKShapeNode
    let hpFill: SKSpriteNode
    let stateLabel: SKLabelNode
    let attackVisual: SKShapeNode
    let stats: EnemyStats

    var model: EnemyRuntimeModel
    var ai: EnemyAIController
    var rangedCombat = RangedCombatController()
    var attackElapsed: TimeInterval?
    var currentAttackID: Int = 0
    var lastDamageAttackID: Int = -1
    var contactCooldown: TimeInterval = 0
    var defeatCounted = false

    init(
        spawn: EnemySpawn,
        node: SKNode,
        body: SKShapeNode,
        hpFill: SKSpriteNode,
        stateLabel: SKLabelNode,
        attackVisual: SKShapeNode,
        worldSpawnX: CGFloat
    ) {
        self.spawn = spawn
        self.node = node
        self.body = body
        self.hpFill = hpFill
        self.stateLabel = stateLabel
        self.attackVisual = attackVisual
        self.stats = spawn.archetype.stats
        self.model = EnemyRuntimeModel(archetype: spawn.archetype)
        self.ai = EnemyAIController(
            spawnX: Double(worldSpawnX),
            profile: EnemyAIProfile.from(stats: spawn.archetype.stats)
        )
    }
}

private final class V21NormalCombatRuntime {
    var enemies: [V21LiveEnemy] = []
    var projectiles: [V21LiveProjectile] = []
    var lastElapsed: CGFloat = 0
    var lastPlayerImpulseSwingID: Int = -1
}

enum MultiEnemyRuntimeInstaller {
    static func clear(from scene: SKScene) {
        scene.childNode(withName: "v21EnemyRoot")?.removeFromParent()
        scene.childNode(withName: "v21ProjectileRoot")?.removeFromParent()
    }

    static func spawn(
        spawns: [EnemySpawn],
        physicalOriginX: CGFloat,
        roomWidth: CGFloat,
        on scene: SKScene,
        context: V21RuntimeContext
    ) {
        clear(from: scene)

        guard let player = scene.childNode(withName: "player") else { return }

        let normalSpawns = spawns.filter { $0.archetype != .boss }
        guard !normalSpawns.isEmpty else { return }

        let enemyRoot = SKNode()
        enemyRoot.name = "v21EnemyRoot"
        enemyRoot.zPosition = 44
        scene.addChild(enemyRoot)

        let projectileRoot = SKNode()
        projectileRoot.name = "v21ProjectileRoot"
        projectileRoot.zPosition = 47
        scene.addChild(projectileRoot)

        let runtime = V21NormalCombatRuntime()

        for spawn in normalSpawns {
            let worldX = physicalOriginX + CGFloat(spawn.position.x)
            let presentation = makeEnemyNode(for: spawn)
            presentation.node.position = CGPoint(x: worldX, y: CGFloat(spawn.position.y))
            enemyRoot.addChild(presentation.node)

            runtime.enemies.append(
                V21LiveEnemy(
                    spawn: spawn,
                    node: presentation.node,
                    body: presentation.body,
                    hpFill: presentation.hpFill,
                    stateLabel: presentation.stateLabel,
                    attackVisual: presentation.attackVisual,
                    worldSpawnX: worldX
                )
            )
        }

        func spawnProjectile(from enemy: V21LiveEnemy, direction: CGFloat) {
            let shape = SKShapeNode(
                rectOf: CGSize(width: 18, height: 12),
                cornerRadius: 5
            )
            shape.fillColor = UIColor(red: 0.35, green: 0.88, blue: 1.0, alpha: 0.95)
            shape.strokeColor = UIColor(white: 1, alpha: 0.65)
            shape.lineWidth = 1.5
            shape.position = CGPoint(
                x: enemy.node.position.x + direction * 34,
                y: enemy.node.position.y + 8
            )
            projectileRoot.addChild(shape)

            let controller = ProjectileController(
                x: Double(shape.position.x),
                velocityX: Double(direction * 285),
                damage: enemy.stats.contactDamage,
                lifetime: 3.2
            )
            runtime.projectiles.append(
                V21LiveProjectile(
                    node: shape,
                    controller: controller,
                    y: shape.position.y,
                    sourceX: enemy.node.position.x
                )
            )
        }

        func emitPlayerImpact(on enemy: V21LiveEnemy) {
            context.focus.gainFromAcceptedMeleeHit()

            guard runtime.lastPlayerImpulseSwingID != context.playerAttackSequenceID,
                  let gameScene = scene as? GameScene else {
                return
            }

            runtime.lastPlayerImpulseSwingID = context.playerAttackSequenceID
            switch context.playerAttackDirection {
            case .down:
                gameScene.enqueueCombatImpulse(.pogo(verticalSpeed: 465))
            case .horizontal, .up:
                let away: Double = player.position.x >= enemy.node.position.x ? 1 : -1
                gameScene.enqueueCombatImpulse(.recoil(direction: away, speed: 240))
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
            let playerAttackRect: CGRect? = {
                guard playerHitboxActive else { return nil }
                let spec = context.playerAttackDirection.hitboxSpec(
                    facing: Double(player.xScale >= 0 ? 1 : -1)
                )
                let facingSign: CGFloat
                if let attackHitboxNode {
                    facingSign = attackHitboxNode.position.x == 0
                        ? 1
                        : (attackHitboxNode.position.x > 0 ? 1 : -1)
                } else {
                    facingSign = 1
                }
                let correctedOffsetX: CGFloat
                if context.playerAttackDirection == .horizontal {
                    correctedOffsetX = abs(CGFloat(spec.offsetX)) * facingSign
                } else {
                    correctedOffsetX = CGFloat(spec.offsetX) * facingSign
                }
                let center = CGPoint(
                    x: player.position.x + correctedOffsetX,
                    y: player.position.y + CGFloat(spec.offsetY)
                )
                return CGRect(
                    x: center.x - CGFloat(spec.width) * 0.5,
                    y: center.y - CGFloat(spec.height) * 0.5,
                    width: CGFloat(spec.width),
                    height: CGFloat(spec.height)
                )
            }()

            for enemy in runtime.enemies {
                guard enemy.model.isAlive else { continue }
                enemy.contactCooldown = max(0, enemy.contactCooldown - Double(dt))

                if let playerAttackRect,
                   playerAttackRect.intersects(hurtbox(for: enemy)) {
                    let accepted = enemy.model.applyPlayerHit(
                        damage: 1,
                        playerAttackID: context.playerAttackSequenceID,
                        playerX: Double(player.position.x),
                        enemyX: Double(enemy.node.position.x)
                    )
                    if accepted {
                        enemy.attackElapsed = nil
                        if enemy.spawn.archetype == .ranged {
                            enemy.rangedCombat = RangedCombatController()
                        }
                        enemy.model.markAttackDamageWindowActive(false)
                        enemy.attackVisual.alpha = 0
                        flash(enemy.body)
                        refreshHP(enemy)
                        emitPlayerImpact(on: enemy)

                        if !enemy.model.isAlive {
                            presentDeath(enemy, context: context)
                            continue
                        }
                    }
                }

                if enemy.model.isHitStunned {
                    enemy.stateLabel.text = "HIT"
                    enemy.attackVisual.alpha = 0
                    enemy.node.position.x += CGFloat(enemy.model.knockbackVelocity) * dt
                    enemy.node.position.x = max(
                        physicalOriginX + 28,
                        min(physicalOriginX + roomWidth - 28, enemy.node.position.x)
                    )
                    enemy.model.update(dt: Double(dt))
                    continue
                }

                enemy.model.update(dt: Double(dt))

                if enemy.contactCooldown <= 0,
                   hurtbox(for: enemy).intersects(playerRect) {
                    enemy.contactCooldown = 0.20
                    context.damageInbox.enqueue(
                        damage: enemy.stats.contactDamage,
                        sourceX: Double(enemy.node.position.x)
                    )
                }

                let verticalDistance = abs(player.position.y - enemy.node.position.y)

                if enemy.spawn.archetype == .ranged {
                    let delta = player.position.x - enemy.node.position.x
                    let directionToPlayer: Double = delta >= 0 ? 1 : -1
                    let horizontalDistance = abs(Double(delta))
                    let playerDetected = verticalDistance <= 95
                        && horizontalDistance <= enemy.stats.detectionRange
                    let controllerDistance = playerDetected
                        ? horizontalDistance
                        : enemy.stats.detectionRange + 1

                    let rangedOutput = enemy.rangedCombat.update(
                        dt: Double(dt),
                        distanceToPlayer: controllerDistance,
                        directionToPlayer: directionToPlayer
                    )
                    let rangedFacing: CGFloat = directionToPlayer >= 0 ? 1 : -1
                    enemy.attackVisual.position.x = rangedFacing * attackVisualOffset(for: .ranged)

                    switch rangedOutput.state {
                    case .aiming:
                        enemy.stateLabel.text = "AIM"
                        enemy.attackVisual.alpha = 0.70
                    case .recovery:
                        enemy.stateLabel.text = "RECOVER"
                        enemy.attackVisual.alpha = 0.16
                    case .retreating:
                        enemy.stateLabel.text = "EVADE"
                        enemy.attackVisual.alpha = 0
                        enemy.node.position.x += CGFloat(rangedOutput.movementDirection)
                            * CGFloat(enemy.stats.chaseSpeed * 0.72) * dt
                    case .tracking:
                        enemy.stateLabel.text = playerDetected ? "TRACK" : "IDLE"
                        enemy.attackVisual.alpha = 0
                        if playerDetected {
                            enemy.node.position.x += CGFloat(rangedOutput.movementDirection)
                                * CGFloat(enemy.stats.patrolSpeed) * dt
                        }
                    }

                    if rangedOutput.shouldFire {
                        spawnProjectile(from: enemy, direction: rangedFacing)
                    }

                    enemy.node.position.x = max(
                        physicalOriginX + 28,
                        min(physicalOriginX + roomWidth - 28, enemy.node.position.x)
                    )
                    continue
                }

                let sensedPlayerX: CGFloat = verticalDistance <= 95
                    ? player.position.x
                    : enemy.node.position.x + 1000

                let output = enemy.ai.update(
                    dt: Double(dt),
                    enemyX: Double(enemy.node.position.x),
                    playerX: Double(sensedPlayerX)
                )

                let facing: CGFloat = output.facing >= 0 ? 1 : -1
                enemy.attackVisual.position.x = facing * attackVisualOffset(for: enemy.spawn.archetype)
                enemy.currentAttackID = output.attackID

                if output.startedAttack {
                    enemy.attackElapsed = 0
                }

                if var attackElapsed = enemy.attackElapsed {
                    attackElapsed += Double(dt)
                    enemy.attackElapsed = attackElapsed
                    let window = damageWindow(for: enemy.spawn.archetype)
                    let active = attackElapsed >= window.start && attackElapsed <= window.end
                    enemy.model.markAttackDamageWindowActive(active)
                    enemy.attackVisual.alpha = active ? 1.0 : 0.30
                    enemy.stateLabel.text = active ? "STRIKE" : "WINDUP"

                    if active,
                       enemy.lastDamageAttackID != enemy.currentAttackID,
                       attackRect(for: enemy, facing: facing).intersects(playerRect) {
                        enemy.lastDamageAttackID = enemy.currentAttackID
                        context.damageInbox.enqueue(
                            damage: enemy.stats.contactDamage,
                            sourceX: Double(enemy.node.position.x)
                        )
                    }

                    if attackElapsed >= enemy.stats.attackDuration {
                        enemy.attackElapsed = nil
                        enemy.model.markAttackDamageWindowActive(false)
                        enemy.attackVisual.alpha = 0
                    }
                } else {
                    enemy.attackVisual.alpha = 0
                    enemy.node.position.x += CGFloat(output.moveDirection) * CGFloat(speed(for: output.state, enemy: enemy)) * dt
                    enemy.stateLabel.text = output.state.rawValue.uppercased()
                }

                enemy.node.position.x = max(
                    physicalOriginX + 28,
                    min(physicalOriginX + roomWidth - 28, enemy.node.position.x)
                )
            }

            if !runtime.projectiles.isEmpty {
                for index in stride(from: runtime.projectiles.count - 1, through: 0, by: -1) {
                    let projectile = runtime.projectiles[index]
                    projectile.controller.update(dt: Double(dt))
                    projectile.node.position.x = CGFloat(projectile.controller.x)

                    if projectile.controller.isActive {
                        let projectileRect = CGRect(
                            x: projectile.node.position.x - 9,
                            y: projectile.y - 6,
                            width: 18,
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

        enemyRoot.run(updateAction, withKey: "v21NormalCombat")
    }

    private static func makeEnemyNode(
        for spawn: EnemySpawn
    ) -> (
        node: SKNode,
        body: SKShapeNode,
        hpFill: SKSpriteNode,
        stateLabel: SKLabelNode,
        attackVisual: SKShapeNode
    ) {
        let node = SKNode()
        node.name = "enemy-\(spawn.id)-\(spawn.archetype.rawValue)"

        let size: CGSize
        let color: UIColor
        switch spawn.archetype {
        case .grunt:
            size = CGSize(width: 44, height: 62)
            color = UIColor(red: 0.58, green: 0.20, blue: 0.23, alpha: 1)
        case .runner:
            size = CGSize(width: 36, height: 54)
            color = UIColor(red: 0.92, green: 0.42, blue: 0.18, alpha: 1)
        case .heavy:
            size = CGSize(width: 58, height: 72)
            color = UIColor(red: 0.34, green: 0.18, blue: 0.48, alpha: 1)
        case .ranged:
            size = CGSize(width: 42, height: 60)
            color = UIColor(red: 0.18, green: 0.48, blue: 0.66, alpha: 1)
        case .boss:
            size = CGSize(width: 80, height: 92)
            color = .gray
        }

        let body = SKShapeNode(rectOf: size, cornerRadius: 9)
        body.fillColor = color
        body.strokeColor = UIColor(white: 1, alpha: 0.24)
        body.lineWidth = 2
        node.addChild(body)

        let maxHP = CGFloat(spawn.archetype.stats.maxHP)
        let background = SKSpriteNode(
            color: UIColor(white: 0.04, alpha: 0.88),
            size: CGSize(width: max(48, size.width + 8), height: 7)
        )
        background.position = CGPoint(x: 0, y: size.height * 0.5 + 12)
        node.addChild(background)

        let fillWidth = max(44, size.width + 4)
        let hpFill = SKSpriteNode(
            color: UIColor(red: 0.90, green: 0.24, blue: 0.20, alpha: 1),
            size: CGSize(width: fillWidth, height: 4)
        )
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(
            x: -fillWidth * 0.5,
            y: size.height * 0.5 + 12
        )
        hpFill.userData = NSMutableDictionary()
        hpFill.userData?["maxHP"] = NSNumber(value: Double(maxHP))
        node.addChild(hpFill)

        let typeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        typeLabel.text = spawn.archetype.rawValue.uppercased()
        typeLabel.fontSize = 9
        typeLabel.fontColor = UIColor(white: 0.95, alpha: 0.88)
        typeLabel.position = CGPoint(x: 0, y: size.height * 0.5 + 25)
        typeLabel.verticalAlignmentMode = .center
        node.addChild(typeLabel)

        let stateLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        stateLabel.text = "IDLE"
        stateLabel.fontSize = 8
        stateLabel.fontColor = UIColor(white: 0.82, alpha: 0.72)
        stateLabel.position = CGPoint(x: 0, y: size.height * 0.5 + 37)
        stateLabel.verticalAlignmentMode = .center
        node.addChild(stateLabel)

        let attackVisual = SKShapeNode(
            rectOf: attackVisualSize(for: spawn.archetype),
            cornerRadius: 7
        )
        attackVisual.fillColor = UIColor(red: 1.0, green: 0.12, blue: 0.08, alpha: 0.20)
        attackVisual.strokeColor = UIColor(red: 1.0, green: 0.42, blue: 0.25, alpha: 0.90)
        attackVisual.lineWidth = 2
        attackVisual.alpha = 0
        node.addChild(attackVisual)

        return (node, body, hpFill, stateLabel, attackVisual)
    }

    private static func refreshHP(_ enemy: V21LiveEnemy) {
        let maxHP = max(1, enemy.stats.maxHP)
        enemy.hpFill.xScale = CGFloat(enemy.model.hp) / CGFloat(maxHP)
    }

    private static func flash(_ body: SKShapeNode) {
        body.removeAction(forKey: "v21HitFlash")
        let original = body.fillColor
        let sequence = SKAction.sequence([
            SKAction.run { body.fillColor = .white },
            SKAction.wait(forDuration: 0.055),
            SKAction.run { body.fillColor = original }
        ])
        body.run(sequence, withKey: "v21HitFlash")
    }

    private static func presentDeath(_ enemy: V21LiveEnemy, context: V21RuntimeContext) {
        guard !enemy.defeatCounted else { return }
        enemy.defeatCounted = true
        context.combatStatus.markEnemyDefeated()
        enemy.attackVisual.alpha = 0
        enemy.stateLabel.text = "DEAD"
        let death = SKAction.group([
            SKAction.fadeOut(withDuration: 0.22),
            SKAction.scale(to: 0.72, duration: 0.22)
        ])
        enemy.node.run(death)
    }

    private static func hurtbox(for enemy: V21LiveEnemy) -> CGRect {
        let size: CGSize
        switch enemy.spawn.archetype {
        case .runner: size = CGSize(width: 34, height: 52)
        case .heavy: size = CGSize(width: 56, height: 70)
        case .ranged: size = CGSize(width: 40, height: 58)
        case .grunt: size = CGSize(width: 40, height: 60)
        case .boss: size = CGSize(width: 78, height: 90)
        }
        return CGRect(
            x: enemy.node.position.x - size.width * 0.5,
            y: enemy.node.position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }

    private static func attackVisualSize(for archetype: EnemyArchetype) -> CGSize {
        switch archetype {
        case .heavy: return CGSize(width: 78, height: 48)
        case .runner: return CGSize(width: 54, height: 34)
        case .ranged: return CGSize(width: 30, height: 24)
        case .grunt: return CGSize(width: 58, height: 38)
        case .boss: return CGSize(width: 100, height: 58)
        }
    }

    private static func attackVisualOffset(for archetype: EnemyArchetype) -> CGFloat {
        switch archetype {
        case .heavy: return 58
        case .runner: return 46
        case .grunt: return 50
        case .ranged: return 34
        case .boss: return 68
        }
    }

    private static func attackRect(for enemy: V21LiveEnemy, facing: CGFloat) -> CGRect {
        let size = attackVisualSize(for: enemy.spawn.archetype)
        let centerX = enemy.node.position.x + facing * attackVisualOffset(for: enemy.spawn.archetype)
        return CGRect(
            x: centerX - size.width * 0.5,
            y: enemy.node.position.y - size.height * 0.5 + 2,
            width: size.width,
            height: size.height
        )
    }

    private static func damageWindow(for archetype: EnemyArchetype) -> (start: TimeInterval, end: TimeInterval) {
        switch archetype {
        case .runner: return (0.07, 0.15)
        case .heavy: return (0.24, 0.36)
        case .grunt: return (0.10, 0.20)
        case .ranged: return (0, 0)
        case .boss: return (0, 0)
        }
    }

    private static func speed(for state: EnemyAIState, enemy: V21LiveEnemy) -> Double {
        switch state {
        case .idle, .attack: return 0
        case .patrol: return enemy.ai.profile.patrolSpeed
        case .chase: return enemy.ai.profile.chaseSpeed
        }
    }
}
