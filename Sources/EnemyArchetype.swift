import Foundation

enum EnemyAttackKind: Equatable {
    case melee
    case projectile
    case boss
}

enum EnemyArchetype: String, Equatable, Hashable {
    case grunt
    case runner
    case heavy
    case ranged
    case boss

    var stats: EnemyStats {
        switch self {
        case .grunt:
            return EnemyStats(
                maxHP: 3,
                contactDamage: 1,
                patrolSpeed: 72,
                chaseSpeed: 138,
                detectionRange: 240,
                attackRange: 62,
                attackCooldown: 0.82,
                attackDuration: 0.30,
                hitStunDuration: 0.16,
                knockbackSpeed: 250,
                attackKind: .melee
            )
        case .runner:
            return EnemyStats(
                maxHP: 2,
                contactDamage: 1,
                patrolSpeed: 102,
                chaseSpeed: 205,
                detectionRange: 310,
                attackRange: 60,
                attackCooldown: 0.62,
                attackDuration: 0.24,
                hitStunDuration: 0.18,
                knockbackSpeed: 330,
                attackKind: .melee
            )
        case .heavy:
            return EnemyStats(
                maxHP: 6,
                contactDamage: 2,
                patrolSpeed: 48,
                chaseSpeed: 82,
                detectionRange: 225,
                attackRange: 70,
                attackCooldown: 1.18,
                attackDuration: 0.44,
                hitStunDuration: 0.10,
                knockbackSpeed: 145,
                attackKind: .melee
            )
        case .ranged:
            return EnemyStats(
                maxHP: 3,
                contactDamage: 1,
                patrolSpeed: 58,
                chaseSpeed: 92,
                detectionRange: 390,
                attackRange: 310,
                attackCooldown: 1.05,
                attackDuration: 0.34,
                hitStunDuration: 0.16,
                knockbackSpeed: 320,
                attackKind: .projectile
            )
        case .boss:
            return EnemyStats(
                maxHP: 20,
                contactDamage: 2,
                patrolSpeed: 0,
                chaseSpeed: 108,
                detectionRange: 900,
                attackRange: 94,
                attackCooldown: 0.95,
                attackDuration: 0.48,
                hitStunDuration: 0.06,
                knockbackSpeed: 70,
                attackKind: .boss
            )
        }
    }
}

struct EnemyStats: Equatable {
    let maxHP: Int
    let contactDamage: Int
    let patrolSpeed: Double
    let chaseSpeed: Double
    let detectionRange: Double
    let attackRange: Double
    let attackCooldown: TimeInterval
    let attackDuration: TimeInterval
    let hitStunDuration: TimeInterval
    let knockbackSpeed: Double
    let attackKind: EnemyAttackKind
}
