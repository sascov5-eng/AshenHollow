import SpriteKit
import UIKit

private final class EnemyAIRuntime {
    var controller: EnemyAIController
    var lastElapsed: CGFloat = 0

    init(spawnX: CGFloat) {
        controller = EnemyAIController(spawnX: Double(spawnX))
    }
}

enum EnemyAIInstaller {
    static func install(on scene: SKScene) {
        guard let enemy = scene.childNode(withName: "testEnemy"),
              let player = scene.childNode(withName: "player") else {
            return
        }

        enemy.removeAction(forKey: "enemyAI")
        enemy.childNode(withName: "enemyAIState")?.removeFromParent()
        enemy.childNode(withName: "enemyAttackVisual")?.removeFromParent()

        // Put the first AI enemy far enough away to visibly demonstrate idle/patrol
        // before the player enters its detection range.
        enemy.position.x = 520

        let stateLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        stateLabel.name = "enemyAIState"
        stateLabel.text = "IDLE"
        stateLabel.fontSize = 10
        stateLabel.fontColor = UIColor(red: 1.0, green: 0.72, blue: 0.45, alpha: 0.92)
        stateLabel.horizontalAlignmentMode = .center
        stateLabel.verticalAlignmentMode = .center
        stateLabel.position = CGPoint(x: 0, y: 74)
        stateLabel.zPosition = 8
        enemy.addChild(stateLabel)

        let attackVisual = SKShapeNode(
            rectOf: CGSize(width: 58, height: 38),
            cornerRadius: 8
        )
        attackVisual.name = "enemyAttackVisual"
        attackVisual.fillColor = UIColor(red: 1.0, green: 0.10, blue: 0.08, alpha: 0.18)
        attackVisual.strokeColor = UIColor(red: 1.0, green: 0.28, blue: 0.18, alpha: 0.88)
        attackVisual.lineWidth = 2
        attackVisual.position = CGPoint(x: -50, y: 2)
        attackVisual.zPosition = 7
        attackVisual.alpha = 0
        enemy.addChild(attackVisual)

        let runtime = EnemyAIRuntime(spawnX: enemy.position.x)

        let aiAction = SKAction.customAction(withDuration: 1_000_000) { node, elapsed in
            guard let liveScene = node.scene,
                  let livePlayer = liveScene.childNode(withName: "player") else {
                return
            }

            if node.action(forKey: "death") != nil || node.alpha < 0.98 || node.isHidden {
                stateLabel.text = "DEAD"
                attackVisual.alpha = 0
                return
            }

            let dt: CGFloat
            if runtime.lastElapsed == 0 {
                dt = 1.0 / 60.0
            } else {
                dt = min(max(elapsed - runtime.lastElapsed, 0), 1.0 / 30.0)
            }
            runtime.lastElapsed = elapsed

            // Ignore the player while they are well above/below the ground enemy.
            // This keeps the first AI from swinging at a player on an overhead platform.
            let verticalDistance = abs(livePlayer.position.y - node.position.y)
            let sensedPlayerX: CGFloat = verticalDistance <= 90
                ? livePlayer.position.x
                : node.position.x + 1000

            let output = runtime.controller.update(
                dt: Double(dt),
                enemyX: Double(node.position.x),
                playerX: Double(sensedPlayerX)
            )

            let speed: CGFloat
            switch output.state {
            case .idle, .attack:
                speed = 0
            case .patrol:
                speed = 72
            case .chase:
                speed = 138
            }

            node.position.x += CGFloat(output.moveDirection) * speed * dt
            node.position.x = max(48, min(liveScene.size.width * 3.2 - 48, node.position.x))

            let facing = CGFloat(output.facing)
            attackVisual.position = CGPoint(x: facing * 50, y: 2)
            attackVisual.alpha = output.isAttackSwingActive ? 1 : 0
            stateLabel.text = output.state.rawValue.uppercased()

            if output.startedAttack {
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.08, duration: 0.05),
                    SKAction.scale(to: 1.0, duration: 0.10)
                ])
                node.run(pulse, withKey: "enemyAttackPulse")
            }
        }

        enemy.run(aiAction, withKey: "enemyAI")
    }
}
