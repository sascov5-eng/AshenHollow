import Foundation

enum EnemyAIState: String {
    case idle
    case patrol
    case chase
    case attack
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
    private let patrolHalfWidth: Double = 110
    private let detectionRange: Double = 240
    private let attackRange: Double = 62
    private let initialIdleDuration: TimeInterval = 0.45
    private let edgeIdleDuration: TimeInterval = 0.28
    private let attackDuration: TimeInterval = 0.30
    private let attackCooldown: TimeInterval = 0.82

    private var idleRemaining: TimeInterval
    private var attackRemaining: TimeInterval = 0
    private var attackCooldownRemaining: TimeInterval = 0
    private var patrolDirection: Double = 1
    private(set) var attackID: Int = 0

    init(spawnX: Double) {
        self.spawnX = spawnX
        self.idleRemaining = initialIdleDuration
    }

    mutating func reset() {
        idleRemaining = initialIdleDuration
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

        if distance <= attackRange {
            var startedAttack = false
            if cooldownWasReady {
                attackID += 1
                attackRemaining = attackDuration
                attackCooldownRemaining = attackCooldown
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

        if distance <= detectionRange {
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

        let leftEdge = spawnX - patrolHalfWidth
        let rightEdge = spawnX + patrolHalfWidth

        if enemyX >= rightEdge && patrolDirection > 0 {
            patrolDirection = -1
            idleRemaining = edgeIdleDuration
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
            idleRemaining = edgeIdleDuration
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
