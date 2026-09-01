import Foundation

@inline(__always)
func expectTraversal(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func platform(_ x: Double, _ y: Double, _ width: Double, _ height: Double = 28) -> RoomPlatform {
    RoomPlatform(center: RoomPoint(x: x, y: y), size: RoomSize(width: width, height: height))
}

private func isSafe(_ result: TraversalTransferResult) -> Bool {
    if case .safe = result { return true }
    return false
}

private func reason(_ result: TraversalTransferResult) -> String {
    if case let .unsafe(reason) = result { return reason }
    return ""
}

@main
struct TraversalSafetyValidatorTestsMain {
    static func main() {
        let validator = TraversalSafetyValidator(tuning: .current)

        let flatSource = platform(300, 86, 220) // top = 100
        let rise95Target = platform(610, 181, 220) // top = 195
        let rise95 = validator.validateOrdinaryTransfer(from: flatSource, to: rise95Target)
        expectTraversal(!isSafe(rise95), "+95 pt mandatory rise is rejected")
        expectTraversal(reason(rise95).contains("vertical"), "+95 pt rejection explains vertical limit")

        let rise70Target = platform(610, 156, 220) // top = 170, clear horizontal gap = 90
        expectTraversal(
            isSafe(validator.validateOrdinaryTransfer(from: flatSource, to: rise70Target)),
            "+70 pt rise with broad landing and useful run-up is safe"
        )

        let narrowLanding = platform(610, 86, 160)
        let narrowResult = validator.validateOrdinaryTransfer(from: flatSource, to: narrowLanding)
        expectTraversal(!isSafe(narrowResult), "mandatory landing narrower than 180 pt is rejected")
        expectTraversal(reason(narrowResult).contains("landing"), "narrow rejection explains landing width")

        let dashSource = RoomPlatform(
            center: RoomPoint(x: 260, y: 60),
            size: RoomSize(width: 520, height: 80)
        ) // right edge = 520, top = 100
        let dashTarget = RoomPlatform(
            center: RoomPoint(x: 900, y: 60),
            size: RoomSize(width: 280, height: 80)
        ) // left edge = 760 => clear gap = 240
        expectTraversal(
            isSafe(validator.validateDashTeachingTransfer(from: dashSource, to: dashTarget)),
            "240 pt Dash teaching gap with 280 pt receiving bank is safe"
        )

        let tooShortDashTarget = RoomPlatform(
            center: RoomPoint(x: 730, y: 60),
            size: RoomSize(width: 280, height: 80)
        ) // left edge = 590 => clear gap = 70
        expectTraversal(
            !isSafe(validator.validateDashTeachingTransfer(from: dashSource, to: tooShortDashTarget)),
            "Dash teaching gate must not be ordinary-jump sized"
        )

        let sideCollisionSource = RoomPlatform(
            center: RoomPoint(x: 300, y: 60),
            size: RoomSize(width: 220, height: 80)
        ) // top = 100, right edge = 410
        let sideCollisionTarget = platform(530, 156, 220) // top = 170, left edge = 420, only 10 pt gap
        let sideCollision = validator.validateOrdinaryTransfer(from: sideCollisionSource, to: sideCollisionTarget)
        expectTraversal(!isSafe(sideCollision), "nearby high platform that catches collider side is rejected")
        expectTraversal(reason(sideCollision).contains("side"), "side-collision rejection is explicit")

        let safeStepSource = platform(260, 146, 220) // top 160
        let safeStepTarget = platform(520, 211, 240) // top 225, rise 65, clear gap 20
        let step = validator.validateVerticalStep(from: safeStepSource, to: safeStepTarget)
        expectTraversal(isSafe(step), "65 pt stair step with enough horizontal separation is safe")

        print("TraversalSafetyValidatorTests: PASS")
    }
}
