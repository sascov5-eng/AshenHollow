import Foundation

@inline(__always)
func expectAttackDirection(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerAttackDirectionTestsMain {
    static func main() {
        let horizontal = PlayerAttackDirection.horizontal.hitboxSpec(facing: 1)
        expectAttackDirection(horizontal.offsetX > 0, "horizontal hitbox faces right")
        expectAttackDirection(horizontal.width == 62, "horizontal hitbox keeps the V21 width")
        expectAttackDirection(horizontal.height == 42, "horizontal hitbox keeps the V21 height")

        let horizontalLeft = PlayerAttackDirection.horizontal.hitboxSpec(facing: -1)
        expectAttackDirection(horizontalLeft.offsetX < 0, "horizontal hitbox mirrors left")

        let up = PlayerAttackDirection.up.hitboxSpec(facing: -1)
        expectAttackDirection(up.offsetY > 0, "up attack extends above player")
        expectAttackDirection(up.height > up.width, "up attack is vertically oriented")

        let down = PlayerAttackDirection.down.hitboxSpec(facing: 1)
        expectAttackDirection(down.offsetY < 0, "down attack extends below player")
        expectAttackDirection(down.height > down.width, "down attack is vertically oriented")

        print("PlayerAttackDirectionTests: PASS")
    }
}
