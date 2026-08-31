import SpriteKit
import UIKit

private final class PlayerDamageRuntime {
    var health = PlayerHealth(maxHP: 5, invulnerabilityDuration: 0.65)
    var lastElapsed: CGFloat = 0
    var deathPresented = false
}

enum PlayerDamageInstaller {
    static func install(on scene: SKScene) {
        guard let player = scene.childNode(withName: "player"),
              let enemy = scene.childNode(withName: "testEnemy"),
              let camera = scene.camera else {
            return
        }

        player.removeAction(forKey: "playerDamageRuntime")
        player.removeAction(forKey: "playerIFrameBlink")
        camera.childNode(withName: "playerHealthHUD")?.removeFromParent()

        let hud = SKNode()
        hud.name = "playerHealthHUD"
        hud.zPosition = 1200
        hud.position = CGPoint(
            x: -scene.size.width * 0.5 + 100,
            y: scene.size.height * 0.5 - 48
        )

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.name = "playerHealthLabel"
        title.text = "PLAYER  HP 5/5"
        title.fontSize = 13
        title.fontColor = UIColor(white: 0.96, alpha: 0.95)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 15)
        hud.addChild(title)

        let background = SKSpriteNode(
            color: UIColor(white: 0.06, alpha: 0.88),
            size: CGSize(width: 126, height: 13)
        )
        background.position = .zero
        hud.addChild(background)

        let fill = SKSpriteNode(
            color: UIColor(red: 0.26, green: 0.78, blue: 0.88, alpha: 1),
            size: CGSize(width: 120, height: 7)
        )
        fill.name = "playerHealthFill"
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -60, y: 0)
        fill.zPosition = 1
        hud.addChild(fill)

        camera.addChild(hud)

        let runtime = PlayerDamageRuntime()
        let respawnSequence = PlayerRespawnSequence()

        func refreshHUD() {
            let ratio = CGFloat(runtime.health.hp) / CGFloat(runtime.health.maxHP)
            fill.xScale = max(0, ratio)
            if runtime.health.isAlive {
                title.text = "PLAYER  HP \(runtime.health.hp)/\(runtime.health.maxHP)"
                title.fontColor = UIColor(white: 0.96, alpha: 0.95)
            } else {
                title.text = "PLAYER  DEAD"
                title.fontColor = UIColor(red: 1.0, green: 0.32, blue: 0.28, alpha: 1)
            }
        }

        func beginDeathAndRespawn() {
            guard !runtime.deathPresented else { return }
            runtime.deathPresented = true
            player.removeAction(forKey: "playerIFrameBlink")
            player.alpha = 0.38
            refreshHUD()
            startRespawnTransition(
                from: scene,
                sequence: respawnSequence
            )
        }

        refreshHUD()

        let damageRuntime = SKAction.customAction(withDuration: 1_000_000) { node, elapsed in
            let dt: CGFloat
            if runtime.lastElapsed == 0 {
                dt = 1.0 / 60.0
            } else {
                dt = min(max(elapsed - runtime.lastElapsed, 0), 1.0 / 30.0)
            }
            runtime.lastElapsed = elapsed
            runtime.health.update(Double(dt))

            guard runtime.health.isAlive else {
                beginDeathAndRespawn()
                return
            }

            guard enemy.action(forKey: "death") == nil,
                  enemy.alpha >= 0.98,
                  !enemy.isHidden,
                  let userData = enemy.userData,
                  (userData["enemyAttackActive"] as? NSNumber)?.boolValue == true,
                  let attackID = (userData["enemyAttackID"] as? NSNumber)?.intValue,
                  attackID > 0,
                  let facingNumber = userData["enemyAttackFacing"] as? NSNumber else {
                return
            }

            let facing: CGFloat = facingNumber.doubleValue >= 0 ? 1 : -1
            let attackCenter = CGPoint(
                x: enemy.position.x + facing * 50,
                y: enemy.position.y + 2
            )
            let attackRect = CGRect(
                x: attackCenter.x - 29,
                y: attackCenter.y - 19,
                width: 58,
                height: 38
            )
            let playerRect = CGRect(
                x: node.position.x - 18,
                y: node.position.y - 30,
                width: 36,
                height: 60
            )

            guard attackRect.intersects(playerRect),
                  runtime.health.applyHit(damage: 1, attackID: attackID) else {
                return
            }

            refreshHUD()

            let knockbackDirection: CGFloat = node.position.x >= enemy.position.x ? 1 : -1
            let targetX = node.position.x + knockbackDirection * 34
            let worldMaxX = max(18, scene.size.width * 3.2 - 18)
            node.position.x = max(18, min(worldMaxX, targetX))

            node.removeAction(forKey: "playerIFrameBlink")

            if runtime.health.isAlive {
                let blink = SKAction.repeat(
                    SKAction.sequence([
                        SKAction.fadeAlpha(to: 0.34, duration: 0.055),
                        SKAction.fadeAlpha(to: 1.0, duration: 0.055)
                    ]),
                    count: 4
                )
                node.run(blink, withKey: "playerIFrameBlink")
            } else {
                beginDeathAndRespawn()
            }
        }

        player.run(damageRuntime, withKey: "playerDamageRuntime")
    }

    private static func startRespawnTransition(
        from scene: SKScene,
        sequence: PlayerRespawnSequence
    ) {
        guard let skView = scene.view else { return }

        scene.isPaused = true
        skView.isUserInteractionEnabled = false

        let blackout = UIView(frame: skView.bounds)
        blackout.backgroundColor = .black
        blackout.alpha = 0
        blackout.isUserInteractionEnabled = true
        blackout.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.addSubview(blackout)
        skView.bringSubviewToFront(blackout)

        UIView.animate(
            withDuration: sequence.fadeOutDuration,
            delay: sequence.deathPauseDuration,
            options: [.curveEaseInOut, .beginFromCurrentState]
        ) {
            blackout.alpha = 1
        } completion: { _ in
            let replacement = GameScene(size: scene.size)
            replacement.scaleMode = scene.scaleMode
            skView.presentScene(replacement)

            EnemyAIInstaller.install(on: replacement)
            PlayerDamageInstaller.install(on: replacement)
            RoomRuntimeInstaller.install(on: replacement)

            UIView.animate(
                withDuration: sequence.fadeInDuration,
                delay: sequence.blackHoldDuration,
                options: [.curveEaseInOut, .beginFromCurrentState]
            ) {
                blackout.alpha = 0
            } completion: { _ in
                blackout.removeFromSuperview()
                skView.isUserInteractionEnabled = true
            }
        }
    }
}
