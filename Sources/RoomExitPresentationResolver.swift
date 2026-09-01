import Foundation

enum RoomExitPresentationState: Equatable {
    case open
    case combatLocked
    case abilityLocked
}

enum RoomExitPresentationResolver {
    static func state(
        for exit: RoomExit,
        roomRequiresCombatClear: Bool,
        combatCleared: Bool,
        unlockedAbilities: Set<PlayerAbility>
    ) -> RoomExitPresentationState {
        if roomRequiresCombatClear && !combatCleared {
            return .combatLocked
        }

        if let requiredAbility = exit.requiredAbility,
           !unlockedAbilities.contains(requiredAbility) {
            return .abilityLocked
        }

        return .open
    }
}
