import Foundation

final class PlayerVitalState {
    private(set) var health: PlayerHealth
    private(set) var acceptedDamageSequence: Int = 0

    init(maxHP: Int = 5, invulnerabilityDuration: TimeInterval = 0.65) {
        health = PlayerHealth(
            maxHP: maxHP,
            invulnerabilityDuration: invulnerabilityDuration
        )
    }

    @discardableResult
    func applyDamage(damage: Int, attackID: Int) -> Bool {
        guard health.applyHit(damage: damage, attackID: attackID) else {
            return false
        }

        acceptedDamageSequence += 1
        return true
    }

    @discardableResult
    func heal(_ amount: Int) -> Bool {
        health.heal(amount)
    }

    func update(_ dt: TimeInterval) {
        health.update(dt)
    }
}
