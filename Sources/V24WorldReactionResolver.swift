import Foundation

enum V24ShrinePresentationState: Equatable {
    case active
    case dormant
}

enum V24CheckpointPresentationState: Equatable {
    case inactive
    case active
}

enum V24WorldReactionResolver {
    static func shrineState(
        id: ShrineID,
        consumedShrines: Set<ShrineID>
    ) -> V24ShrinePresentationState {
        consumedShrines.contains(id) ? .dormant : .active
    }

    static func checkpointState(
        id: CheckpointID,
        currentCheckpoint: CheckpointID
    ) -> V24CheckpointPresentationState {
        id == currentCheckpoint ? .active : .inactive
    }

    static func exitLabel(
        state: RoomExitPresentationState,
        requiredAbility: PlayerAbility?,
        shortcut: Bool,
        completionExit: Bool
    ) -> String {
        switch state {
        case .open:
            if completionExit { return "FINISH" }
            return shortcut ? "SHORTCUT" : "EXIT"
        case .combatLocked:
            return "LOCKED"
        case .abilityLocked:
            if requiredAbility == .wallTraversal { return "WALL" }
            if requiredAbility == .dash { return "DASH" }
            return "ABILITY"
        }
    }
}
