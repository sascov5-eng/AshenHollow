import Foundation

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct AttackControllerTests {
    static func main() {
        var attack = AttackController()

        expect(!attack.isAttacking, "attack starts idle")
        expect(!attack.isHitboxActive, "hitbox starts inactive")
        expect(attack.tryStart(), "first attack starts")
        expect(attack.currentDirection == .horizontal, "legacy attack starts horizontal")
        expect(attack.isAttacking, "attack reports active immediately")
        expect(!attack.tryStart(), "cannot restart while cooldown is active")

        attack.update(0.07)
        expect(attack.isAttacking, "attack remains active during swing")
        expect(attack.isHitboxActive, "hitbox becomes active inside damage window")

        attack.update(0.10)
        expect(attack.isAttacking, "visual attack can outlive hitbox window")
        expect(!attack.isHitboxActive, "hitbox closes before attack animation ends")

        attack.update(0.20)
        expect(!attack.isAttacking, "attack animation eventually ends")
        expect(attack.tryStart(direction: .up), "up attack starts after cooldown")
        expect(attack.currentDirection == .up, "direction locks for the current swing")

        attack.update(attack.attackDuration)
        expect(!attack.isAttacking, "directional attack completes")
        expect(attack.currentDirection == .up, "completed swing preserves its last direction")

        attack.update(attack.cooldownDuration)
        expect(attack.tryStart(direction: .down), "down attack starts after cooldown")
        expect(attack.currentDirection == .down, "new swing replaces direction")

        print("AttackControllerTests: PASS")
    }
}
