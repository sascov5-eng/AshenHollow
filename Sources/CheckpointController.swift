import Foundation
import CoreGraphics

struct PlayerResourceState: Equatable {
    var hp: Int
    let maxHP: Int
    var light: Int
}

struct CheckpointActivationResult: Equatable {
    let respawnPosition: CGPoint
    let player: PlayerResourceState
}

enum CheckpointController {
    static func activate(
        id: String,
        playerState: PlayerResourceState,
        session: TestSessionState,
        layout: TestLocationSpec
    ) -> CheckpointActivationResult? {
        guard let checkpoint = layout.checkpoints.first(where: { $0.id == id }) else { return nil }
        session.activeCheckpointID = id
        var player = playerState
        player.hp = player.maxHP
        return CheckpointActivationResult(respawnPosition: checkpoint.position, player: player)
    }

    static func respawnPosition(session: TestSessionState, layout: TestLocationSpec) -> CGPoint {
        guard let id = session.activeCheckpointID,
              let checkpoint = layout.checkpoints.first(where: { $0.id == id }) else {
            return layout.spawnPoint
        }
        return checkpoint.position
    }
}
