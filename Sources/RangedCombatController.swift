import Foundation

enum RangedCombatState: Equatable {
    case tracking
    case aiming
    case recovery
    case retreating
}

struct RangedCombatOutput: Equatable {
    let state: RangedCombatState
    let shouldFire: Bool
    let movementDirection: Double
}

struct RangedCombatController {
    let aimDuration: TimeInterval
    let recoveryDuration: TimeInterval
    let retreatDistanceTrigger: Double
    let retreatDuration: TimeInterval
    let retreatCooldownDuration: TimeInterval
    let attackDistance: Double

    private(set) var state: RangedCombatState = .tracking
    private var stateRemaining: TimeInterval = 0
    private var retreatCooldownRemaining: TimeInterval = 0

    init(
        aimDuration: TimeInterval = 0.42,
        recoveryDuration: TimeInterval = 0.72,
        retreatDistanceTrigger: Double = 105,
        retreatDuration: TimeInterval = 0.28,
        retreatCooldownDuration: TimeInterval = 0.85,
        attackDistance: Double = 270
    ) {
        self.aimDuration = max(0.01, aimDuration)
        self.recoveryDuration = max(0.01, recoveryDuration)
        self.retreatDistanceTrigger = max(0, retreatDistanceTrigger)
        self.retreatDuration = max(0.01, retreatDuration)
        self.retreatCooldownDuration = max(0, retreatCooldownDuration)
        self.attackDistance = max(0, attackDistance)
    }

    mutating func update(
        dt: TimeInterval,
        distanceToPlayer: Double,
        directionToPlayer: Double
    ) -> RangedCombatOutput {
        let safeDT = max(0, dt)
        retreatCooldownRemaining = max(0, retreatCooldownRemaining - safeDT)

        switch state {
        case .aiming:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 {
                state = .recovery
                stateRemaining = recoveryDuration
                return RangedCombatOutput(
                    state: .recovery,
                    shouldFire: true,
                    movementDirection: 0
                )
            }
            return RangedCombatOutput(
                state: .aiming,
                shouldFire: false,
                movementDirection: 0
            )

        case .recovery:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 {
                state = .tracking
            }
            return RangedCombatOutput(
                state: state,
                shouldFire: false,
                movementDirection: 0
            )

        case .retreating:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 {
                state = .tracking
                retreatCooldownRemaining = retreatCooldownDuration
                return RangedCombatOutput(
                    state: .tracking,
                    shouldFire: false,
                    movementDirection: 0
                )
            }
            return RangedCombatOutput(
                state: .retreating,
                shouldFire: false,
                movementDirection: awayDirection(from: directionToPlayer)
            )

        case .tracking:
            if distanceToPlayer < retreatDistanceTrigger,
               retreatCooldownRemaining == 0 {
                state = .retreating
                stateRemaining = retreatDuration
                return RangedCombatOutput(
                    state: .retreating,
                    shouldFire: false,
                    movementDirection: awayDirection(from: directionToPlayer)
                )
            }

            if distanceToPlayer <= attackDistance {
                state = .aiming
                stateRemaining = aimDuration
                return RangedCombatOutput(
                    state: .aiming,
                    shouldFire: false,
                    movementDirection: 0
                )
            }

            return RangedCombatOutput(
                state: .tracking,
                shouldFire: false,
                movementDirection: towardDirection(from: directionToPlayer)
            )
        }
    }

    private func towardDirection(from directionToPlayer: Double) -> Double {
        directionToPlayer >= 0 ? 1 : -1
    }

    private func awayDirection(from directionToPlayer: Double) -> Double {
        directionToPlayer >= 0 ? -1 : 1
    }
}
