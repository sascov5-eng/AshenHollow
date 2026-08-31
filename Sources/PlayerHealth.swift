import Foundation

struct PlayerHealth {
    let maxHP: Int
    let invulnerabilityDuration: TimeInterval

    private(set) var hp: Int
    private(set) var invulnerabilityRemaining: TimeInterval = 0
    private var lastAttackID: Int?

    var isAlive: Bool {
        hp > 0
    }

    var isInvulnerable: Bool {
        invulnerabilityRemaining > 0
    }

    init(maxHP: Int, invulnerabilityDuration: TimeInterval) {
        let safeMax = max(1, maxHP)
        self.maxHP = safeMax
        self.hp = safeMax
        self.invulnerabilityDuration = max(0, invulnerabilityDuration)
    }

    @discardableResult
    mutating func applyHit(damage: Int, attackID: Int) -> Bool {
        guard isAlive,
              damage > 0,
              !isInvulnerable,
              lastAttackID != attackID else {
            return false
        }

        lastAttackID = attackID
        hp = max(0, hp - damage)

        if isAlive {
            invulnerabilityRemaining = invulnerabilityDuration
        } else {
            invulnerabilityRemaining = 0
        }

        return true
    }

    mutating func update(_ dt: TimeInterval) {
        guard dt > 0 else { return }
        invulnerabilityRemaining = max(0, invulnerabilityRemaining - dt)
    }
}
