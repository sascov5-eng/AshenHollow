import Foundation

@inline(__always)
func expectMovementTuning(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerMovementTuningTestsMain {
    static func main() {
        let tuning = PlayerMovementTuning.current

        expectMovementTuning(tuning.colliderWidth == 36, "collider width remains 36")
        expectMovementTuning(tuning.colliderHeight == 60, "collider height remains 60")
        expectMovementTuning(tuning.gravity == 1700, "gravity magnitude remains 1700")
        expectMovementTuning(tuning.jumpVelocity == 610, "jump velocity remains 610")
        expectMovementTuning(tuning.jumpReleaseVelocity == 285, "jump release cap remains 285")
        expectMovementTuning(tuning.maxFallSpeed == 900, "max fall speed magnitude remains 900")
        expectMovementTuning(tuning.runSpeed == 315, "run speed remains 315")
        expectMovementTuning(tuning.groundAcceleration == 1900, "ground acceleration remains 1900")
        expectMovementTuning(tuning.airAcceleration == 1050, "air acceleration remains 1050")
        expectMovementTuning(tuning.groundDeceleration == 2400, "ground deceleration remains 2400")
        expectMovementTuning(tuning.coyoteDuration == 0.12, "coyote duration remains 0.12")
        expectMovementTuning(tuning.jumpBufferDuration == 0.12, "jump buffer remains 0.12")
        expectMovementTuning(tuning.maxMotionPerSubstep == 5, "substep cap remains 5")
        expectMovementTuning(tuning.dashSpeed == 720, "dash speed remains 720")
        expectMovementTuning(tuning.dashDuration == 0.16, "dash duration remains 0.16")
        expectMovementTuning(tuning.dashCooldown == 0.60, "dash cooldown remains 0.60")
        expectMovementTuning(tuning.wallSlideSpeed == -180, "wall slide cap remains -180")
        expectMovementTuning(tuning.wallJumpHorizontalSpeed == 360, "wall jump horizontal speed remains 360")
        expectMovementTuning(tuning.wallJumpVerticalSpeed == 560, "wall jump vertical speed remains 560")
        expectMovementTuning(tuning.sameWallLockDuration == 0.12, "same-wall lock remains 0.12")

        let expectedApex = tuning.jumpVelocity * tuning.jumpVelocity / (2 * tuning.gravity)
        expectMovementTuning(expectedApex > 109 && expectedApex < 110, "derived full-jump apex stays near 109 pt")
        expectMovementTuning(tuning.dashSpeed * tuning.dashDuration == 115.2, "pure dash displacement remains 115.2 pt")

        print("PlayerMovementTuningTests: PASS")
    }
}
