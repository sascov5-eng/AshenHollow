import Foundation

struct CombatHitStopController {
    private(set) var remaining: TimeInterval = 0

    var isActive: Bool {
        remaining > 0
    }

    mutating func request(duration: TimeInterval) {
        guard duration > 0 else { return }
        remaining = max(remaining, duration)
    }

    @discardableResult
    mutating func update(dt: TimeInterval) -> Bool {
        guard remaining > 0 else { return false }
        guard dt > 0 else { return true }
        remaining = max(0, remaining - dt)
        return true
    }

    mutating func reset() {
        remaining = 0
    }
}
