import Foundation

enum TraversalTeachingPrompt: Equatable {
    case dash
    case wallTraversal
}

struct TraversalTeachingController {
    private(set) var prompt: TraversalTeachingPrompt?
    private var demonstratedAbilities: Set<PlayerAbility> = []

    mutating func begin(for ability: PlayerAbility) {
        guard !demonstratedAbilities.contains(ability) else { return }
        switch ability {
        case .dash:
            prompt = .dash
        case .wallTraversal:
            prompt = .wallTraversal
        }
    }

    mutating func recordDashStarted() {
        guard prompt == .dash else { return }
        demonstratedAbilities.insert(.dash)
        prompt = nil
    }

    mutating func recordWallJump() {
        guard prompt == .wallTraversal else { return }
        demonstratedAbilities.insert(.wallTraversal)
        prompt = nil
    }
}
