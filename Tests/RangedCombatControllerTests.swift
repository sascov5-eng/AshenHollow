import Foundation

@inline(__always)
func expectRanged(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RangedCombatControllerTestsMain {
    static func main() {
        var ranged = RangedCombatController()

        var output = ranged.update(
            dt: 0.01,
            distanceToPlayer: 220,
            directionToPlayer: 1
        )
        expectRanged(output.state == .aiming, "valid attack range enters aim")
        expectRanged(!output.shouldFire, "aim never fires immediately")
        expectRanged(output.movementDirection == 0, "aim holds position")

        output = ranged.update(
            dt: 0.40,
            distanceToPlayer: 220,
            directionToPlayer: 1
        )
        expectRanged(output.state == .aiming, "aim remains readable before threshold")
        expectRanged(!output.shouldFire, "readable aim has no early shot")

        output = ranged.update(
            dt: 0.02,
            distanceToPlayer: 220,
            directionToPlayer: 1
        )
        expectRanged(output.shouldFire, "aim completion fires exactly once")
        expectRanged(output.state == .recovery, "shot enters recovery")

        output = ranged.update(
            dt: 0.20,
            distanceToPlayer: 220,
            directionToPlayer: 1
        )
        expectRanged(output.state == .recovery, "recovery is a real punish window")
        expectRanged(!output.shouldFire, "recovery blocks immediate second shot")
        expectRanged(output.movementDirection == 0, "recovery does not kite")

        output = ranged.update(
            dt: 0.60,
            distanceToPlayer: 220,
            directionToPlayer: 1
        )
        expectRanged(!output.shouldFire, "leaving recovery does not fire on same update")

        var retreat = RangedCombatController()
        output = retreat.update(
            dt: 0.01,
            distanceToPlayer: 80,
            directionToPlayer: 1
        )
        expectRanged(output.state == .retreating, "close player starts retreat burst")
        expectRanged(output.movementDirection == -1, "retreat moves away from player")

        output = retreat.update(
            dt: 0.30,
            distanceToPlayer: 80,
            directionToPlayer: 1
        )
        expectRanged(output.state != .retreating, "retreat burst is finite")

        output = retreat.update(
            dt: 0.10,
            distanceToPlayer: 80,
            directionToPlayer: 1
        )
        expectRanged(output.state != .retreating, "retreat cooldown prevents permanent kiting")

        var leftSide = RangedCombatController()
        output = leftSide.update(
            dt: 0.01,
            distanceToPlayer: 70,
            directionToPlayer: -1
        )
        expectRanged(output.movementDirection == 1, "retreat direction mirrors correctly")

        print("RangedCombatControllerTests: PASS")
    }
}
