import Foundation

struct AttackHitboxSpec: Equatable {
    let offsetX: Double
    let offsetY: Double
    let width: Double
    let height: Double
}

enum PlayerAttackDirection: Equatable {
    case horizontal
    case up
    case down

    func hitboxSpec(facing: Double) -> AttackHitboxSpec {
        switch self {
        case .horizontal:
            return AttackHitboxSpec(
                offsetX: 50 * (facing >= 0 ? 1 : -1),
                offsetY: 2,
                width: 62,
                height: 42
            )
        case .up:
            return AttackHitboxSpec(
                offsetX: 8 * (facing >= 0 ? 1 : -1),
                offsetY: 48,
                width: 42,
                height: 64
            )
        case .down:
            return AttackHitboxSpec(
                offsetX: 6 * (facing >= 0 ? 1 : -1),
                offsetY: -50,
                width: 42,
                height: 64
            )
        }
    }
}
