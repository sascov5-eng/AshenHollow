import Foundation

struct DashController {
    private let tuning = PlayerMovementTuning.current

    var cooldown: TimeInterval { tuning.dashCooldown }
    var duration: TimeInterval { tuning.dashDuration }
    private(set) var cooldownRemaining: TimeInterval = 0
    private(set) var dashRemaining: TimeInterval = 0
    private(set) var direction: Double = 1
    private(set) var airDashAvailable = true

    var isDashing: Bool { dashRemaining > 0 }

    mutating func tryStart(
        unlocked: Bool,
        isGrounded: Bool,
        inputX: Double,
        facing: Double
    ) -> Double? {
        guard unlocked, cooldownRemaining <= 0, !isDashing else { return nil }
        if !isGrounded && !airDashAvailable { return nil }

        direction = inputX == 0
            ? (facing >= 0 ? 1 : -1)
            : (inputX > 0 ? 1 : -1)
        dashRemaining = duration
        cooldownRemaining = cooldown
        if !isGrounded {
            airDashAvailable = false
        }
        return direction
    }

    mutating func update(dt: TimeInterval) {
        guard dt > 0 else { return }
        cooldownRemaining = max(0, cooldownRemaining - dt)
        dashRemaining = max(0, dashRemaining - dt)
    }

    mutating func restoreAirDash() {
        airDashAvailable = true
    }

    mutating func cancelActiveDash() {
        dashRemaining = 0
    }
}
