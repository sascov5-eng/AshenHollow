import Foundation

struct EnemyRuntimeModel {
    let archetype: EnemyArchetype
    private(set) var hp: Int
    private(set) var hitStunRemaining: TimeInterval = 0
    private(set) var knockbackVelocity: Double = 0
    private(set) var isAttackDamageWindowActive: Bool = false

    private var lastPlayerAttackID: Int?

    var isAlive: Bool { hp > 0 }
    var isHitStunned: Bool { hitStunRemaining > 0 }

    init(archetype: EnemyArchetype) {
        self.archetype = archetype
        self.hp = archetype.stats.maxHP
    }

    mutating func markAttackDamageWindowActive(_ active: Bool) {
        isAttackDamageWindowActive = active
    }

    @discardableResult
    mutating func applyPlayerHit(
        damage: Int,
        playerAttackID: Int,
        playerX: Double,
        enemyX: Double
    ) -> Bool {
        guard isAlive,
              damage > 0,
              lastPlayerAttackID != playerAttackID else {
            return false
        }

        lastPlayerAttackID = playerAttackID
        hp = max(0, hp - damage)

        let stats = archetype.stats
        hitStunRemaining = isAlive ? stats.hitStunDuration : 0

        if enemyX > playerX {
            knockbackVelocity = stats.knockbackSpeed
        } else if enemyX < playerX {
            knockbackVelocity = -stats.knockbackSpeed
        } else {
            knockbackVelocity = 0
        }

        if archetype != .boss {
            isAttackDamageWindowActive = false
        }

        return true
    }

    mutating func update(dt: TimeInterval) {
        guard dt > 0 else { return }
        hitStunRemaining = max(0, hitStunRemaining - dt)
        if hitStunRemaining <= 0 {
            knockbackVelocity = 0
        }
    }
}
