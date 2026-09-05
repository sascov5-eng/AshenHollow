import Foundation
import CoreGraphics

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct V14LogicTests {
    static func main() {
        let layout = TestLocationLayout.v14
        expect(layout.checkpoints.count == 4, "expected four checkpoints")
        expect(Set(layout.movingPlatforms.map(\.axis)) == Set([.horizontal, .vertical]), "expected horizontal and vertical moving platform")
        expect(Set(layout.enemies.map(\.kind)).isSuperset(of: [.groundPatrol, .flying, .aggressive]), "missing enemy kind")
        expect(layout.interactions.contains(where: { $0.kind == .lever }), "missing normal lever")
        expect(layout.interactions.contains(where: { $0.kind == .door }), "missing normal door")
        expect(layout.interactions.contains(where: { $0.kind == .shortcutLever }), "missing shortcut lever")
        expect(layout.interactions.contains(where: { $0.kind == .shortcutDoor }), "missing shortcut door")
        expect(layout.interactions.contains(where: { $0.kind == .breakableWall }), "missing breakable wall")
        expect(layout.interactions.contains(where: { $0.kind == .hiddenPassage }), "missing hidden passage")
        expect(Set(layout.tutorials.map(\.mechanic)).isSuperset(of: TestLocationSpec.requiredTutorialMechanics), "tutorial coverage incomplete")

        let issues = TraversalReachabilityValidator.validate(layout: layout, tuning: .current)
        expect(issues.isEmpty, "reachability issues: \(issues)")

        let session = TestSessionState()
        session.completedTutorials.insert(.jump)
        session.openedInteractions.insert("door-main")
        session.destroyedSecrets.insert("secret-wall")
        session.enemyStates["enemy-ground"] = EnemyRuntimeSnapshot(hp: 1, isAlive: true, position: CGPoint(x: 3500, y: 130))
        let player = PlayerResourceState(hp: 2, maxHP: 5, light: 68)
        let activation = CheckpointController.activate(id: "cp2", playerState: player, session: session, layout: layout)
        expect(activation?.player.hp == 5, "checkpoint should restore HP")
        expect(activation?.player.light == 68, "checkpoint should preserve LIGHT")
        expect(session.enemyStates["enemy-ground"]?.hp == 1, "checkpoint must not reset enemies")
        expect(session.completedTutorials.contains(.jump), "checkpoint must preserve tutorials")
        expect(session.openedInteractions.contains("door-main"), "checkpoint must preserve door")
        expect(session.destroyedSecrets.contains("secret-wall"), "checkpoint must preserve secret")

        let tracker = SafePositionTracker()
        tracker.update(candidate: CGPoint(x: 100, y: 100), isGrounded: false, isSafe: true, isDashing: false, isWallSliding: false, edgeSafe: true)
        expect(tracker.safePosition == nil, "airborne position must not become safe")
        tracker.update(candidate: CGPoint(x: 120, y: 130), isGrounded: true, isSafe: true, isDashing: false, isWallSliding: false, edgeSafe: true)
        expect(tracker.safePosition == CGPoint(x: 120, y: 130), "ground safe point not recorded")

        let spike = RespawnController.spikeRecovery(currentHP: 3, safePosition: CGPoint(x: 120, y: 130), checkpointPosition: CGPoint(x: 20, y: 130))
        expect(spike.hp == 2 && !spike.resetsEnemies, "spike recovery semantics wrong")
        let lethalSpike = RespawnController.spikeRecovery(currentHP: 1, safePosition: CGPoint(x: 120, y: 130), checkpointPosition: CGPoint(x: 20, y: 130))
        expect(lethalSpike.hp == 5 && lethalSpike.resetsEnemies, "lethal spike should use death recovery")

        let tutorialSession = TestSessionState()
        let tutorial = DeveloperTutorialController(layout: layout, session: tutorialSession)
        tutorial.update(playerPosition: CGPoint(x: 500, y: 130))
        expect(tutorial.presentation?.mechanic == .jump, "jump hint not presented")
        tutorial.register(action: .jump)
        expect(tutorial.presentation == nil && tutorialSession.completedTutorials.contains(.jump), "jump hint not dismissed on action")

        let movingSpec = layout.movingPlatforms.first(where: { $0.axis == .horizontal })!
        let moving = MovingPlatformController(spec: movingSpec)
        let delta = moving.update(dt: 0.5)
        expect(delta.dx > 0 && delta.dy == 0, "horizontal moving platform delta wrong")

        let enemySpec = layout.enemies.first(where: { $0.id == "enemy-ground" })!
        let enemy = TestEnemyController(spec: enemySpec)
        expect(enemy.receiveMeleeHit(), "melee hit should be accepted")
        expect(enemy.hp == enemySpec.maxHP - 1, "enemy hp did not decrease")
        let beforeKnockback = enemy.position
        enemy.applyMeleeKnockback(fromX: beforeKnockback.x - 50, force: 200, stun: 0.12)
        let knockbackStep = enemy.update(dt: 0.05, playerPosition: CGPoint(x: beforeKnockback.x - 50, y: beforeKnockback.y))
        expect(knockbackStep.position.x > beforeKnockback.x, "melee knockback should push enemy away from attacker")
        let duringStun = knockbackStep.position.x
        let secondKnockbackStep = enemy.update(dt: 0.05, playerPosition: CGPoint(x: beforeKnockback.x - 50, y: beforeKnockback.y))
        expect(secondKnockbackStep.position.x > duringStun, "knockback momentum should continue during hit stun")

        var damage = PlayerDamageController()
        let firstHit = damage.takeHit(from: 0, playerX: 100)
        expect(firstHit?.hpLoss == 1, "enemy hit must deal one hp")
        expect(damage.takeHit(from: 0, playerX: 100) == nil, "i-frames should reject immediate repeated hit")

        let interactions = TestInteractionController(layout: layout, session: session)
        expect(interactions.activateLever(id: "lever-door"), "normal lever failed")
        expect(interactions.isOpen("door-main"), "normal door did not open")
        expect(interactions.activateLever(id: "shortcut-lever"), "shortcut lever failed")
        expect(interactions.isOpen("shortcut-door"), "shortcut did not open")
        expect(interactions.attackSecretWall(id: "secret-wall"), "secret wall attack failed")
        expect(interactions.isSecretDestroyed("secret-wall"), "secret wall state not persisted")

        var life = PlayerLifeStateController()
        life.registerDamage(isLethal: false)
        if case .hurt = life.state {} else { expect(false, "hurt state missing") }
        life.registerDamage(isLethal: true)
        expect(life.state == .dead, "death state missing")
        life.respawn()
        expect(life.state == .normal, "respawn should restore normal life state")

        print("PASS: v1.4 logic tests + v1.6 enemy feedback")
    }
}
