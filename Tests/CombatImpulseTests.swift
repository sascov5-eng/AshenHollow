import Foundation

@inline(__always)
func expectCombatImpulse(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct CombatImpulseTestsMain {
    static func main() {
        let recoilLeft = CombatImpulse.recoil(direction: -1, speed: 240)
        expectCombatImpulse(recoilLeft.kind == .recoil, "recoil kind")
        expectCombatImpulse(recoilLeft.velocityX == -240, "recoil points left")
        expectCombatImpulse(recoilLeft.velocityY == nil, "horizontal recoil preserves vertical velocity")

        let recoilRight = CombatImpulse.recoil(direction: 1, speed: 240)
        expectCombatImpulse(recoilRight.velocityX == 240, "recoil points right")

        let pogo = CombatImpulse.pogo(verticalSpeed: 465)
        expectCombatImpulse(pogo.kind == .pogo, "pogo kind")
        expectCombatImpulse(pogo.velocityY == 465, "pogo sets upward velocity")
        expectCombatImpulse(pogo.velocityX == nil, "pogo preserves horizontal velocity")

        print("CombatImpulseTests: PASS")
    }
}
