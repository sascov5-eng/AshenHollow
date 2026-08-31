import Foundation

@inline(__always)
func expectEnemyRuntime(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct EnemyRuntimeModelTestsMain {
    static func main() {
        var first = EnemyRuntimeModel(archetype: .grunt)
        var second = EnemyRuntimeModel(archetype: .grunt)

        expectEnemyRuntime(first.hp == 3 && second.hp == 3, "Grunts start with independent 3 HP")

        first.markAttackDamageWindowActive(true)
        expectEnemyRuntime(
            first.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 10),
            "First enemy accepts the first player swing"
        )
        expectEnemyRuntime(first.hp == 2, "First enemy loses exactly 1 HP")
        expectEnemyRuntime(first.hitStunRemaining > 0, "Accepted hit starts hit stun")
        expectEnemyRuntime(first.knockbackVelocity > 0, "Enemy to player's right is knocked right")
        expectEnemyRuntime(!first.isAttackDamageWindowActive, "Normal enemy active damage window is interrupted")

        expectEnemyRuntime(
            !first.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 10),
            "Same player attack ID cannot damage the same enemy twice"
        )
        expectEnemyRuntime(first.hp == 2, "Duplicate swing does not change first enemy HP")

        expectEnemyRuntime(
            second.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 20),
            "A different enemy independently accepts the same player swing"
        )
        expectEnemyRuntime(second.hp == 2, "Second enemy keeps independent HP")

        first.update(dt: first.hitStunRemaining + 0.01)
        expectEnemyRuntime(!first.isHitStunned, "Hit stun expires after its duration")

        var leftEnemy = EnemyRuntimeModel(archetype: .runner)
        _ = leftEnemy.applyPlayerHit(damage: 1, playerAttackID: 1, playerX: 100, enemyX: 80)
        expectEnemyRuntime(leftEnemy.knockbackVelocity < 0, "Enemy left of player is knocked left")

        var heavy = EnemyRuntimeModel(archetype: .heavy)
        _ = heavy.applyPlayerHit(damage: 1, playerAttackID: 1, playerX: 0, enemyX: 10)
        expectEnemyRuntime(
            abs(heavy.knockbackVelocity) < abs(first.archetype.stats.knockbackSpeed),
            "Heavy knockback is weaker than Grunt"
        )

        var boss = EnemyRuntimeModel(archetype: .boss)
        boss.markAttackDamageWindowActive(true)
        _ = boss.applyPlayerHit(damage: 1, playerAttackID: 1, playerX: 0, enemyX: 10)
        expectEnemyRuntime(boss.isAttackDamageWindowActive, "Boss hit does not automatically cancel committed damage window")

        print("EnemyRuntimeModelTests: PASS")
    }
}
