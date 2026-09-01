import SpriteKit

@MainActor
enum CombatFeedback {
    static func presentAcceptedMeleeHit(
        on scene: SKScene,
        context: V21RuntimeContext,
        duration: TimeInterval = 0.045
    ) {
        let safeDuration = max(0.02, duration)
        context.hitStop.request(duration: safeDuration)

        let roots = [
            scene.childNode(withName: "v21EnemyRoot"),
            scene.childNode(withName: "v21ProjectileRoot"),
            scene.childNode(withName: "v21BossRoot"),
            scene.childNode(withName: "v21BossProjectileRoot")
        ].compactMap { $0 }

        for root in roots {
            root.speed = 0
        }

        scene.removeAction(forKey: "v22CombatHitStopRestore")
        scene.run(
            SKAction.sequence([
                SKAction.wait(forDuration: safeDuration),
                SKAction.run {
                    for root in roots {
                        root.speed = 1
                    }
                    context.hitStop.reset()
                }
            ]),
            withKey: "v22CombatHitStopRestore"
        )

        if let camera = scene.camera {
            camera.removeAction(forKey: "v22CombatShake")
            let shake = SKAction.sequence([
                SKAction.moveBy(x: 3.0, y: 1.5, duration: 0.018),
                SKAction.moveBy(x: -5.0, y: -2.5, duration: 0.022),
                SKAction.moveBy(x: 2.0, y: 1.0, duration: 0.018)
            ])
            camera.run(shake, withKey: "v22CombatShake")
        }
    }
}
