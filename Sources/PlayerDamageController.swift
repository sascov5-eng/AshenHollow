import Foundation
import CoreGraphics

struct PlayerDamageResult: Equatable {
    let hpLoss: Int
    let knockback: CGVector
    let invulnerability: TimeInterval
}

struct PlayerDamageController {
    private(set) var invulnerabilityRemaining: TimeInterval = 0

    var isInvulnerable: Bool { invulnerabilityRemaining > 0 }

    mutating func update(dt: TimeInterval) {
        invulnerabilityRemaining = max(0, invulnerabilityRemaining - max(0, dt))
    }

    mutating func grantInvulnerability(_ duration: TimeInterval = 1.0) {
        invulnerabilityRemaining = max(invulnerabilityRemaining, duration)
    }

    mutating func takeHit(from sourceX: CGFloat, playerX: CGFloat) -> PlayerDamageResult? {
        guard !isInvulnerable else { return nil }
        invulnerabilityRemaining = 1.0
        let direction: CGFloat = playerX >= sourceX ? 1 : -1
        return PlayerDamageResult(hpLoss: 1, knockback: CGVector(dx: direction * 260, dy: 220), invulnerability: 1.0)
    }
}
