import Foundation

enum EnemyAIState: String {
    case idle
    case patrol
    case chase
    case attack
}

struct EnemyAIProfile: Equatable {
    let patrolHalfWidth: Double
    let detectionRange: Double
    let attackRange: Double
    let initialIdleDuration: TimeInterval
    let edgeIdleDuration: TimeInterval
    let attackDuration: TimeInterval
    let attackCooldown: TimeInterval
    let patrolSpeed: Double
    let chaseSpeed: Double

    static func from(stats: EnemyStats) -> EnemyAIProfile {
        EnemyAIProfile(
            patrolHalfWidth: stats.attackKind == .projectile ? 85 : 110,
            detectionRange: stats.detectionRange,
            attackRange: stats.attackRange,
            initialIdleDuration: stats.attackKind == .projectile ? 0.30 : 0.45,
            edgeIdleDuration: 0.28,
            attackDuration: stats.attackDuration,
            attackCooldown: stats.attackCooldown,
            patrolSpeed: stats.patrolSpeed,
            chaseSpeed: stats.chaseSpeed
        )
    }

    static let v17Baseline = EnemyAIProfile(
        patrolHalfWidth: 110,
        detectionRange: 240,
        attackRange: 62,
        initialIdleDuration: 0.45,
        edgeIdleDuration: 0.28,
        attackDuration: 0.30,
        attackCooldown: 0.82,
        patrolSpeed: 72,
        chaseSpeed: 138
    )
}

struct EnemyAIOutput {
    let state: EnemyAIState
    let moveDirection: Double
    let facing: Double
    let startedAttack: Bool
    let attackID: Int
    let isAttackSwingActive: Bool
}

struct EnemyAIController {
    private let spawnX: Double
    let profile: EnemyAIProfile

    private var idleRemaining: TimeInterval
    private var attackRemaining: TimeInterval = 0
    private var attackCooldownRemaining: TimeInterval = 0
    private var patrolDirection: Double = 1
    private(set) var attackID: Int = 0

    init(spawnX: Double) {
        self.init(spawnX: spawnX, profile: .v17Baseline)
    }

    init(spawnX: Double, profile: EnemyAIProfile) {
        self.spawnX = spawnX
        self.profile = profile
        self.idleRemaining = profile.initialIdleDuration
    }

    mutating func reset() {
        idleRemaining = profile.initialIdleDuration
        attackRemaining = 0
        attackCooldownRemaining = 0
        patrolDirection = 1
        attackID = 0
    }

    mutating func update(
        dt: TimeInterval,
        enemyX: Double,
        playerX: Double
    ) -> EnemyAIOutput {
        let safeDT = max(0, dt)
        let cooldownWasReady = attackCooldownRemaining <= 0

        attackRemaining = max(0, attackRemaining - safeDT)
        attackCooldownRemaining = max(0, attackCooldownRemaining - safeDT)

        let delta = playerX - enemyX
        let distance = abs(delta)
        let playerDirection: Double = delta >= 0 ? 1 : -1

        if distance <= profile.attackRange {
            var startedAttack = false
            if cooldownWasReady {
                attackID += 1
                attackRemaining = profile.attackDuration
                attackCooldownRemaining = profile.attackCooldown
                startedAttack = true
            }

            return EnemyAIOutput(
                state: .attack,
                moveDirection: 0,
                facing: playerDirection,
                startedAttack: startedAttack,
                attackID: attackID,
                isAttackSwingActive: attackRemaining > 0
            )
        }

        if distance <= profile.detectionRange {
            idleRemaining = 0
            return EnemyAIOutput(
                state: .chase,
                moveDirection: playerDirection,
                facing: playerDirection,
                startedAttack: false,
                attackID: attackID,
                isAttackSwingActive: false
            )
        }

        if idleRemaining > 0 {
            idleRemaining = max(0, idleRemaining - safeDT)
            if idleRemaining > 0 {
                return EnemyAIOutput(
                    state: .idle,
                    moveDirection: 0,
                    facing: patrolDirection,
                    startedAttack: false,
                    attackID: attackID,
                    isAttackSwingActive: false
                )
            }
        }

        let leftEdge = spawnX - profile.patrolHalfWidth
        let rightEdge = spawnX + profile.patrolHalfWidth

        if enemyX >= rightEdge && patrolDirection > 0 {
            patrolDirection = -1
            idleRemaining = profile.edgeIdleDuration
            return EnemyAIOutput(
                state: .idle,
                moveDirection: 0,
                facing: patrolDirection,
                startedAttack: false,
                attackID: attackID,
                isAttackSwingActive: false
            )
        }

        if enemyX <= leftEdge && patrolDirection < 0 {
            patrolDirection = 1
            idleRemaining = profile.edgeIdleDuration
            return EnemyAIOutput(
                state: .idle,
                moveDirection: 0,
                facing: patrolDirection,
                startedAttack: false,
                attackID: attackID,
                isAttackSwingActive: false
            )
        }

        return EnemyAIOutput(
            state: .patrol,
            moveDirection: patrolDirection,
            facing: patrolDirection,
            startedAttack: false,
            attackID: attackID,
            isAttackSwingActive: false
        )
    }
}
