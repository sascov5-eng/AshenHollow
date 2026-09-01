import Foundation

enum PlayerAbility: String, Codable, CaseIterable, Hashable {
    case dash
    case wallTraversal
}

enum ShrineID: String, Codable, CaseIterable, Hashable {
    case dash
    case wallTraversal
}

enum CheckpointID: String, Codable, CaseIterable, Hashable {
    case approach
    case postDash
    case postWallTraversal
    case preWarden
}

struct CheckpointSnapshot: Codable, Equatable {
    let id: CheckpointID
    let roomID: RoomID
    let spawn: RoomPoint
}

struct DemoProgressionState: Codable, Equatable {
    var unlockedAbilities: Set<PlayerAbility>
    var consumedShrines: Set<ShrineID>
    var checkpoint: CheckpointSnapshot

    static let fresh = DemoProgressionState(
        unlockedAbilities: [],
        consumedShrines: [],
        checkpoint: CheckpointSnapshot(
            id: .approach,
            roomID: .approach,
            spawn: RoomPoint(x: 120, y: 130)
        )
    )

    func has(_ ability: PlayerAbility) -> Bool {
        unlockedAbilities.contains(ability)
    }

    @discardableResult
    mutating func claimShrine(
        _ shrine: ShrineID,
        ability: PlayerAbility,
        checkpoint: CheckpointSnapshot
    ) -> Bool {
        guard !consumedShrines.contains(shrine) else { return false }
        consumedShrines.insert(shrine)
        unlockedAbilities.insert(ability)
        self.checkpoint = checkpoint
        return true
    }

    mutating func activateCheckpoint(_ checkpoint: CheckpointSnapshot) {
        self.checkpoint = checkpoint
    }
}
