import Foundation

@inline(__always)
func expectBoss(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct BossControllerTestsMain {
    static func main() {
        var boss = BossController()
        expectBoss(boss.hp == 20, "Ash Warden starts at 20 HP")
        expectBoss(boss.phase == .one, "Ash Warden starts in phase one")
        expectBoss(boss.stage == .idle, "Boss starts idle")

        expectBoss(boss.begin(pattern: .charge), "Boss can begin charge")
        expectBoss(boss.currentPattern == .charge, "Charge becomes current pattern")
        expectBoss(boss.stage == .telegraph, "Pattern begins with telegraph")

        boss.update(dt: boss.telegraphDuration(for: .charge) + 0.01)
        expectBoss(boss.stage == .committed, "Charge becomes committed after telegraph")
        expectBoss(boss.isCommitted, "Committed flag is true")

        let committedPattern = boss.currentPattern
        _ = boss.applyPlayerHit(damage: 1)
        expectBoss(boss.hp == 19, "Boss takes player damage")
        expectBoss(boss.currentPattern == committedPattern, "Player hit does not cancel committed pattern")
        expectBoss(boss.stage == .committed, "Committed stage survives player hit")

        var phaseBoss = BossController()
        _ = phaseBoss.applyPlayerHit(damage: 10)
        expectBoss(phaseBoss.hp == 10, "Boss reaches half HP")
        expectBoss(phaseBoss.phase == .two, "Phase two begins at 50 percent")
        expectBoss(phaseBoss.volleyProjectileCount == 5, "Phase two volley is denser")
        expectBoss(
            phaseBoss.recoveryDuration(for: .slash) < BossController().recoveryDuration(for: .slash),
            "Phase two recovery is shorter"
        )

        _ = phaseBoss.applyPlayerHit(damage: 10)
        expectBoss(phaseBoss.hp == 0, "Boss can be defeated")
        expectBoss(phaseBoss.phase == .defeated, "Boss enters defeated phase")
        expectBoss(phaseBoss.stage == .idle, "Defeat cancels boss active pattern state")
        expectBoss(!phaseBoss.begin(pattern: .slash), "Defeated boss cannot start attacks")

        print("BossControllerTests: PASS")
    }
}
