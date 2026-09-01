import SpriteKit
import UIKit

private final class PlayerDamageRuntime {
    var lastElapsed: CGFloat = 0
    var deathPresented = false
}

enum PlayerDamageInstaller {
    static func install(on scene: SKScene, context: V21RuntimeContext) {
        guard let player = scene.childNode(withName: "player"),
              let camera = scene.camera else {
            return
        }

        player.removeAction(forKey: "playerDamageRuntime")
        player.removeAction(forKey: "playerIFrameBlink")
        camera.childNode(withName: "playerHealthHUD")?.removeFromParent()
        context.damageInbox.clear()

        let hud = SKNode()
        hud.name = "playerHealthHUD"
        hud.zPosition = 1200
        hud.position = CGPoint(
            x: -scene.size.width * 0.5 + 104,
            y: scene.size.height * 0.5 - 54
        )

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.name = "playerHealthLabel"
        title.text = "PLAYER  HP 5/5"
        title.fontSize = 13
        title.fontColor = UIColor(white: 0.96, alpha: 0.95)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 29)
        hud.addChild(title)

        let background = SKSpriteNode(
            color: UIColor(white: 0.06, alpha: 0.88),
            size: CGSize(width: 126, height: 13)
        )
        background.position = CGPoint(x: 0, y: 14)
        hud.addChild(background)

        let fill = SKSpriteNode(
            color: UIColor(red: 0.26, green: 0.78, blue: 0.88, alpha: 1),
            size: CGSize(width: 120, height: 7)
        )
        fill.name = "playerHealthFill"
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -60, y: 14)
        fill.zPosition = 1
        hud.addChild(fill)

        let essenceLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        essenceLabel.name = "essenceLabel"
        essenceLabel.text = "ESSENCE  0/100"
        essenceLabel.fontSize = 10
        essenceLabel.fontColor = UIColor(red: 0.72, green: 0.90, blue: 1.0, alpha: 0.95)
        essenceLabel.horizontalAlignmentMode = .center
        essenceLabel.verticalAlignmentMode = .center
        essenceLabel.position = CGPoint(x: 0, y: -2)
        hud.addChild(essenceLabel)

        let essenceBackground = SKSpriteNode(
            color: UIColor(white: 0.05, alpha: 0.88),
            size: CGSize(width: 126, height: 9)
        )
        essenceBackground.position = CGPoint(x: 0, y: -15)
        hud.addChild(essenceBackground)

        let essenceFill = SKSpriteNode(
            color: UIColor(red: 0.36, green: 0.72, blue: 1.0, alpha: 1),
            size: CGSize(width: 120, height: 5)
        )
        essenceFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        essenceFill.position = CGPoint(x: -60, y: -15)
        essenceFill.zPosition = 1
        essenceFill.xScale = 0
        hud.addChild(essenceFill)

        let focusBackground = SKSpriteNode(
            color: UIColor(white: 0.05, alpha: 0.75),
            size: CGSize(width: 126, height: 6)
        )
        focusBackground.position = CGPoint(x: 0, y: -27)
        hud.addChild(focusBackground)

        let focusFill = SKSpriteNode(
            color: UIColor(white: 0.95, alpha: 0.95),
            size: CGSize(width: 120, height: 3)
        )
        focusFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        focusFill.position = CGPoint(x: -60, y: -27)
        focusFill.zPosition = 1
        focusFill.xScale = 0
        hud.addChild(focusFill)

        camera.addChild(hud)

        let runtime = PlayerDamageRuntime()
        let respawnSequence = PlayerRespawnSequence()

        func refreshHUD() {
            let health = context.vitals.health
            let ratio = CGFloat(health.hp) / CGFloat(health.maxHP)
            fill.xScale = max(0, ratio)

            if health.isAlive {
                title.text = "PLAYER  HP \(health.hp)/\(health.maxHP)"
                title.fontColor = UIColor(white: 0.96, alpha: 0.95)
            } else {
                title.text = "PLAYER  DEAD"
                title.fontColor = UIColor(red: 1.0, green: 0.32, blue: 0.28, alpha: 1)
            }

            essenceLabel.text = "ESSENCE  \(context.focus.essence)/\(context.focus.maxEssence)"
            essenceFill.xScale = CGFloat(context.focus.essence) / CGFloat(context.focus.maxEssence)
            focusFill.xScale = CGFloat(context.focus.focusProgress)
            focusFill.alpha = context.focus.isFocusing ? 1 : 0.28
        }

        func beginDeathAndRespawn() {
            guard !runtime.deathPresented else { return }
            runtime.deathPresented = true
            context.damageInbox.clear()
            context.focus.cancelFocus()
            context.hitStop.reset()
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
            context.vitals.update(Double(dt))
            refreshHUD()

            guard context.vitals.health.isAlive else {
                beginDeathAndRespawn()
                return
            }

            let events = context.damageInbox.drain()
            guard !events.isEmpty else { return }

            for event in events {
                guard context.vitals.applyDamage(
                    damage: event.damage,
                    attackID: event.token
                ) else {
                    continue
                }

                context.focus.cancelFocus()
                refreshHUD()

                let sourceX = CGFloat(event.sourceX)
                let knockbackDirection: Double = node.position.x >= sourceX ? 1 : -1
                if let gameScene = scene as? GameScene {
                    gameScene.enqueueCombatImpulse(
                        .recoil(direction: knockbackDirection, speed: 265)
                    )
                }

                node.removeAction(forKey: "playerIFrameBlink")

                if context.vitals.health.isAlive {
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
                    break
                }
            }
        }

        player.run(damageRuntime, withKey: "playerDamageRuntime")
    }

    static func install(on scene: SKScene) {
        scene.userData = scene.userData ?? NSMutableDictionary()
        let context: V21RuntimeContext
        if let existing = V21RuntimeBootstrap.context(from: scene) {
            context = existing
        } else {
            context = V21RuntimeContext()
            scene.userData?["v21RuntimeContext"] = context
        }
        install(on: scene, context: context)
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
            V21RuntimeBootstrap.install(on: replacement)

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
