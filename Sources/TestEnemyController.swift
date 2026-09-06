import Foundation
import CoreGraphics

struct EnemyUpdateResult: Equatable {
    var position: CGPoint
    var velocity: CGVector
}

final class TestEnemyController {
    let spec: EnemyTestSpec
    private(set) var hp: Int
    private(set) var isAlive: Bool = true
    private(set) var position: CGPoint
    private var direction: CGFloat = 1
    private var hitStunRemaining: TimeInterval = 0
    private var knockbackVelocityX: CGFloat = 0

    init(spec: EnemyTestSpec, snapshot: EnemyRuntimeSnapshot? = nil) {
        self.spec = spec
        if let snapshot {
            hp = snapshot.hp
            isAlive = snapshot.isAlive
            position = snapshot.position
        } else {
            hp = spec.maxHP
            position = spec.spawn
        }
    }

    func update(dt: TimeInterval, playerPosition: CGPoint) -> EnemyUpdateResult {
        guard isAlive else { return EnemyUpdateResult(position: position, velocity: .zero) }
        let old = position

        if hitStunRemaining > 0 {
            let step = min(dt, hitStunRemaining)
            position.x += knockbackVelocityX * CGFloat(step)
            hitStunRemaining = max(0, hitStunRemaining - dt)
            knockbackVelocityX *= 0.78
            if hitStunRemaining == 0 { knockbackVelocityX = 0 }
            return EnemyUpdateResult(position: position, velocity: CGVector(dx: position.x - old.x, dy: position.y - old.y))
        }

        switch spec.kind {
        case .groundPatrol, .passive:
            let speed: CGFloat = spec.kind == .passive ? 38 : 70
            position.x += direction * speed * CGFloat(dt)
            if position.x >= spec.patrolRange.upperBound { position.x = spec.patrolRange.upperBound; direction = -1 }
            if position.x <= spec.patrolRange.lowerBound { position.x = spec.patrolRange.lowerBound; direction = 1 }
        case .flying:
            position.x += direction * 55 * CGFloat(dt)
            if position.x >= spec.patrolRange.upperBound { position.x = spec.patrolRange.upperBound; direction = -1 }
            if position.x <= spec.patrolRange.lowerBound { position.x = spec.patrolRange.lowerBound; direction = 1 }
            position.y = spec.spawn.y + sin(position.x * 0.025) * 35
        case .aggressive, .miniBoss, .boss:
            let chase: CGFloat = spec.kind == .boss ? 520 : (spec.kind == .miniBoss ? 440 : 380)
            let run: CGFloat = spec.kind == .boss ? 150 : (spec.kind == .miniBoss ? 130 : 115)
            let dx = playerPosition.x - position.x
            if abs(dx) < chase { position.x += (dx >= 0 ? 1 : -1) * run * CGFloat(dt) }
            else {
                position.x += direction * 60 * CGFloat(dt)
                if position.x >= spec.patrolRange.upperBound { position.x = spec.patrolRange.upperBound; direction = -1 }
                if position.x <= spec.patrolRange.lowerBound { position.x = spec.patrolRange.lowerBound; direction = 1 }
            }
            if spec.kind == .boss {
                position.y = spec.spawn.y + sin(position.x * 0.01) * 8
            }
        }
        return EnemyUpdateResult(position: position, velocity: CGVector(dx: position.x - old.x, dy: position.y - old.y))
    }

    @discardableResult
    func receiveMeleeHit(damage: Int = 1) -> Bool {
        guard isAlive else { return false }
        hp = max(0, hp - max(1, damage))
        if hp == 0 { isAlive = false }
        return true
    }

    func applyMeleeKnockback(fromX attackerX: CGFloat, force: CGFloat = 185, stun: TimeInterval = 0.12) {
        guard isAlive else { return }
        let away: CGFloat = position.x >= attackerX ? 1 : -1
        knockbackVelocityX = away * max(0, force)
        hitStunRemaining = max(hitStunRemaining, max(0, stun))
        direction = away
    }

    func snapshot() -> EnemyRuntimeSnapshot {
        EnemyRuntimeSnapshot(hp: hp, isAlive: isAlive, position: position)
    }

    func reset() {
        hp = spec.maxHP
        isAlive = true
        position = spec.spawn
        direction = 1
        hitStunRemaining = 0
        knockbackVelocityX = 0
    }
}
