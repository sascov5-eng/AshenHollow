import Foundation
import CoreGraphics

struct RecoveryResult: Equatable {
    let position: CGPoint
    let hp: Int
    let invulnerability: TimeInterval
    let transitionDuration: TimeInterval
    let resetsEnemies: Bool
}

enum RespawnController {
    static func spikeRecovery(currentHP: Int, safePosition: CGPoint, checkpointPosition: CGPoint) -> RecoveryResult {
        let nextHP = max(0, currentHP - 1)
        if nextHP == 0 {
            return RecoveryResult(position: checkpointPosition, hp: 5, invulnerability: 1.0, transitionDuration: 0.65, resetsEnemies: true)
        }
        return RecoveryResult(position: safePosition, hp: nextHP, invulnerability: 1.0, transitionDuration: 0.35, resetsEnemies: false)
    }

    static func deathRecovery(checkpointPosition: CGPoint, maxHP: Int) -> RecoveryResult {
        RecoveryResult(position: checkpointPosition, hp: maxHP, invulnerability: 1.0, transitionDuration: 0.65, resetsEnemies: true)
    }
}
