import Foundation
import CoreGraphics

struct EnemyRuntimeSnapshot: Equatable {
    var hp: Int
    var isAlive: Bool
    var position: CGPoint
}

final class TestSessionState {
    var activeCheckpointID: String?
    var completedTutorials: Set<TestMechanicID> = []
    var openedInteractions: Set<String> = []
    var destroyedSecrets: Set<String> = []
    var enemyStates: [String: EnemyRuntimeSnapshot] = [:]

    func resetForNewSession() {
        activeCheckpointID = nil
        completedTutorials.removeAll()
        openedInteractions.removeAll()
        destroyedSecrets.removeAll()
        enemyStates.removeAll()
    }

    func preserveAcrossDeathResetEnemies(_ initial: [EnemyTestSpec]) {
        enemyStates = Dictionary(uniqueKeysWithValues: initial.map {
            ($0.id, EnemyRuntimeSnapshot(hp: $0.maxHP, isAlive: true, position: $0.spawn))
        })
    }
}
