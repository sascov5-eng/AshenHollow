import Foundation

@inline(__always)
func expectDash(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DashControllerTestsMain {
    static func main() {
        var dash = DashController()
        expectDash(dash.tryStart(unlocked: false, isGrounded: true, inputX: 1, facing: 1) == nil, "locked Dash cannot start")

        expectDash(dash.tryStart(unlocked: true, isGrounded: true, inputX: -1, facing: 1) == -1, "input chooses Dash direction")
        expectDash(dash.isDashing, "Dash enters active window")
        dash.update(dt: 0.20)
        expectDash(!dash.isDashing, "active window ends")
        expectDash(dash.tryStart(unlocked: true, isGrounded: true, inputX: 1, facing: 1) == nil, "cooldown blocks immediate reuse")

        dash.update(dt: 0.50)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 0, facing: 1) == 1, "neutral input uses facing")
        dash.update(dt: 0.70)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == nil, "second air Dash is blocked")
        dash.restoreAirDash()
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == 1, "restore event grants air Dash")

        print("DashControllerTests: PASS")
    }
}
