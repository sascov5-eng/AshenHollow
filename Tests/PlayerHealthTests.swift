import Foundation

@inline(__always)
func expectPlayerHealth(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerHealthTestsMain {
    static func main() {
        var player = PlayerHealth(maxHP: 5, invulnerabilityDuration: 0.65)

        expectPlayerHealth(player.hp == 5, "player starts with 5 HP")
        expectPlayerHealth(player.isAlive, "player starts alive")
        expectPlayerHealth(!player.isInvulnerable, "player starts vulnerable")
        expectPlayerHealth(!player.heal(1), "full-health player cannot over-heal")

        expectPlayerHealth(player.applyHit(damage: 1, attackID: 1), "first enemy attack damages player")
        expectPlayerHealth(player.hp == 4, "first hit removes exactly 1 HP")
        expectPlayerHealth(player.isInvulnerable, "first hit starts i-frames")
        expectPlayerHealth(player.heal(1), "living damaged player can heal")
        expectPlayerHealth(player.hp == 5, "heal restores exactly one HP")
        expectPlayerHealth(!player.heal(1), "heal cannot exceed max HP")

        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 1), "same enemy swing cannot damage twice")
        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 2), "different swing is blocked during i-frames")
        expectPlayerHealth(player.hp == 5, "i-frames preserve healed HP")

        player.update(0.64)
        expectPlayerHealth(player.isInvulnerable, "i-frames are still active before duration ends")
        player.update(0.02)
        expectPlayerHealth(!player.isInvulnerable, "i-frames expire after duration")

        expectPlayerHealth(player.applyHit(damage: 1, attackID: 2), "new swing damages after i-frames")
        expectPlayerHealth(player.hp == 4, "accepted hit leaves 4 HP after earlier heal")

        for attackID in 3...6 {
            player.update(0.66)
            expectPlayerHealth(player.applyHit(damage: 1, attackID: attackID), "accepted hit \(attackID) damages player")
        }

        expectPlayerHealth(player.hp == 0, "final accepted hit reaches 0 HP")
        expectPlayerHealth(!player.isAlive, "player dies at 0 HP")
        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 7), "dead player ignores further hits")
        expectPlayerHealth(!player.heal(1), "dead player cannot be revived by Focus heal")

        print("PlayerHealthTests: PASS")
    }
}
