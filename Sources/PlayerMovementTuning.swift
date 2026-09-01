import Foundation

struct PlayerMovementTuning: Equatable {
    let colliderWidth: Double
    let colliderHeight: Double
    let gravity: Double
    let jumpVelocity: Double
    let jumpReleaseVelocity: Double
    let maxFallSpeed: Double
    let runSpeed: Double
    let groundAcceleration: Double
    let airAcceleration: Double
    let groundDeceleration: Double
    let coyoteDuration: TimeInterval
    let jumpBufferDuration: TimeInterval
    let maxMotionPerSubstep: Double
    let dashSpeed: Double
    let dashDuration: TimeInterval
    let dashCooldown: TimeInterval
    let wallSlideSpeed: Double
    let wallJumpHorizontalSpeed: Double
    let wallJumpVerticalSpeed: Double
    let sameWallLockDuration: TimeInterval

    static let current = PlayerMovementTuning(
        colliderWidth: 36,
        colliderHeight: 60,
        gravity: 1700,
        jumpVelocity: 610,
        jumpReleaseVelocity: 285,
        maxFallSpeed: 900,
        runSpeed: 315,
        groundAcceleration: 1900,
        airAcceleration: 1050,
        groundDeceleration: 2400,
        coyoteDuration: 0.12,
        jumpBufferDuration: 0.12,
        maxMotionPerSubstep: 5,
        dashSpeed: 720,
        dashDuration: 0.16,
        dashCooldown: 0.60,
        wallSlideSpeed: -180,
        wallJumpHorizontalSpeed: 360,
        wallJumpVerticalSpeed: 560,
        sameWallLockDuration: 0.12
    )

    var fullJumpApexRise: Double {
        jumpVelocity * jumpVelocity / (2 * gravity)
    }

    var pureDashDisplacement: Double {
        dashSpeed * dashDuration
    }
}
