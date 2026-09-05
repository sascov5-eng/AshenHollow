import Foundation

enum PlayerLifeState: Equatable {
    case normal
    case hurt(TimeInterval)
    case dead
}

struct PlayerLifeStateController {
    private(set) var state: PlayerLifeState = .normal

    mutating func registerDamage(isLethal: Bool) {
        state = isLethal ? .dead : .hurt(0.28)
    }

    mutating func update(dt: TimeInterval) {
        guard case .hurt(let remaining) = state else { return }
        let next = remaining - max(0, dt)
        state = next <= 0 ? .normal : .hurt(next)
    }

    mutating func respawn() {
        state = .normal
    }
}
