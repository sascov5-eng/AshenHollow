import Foundation

@inline(__always)
func expectAI(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct EnemyAIControllerTests {
    static func main() {
        // Compatibility baseline: Grunt-equivalent V17 behavior remains unchanged.
        var ai = EnemyAIController(spawnX: 500)

        var output = ai.update(dt: 0.10, enemyX: 500, playerX: 1000)
        expectAI(output.state == .idle, "enemy starts idle")
        expectAI(output.moveDirection == 0, "idle enemy does not move")

        output = ai.update(dt: 0.50, enemyX: 500, playerX: 1000)
        expectAI(output.state == .patrol, "enemy enters patrol after idle delay")
        expectAI(output.moveDirection == 1, "patrol begins to the right")

        output = ai.update(dt: 0.02, enemyX: 500, playerX: 680)
        expectAI(output.state == .chase, "enemy chases player inside detection range")
        expectAI(output.moveDirection == 1, "enemy chases toward player")

        output = ai.update(dt: 0.02, enemyX: 500, playerX: 455)
        expectAI(output.state == .attack, "enemy attacks player inside attack range")
        expectAI(output.moveDirection == 0, "enemy stops while attacking")
        expectAI(output.facing == -1, "enemy faces player before attack")
        expectAI(output.startedAttack, "first attack emits a start pulse")
        let firstAttackID = output.attackID

        output = ai.update(dt: 0.02, enemyX: 500, playerX: 455)
        expectAI(output.state == .attack, "enemy remains in attack state at close range")
        expectAI(!output.startedAttack, "same cooldown does not retrigger attack")
        expectAI(output.attackID == firstAttackID, "attack id remains stable during cooldown")

        _ = ai.update(dt: 0.90, enemyX: 500, playerX: 455)
        output = ai.update(dt: 0.02, enemyX: 500, playerX: 455)
        expectAI(output.startedAttack, "enemy attacks again after cooldown")
        expectAI(output.attackID == firstAttackID + 1, "new attack receives a new id")

        let gruntProfile = EnemyAIProfile.from(stats: EnemyArchetype.grunt.stats)
        let runnerProfile = EnemyAIProfile.from(stats: EnemyArchetype.runner.stats)
        let heavyProfile = EnemyAIProfile.from(stats: EnemyArchetype.heavy.stats)

        expectAI(runnerProfile.detectionRange > gruntProfile.detectionRange, "Runner detects farther than Grunt")
        expectAI(runnerProfile.chaseSpeed > gruntProfile.chaseSpeed, "Runner profile is faster than Grunt")
        expectAI(heavyProfile.chaseSpeed < gruntProfile.chaseSpeed, "Heavy profile is slower than Grunt")
        expectAI(heavyProfile.attackCooldown > gruntProfile.attackCooldown, "Heavy attacks less frequently")

        var runnerAI = EnemyAIController(spawnX: 500, profile: runnerProfile)
        output = runnerAI.update(dt: 0.50, enemyX: 500, playerX: 790)
        expectAI(output.state == .chase, "Runner uses its wider detection range")

        print("EnemyAIControllerTests: PASS")
    }
}
