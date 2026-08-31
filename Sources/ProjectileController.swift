import Foundation

struct ProjectileController {
    private(set) var x: Double
    let velocityX: Double
    let damage: Int
    private(set) var lifetimeRemaining: TimeInterval
    private(set) var isActive: Bool = true

    init(
        x: Double,
        velocityX: Double,
        damage: Int,
        lifetime: TimeInterval
    ) {
        self.x = x
        self.velocityX = velocityX
        self.damage = max(0, damage)
        self.lifetimeRemaining = max(0, lifetime)
        self.isActive = lifetime > 0
    }

    mutating func update(dt: TimeInterval) {
        guard isActive, dt > 0 else { return }

        x += velocityX * dt
        lifetimeRemaining = max(0, lifetimeRemaining - dt)
        if lifetimeRemaining <= 0 {
            isActive = false
        }
    }

    @discardableResult
    mutating func consumeOnPlayerContact() -> Bool {
        guard isActive else { return false }
        isActive = false
        return true
    }

    mutating func deactivate() {
        isActive = false
    }
}
