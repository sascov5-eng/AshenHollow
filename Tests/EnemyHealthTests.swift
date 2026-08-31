import Foundation

@inline(__always)
func expectEnemy(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct EnemyHealthTestsMain {
    static func main() {
        var enemy = EnemyHealth(maxHP: 3)

        expectEnemy(enemy.hp == 3, "enemy starts with 3 HP")
        expectEnemy(enemy.isAlive, "enemy starts alive")

        expectEnemy(enemy.applyHit(damage: 1, attackID: 1), "first swing damages enemy")
        expectEnemy(enemy.hp == 2, "first swing removes exactly 1 HP")

        expectEnemy(!enemy.applyHit(damage: 1, attackID: 1), "same swing cannot damage twice")
        expectEnemy(enemy.hp == 2, "duplicate hit keeps HP unchanged")

        expectEnemy(enemy.applyHit(damage: 1, attackID: 2), "second swing damages enemy")
        expectEnemy(enemy.hp == 1, "second swing leaves 1 HP")

        expectEnemy(enemy.applyHit(damage: 1, attackID: 3), "third swing damages enemy")
        expectEnemy(enemy.hp == 0, "third swing reaches 0 HP")
        expectEnemy(!enemy.isAlive, "enemy dies at 0 HP")

        expectEnemy(!enemy.applyHit(damage: 1, attackID: 4), "dead enemy ignores further hits")
        expectEnemy(enemy.hp == 0, "HP never drops below zero")

        print("EnemyHealthTests: PASS")
    }
}
