import Foundation

@inline(__always)
func expectEnemyArchetype(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct EnemyArchetypeTestsMain {
    static func main() {
        let grunt = EnemyArchetype.grunt.stats
        expectEnemyArchetype(grunt.maxHP == 3, "Grunt HP is 3")
        expectEnemyArchetype(grunt.contactDamage == 1, "Grunt damage is 1")
        expectEnemyArchetype(grunt.attackKind == .melee, "Grunt is melee")

        let runner = EnemyArchetype.runner.stats
        expectEnemyArchetype(runner.maxHP == 2, "Runner HP is 2")
        expectEnemyArchetype(runner.contactDamage == 1, "Runner damage is 1")
        expectEnemyArchetype(runner.chaseSpeed > grunt.chaseSpeed, "Runner chases faster than Grunt")
        expectEnemyArchetype(runner.detectionRange > grunt.detectionRange, "Runner detects farther than Grunt")
        expectEnemyArchetype(runner.knockbackSpeed > grunt.knockbackSpeed, "Runner has stronger hit knockback")

        let heavy = EnemyArchetype.heavy.stats
        expectEnemyArchetype(heavy.maxHP == 6, "Heavy HP is 6")
        expectEnemyArchetype(heavy.contactDamage == 2, "Heavy damage is 2")
        expectEnemyArchetype(heavy.chaseSpeed < grunt.chaseSpeed, "Heavy is slower than Grunt")
        expectEnemyArchetype(heavy.hitStunDuration < grunt.hitStunDuration, "Heavy has shorter hit stun")
        expectEnemyArchetype(heavy.knockbackSpeed < grunt.knockbackSpeed, "Heavy has weaker hit knockback")

        let ranged = EnemyArchetype.ranged.stats
        expectEnemyArchetype(ranged.maxHP == 3, "Ranged HP is 3")
        expectEnemyArchetype(ranged.contactDamage == 1, "Ranged projectile damage is 1")
        expectEnemyArchetype(ranged.attackKind == .projectile, "Ranged uses projectiles")
        expectEnemyArchetype(ranged.knockbackSpeed > grunt.knockbackSpeed, "Ranged has strong hit knockback")

        let boss = EnemyArchetype.boss.stats
        expectEnemyArchetype(boss.maxHP == 20, "Boss HP is 20")
        expectEnemyArchetype(boss.attackKind == .boss, "Boss uses boss attack controller")
        expectEnemyArchetype(boss.hitStunDuration < heavy.hitStunDuration, "Boss hit stun is shortest")
        expectEnemyArchetype(boss.knockbackSpeed < heavy.knockbackSpeed, "Boss knockback is weakest")

        print("EnemyArchetypeTests: PASS")
    }
}
