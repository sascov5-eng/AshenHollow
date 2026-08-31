import Foundation

struct EnemyHealth {
    let maxHP: Int
    private(set) var hp: Int
    private var lastAttackID: Int?

    var isAlive: Bool {
        hp > 0
    }

    init(maxHP: Int) {
        let safeMax = max(1, maxHP)
        self.maxHP = safeMax
        self.hp = safeMax
    }

    @discardableResult
    mutating func applyHit(damage: Int, attackID: Int) -> Bool {
        guard isAlive, damage > 0, lastAttackID != attackID else {
            return false
        }

        lastAttackID = attackID
        hp = max(0, hp - damage)
        return true
    }
}
