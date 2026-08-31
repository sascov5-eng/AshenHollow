import Foundation

struct AttackController {
    private(set) var attackRemaining: TimeInterval = 0
    private(set) var cooldownRemaining: TimeInterval = 0

    let attackDuration: TimeInterval = 0.22
    let cooldownDuration: TimeInterval = 0.32
    let hitboxStart: TimeInterval = 0.05
    let hitboxEnd: TimeInterval = 0.13

    var isAttacking: Bool {
        attackRemaining > 0
    }

    var isHitboxActive: Bool {
        guard isAttacking else { return false }
        let elapsed = attackDuration - attackRemaining
        return elapsed >= hitboxStart && elapsed <= hitboxEnd
    }

    @discardableResult
    mutating func tryStart() -> Bool {
        guard cooldownRemaining <= 0 else { return false }

        attackRemaining = attackDuration
        cooldownRemaining = cooldownDuration
        return true
    }

    mutating func update(_ dt: TimeInterval) {
        guard dt > 0 else { return }
        attackRemaining = max(0, attackRemaining - dt)
        cooldownRemaining = max(0, cooldownRemaining - dt)
    }

    mutating func reset() {
        attackRemaining = 0
        cooldownRemaining = 0
    }
}
