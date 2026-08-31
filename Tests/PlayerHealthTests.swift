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

        expectPlayerHealth(player.applyHit(damage: 1, attackID: 1), "first enemy attack damages player")
        expectPlayerHealth(player.hp == 4, "first hit removes exactly 1 HP")
        expectPlayerHealth(player.isInvulnerable, "first hit starts i-frames")

        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 1), "same enemy swing cannot damage twice")
        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 2), "different swing is blocked during i-frames")
        expectPlayerHealth(player.hp == 4, "i-frames preserve HP")

        player.update(0.64)
        expectPlayerHealth(player.isInvulnerable, "i-frames are still active before duration ends")
        player.update(0.02)
        expectPlayerHealth(!player.isInvulnerable, "i-frames expire after duration")

        expectPlayerHealth(player.applyHit(damage: 1, attackID: 2), "new swing damages after i-frames")
        expectPlayerHealth(player.hp == 3, "second accepted hit leaves 3 HP")

        for attackID in 3...5 {
            player.update(0.66)
            expectPlayerHealth(player.applyHit(damage: 1, attackID: attackID), "accepted hit \(attackID) damages player")
        }

        expectPlayerHealth(player.hp == 0, "fifth accepted hit reaches 0 HP")
        expectPlayerHealth(!player.isAlive, "player dies at 0 HP")
        expectPlayerHealth(!player.applyHit(damage: 1, attackID: 6), "dead player ignores further hits")

        print("PlayerHealthTests: PASS")
    }
}
