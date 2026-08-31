import Foundation

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

var attack = AttackController()

expect(!attack.isAttacking, "attack starts idle")
expect(!attack.isHitboxActive, "hitbox starts inactive")
expect(attack.tryStart(), "first attack starts")
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
expect(attack.tryStart(), "attack can start again after cooldown")

print("AttackControllerTests: PASS")
