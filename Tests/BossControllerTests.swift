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

        expectBoss(boss.applyPlayerHit(damage: 1) == .accepted, "idle boss takes damage")
        expectBoss(boss.hp == 19, "idle hit removes one HP")

        expectBoss(boss.begin(pattern: .slash), "Boss can begin slash")
        expectBoss(boss.stage == .telegraph, "Pattern begins with telegraph")
        expectBoss(boss.applyPlayerHit(damage: 1) == .accepted, "telegraph boss remains damageable")
        expectBoss(boss.stage == .telegraph, "normal telegraph hit does not cancel attack")

        boss.update(dt: boss.telegraphDuration(for: .slash) + 0.01)
        expectBoss(boss.stage == .committed, "Slash becomes committed after telegraph")
        let committedPattern = boss.currentPattern
        expectBoss(boss.applyPlayerHit(damage: 1) == .accepted, "committed boss remains damageable")
        expectBoss(boss.currentPattern == committedPattern, "normal hit does not cancel committed pattern")
        expectBoss(boss.stage == .committed, "committed stage survives normal hit")

        var staggerBoss = BossController()
        for hit in 1...5 {
            expectBoss(staggerBoss.applyPlayerHit(damage: 1) == .accepted, "pre-stagger hit \(hit) is accepted")
        }
        expectBoss(staggerBoss.staggerHitCount == 5, "five phase-one hits build stagger")
        expectBoss(staggerBoss.applyPlayerHit(damage: 1) == .staggered, "sixth phase-one hit triggers stagger")
        expectBoss(staggerBoss.stage == .staggered, "boss enters stagger stage")
        expectBoss(staggerBoss.currentPattern == nil, "stagger cancels the current pattern")
        expectBoss(staggerBoss.applyPlayerHit(damage: 1) == .accepted, "boss stays damageable while staggered")
        expectBoss(staggerBoss.stage == .staggered, "hit during stagger does not end stagger")
        staggerBoss.update(dt: 1.44)
        expectBoss(staggerBoss.stage == .staggered, "stagger persists for the designed duration")
        staggerBoss.update(dt: 0.02)
        expectBoss(staggerBoss.stage == .idle, "stagger ends cleanly")
        expectBoss(staggerBoss.staggerHitCount == 0, "stagger counter resets after stagger")

        var phaseBoss = BossController()
        expectBoss(phaseBoss.applyPlayerHit(damage: 10) == .accepted, "large hit can cross phase threshold")
        expectBoss(phaseBoss.hp == 10, "Boss reaches half HP")
        expectBoss(phaseBoss.phase == .two, "Phase two begins at 50 percent")
        expectBoss(phaseBoss.staggerHitCount == 0, "phase transition rebases stagger progress")
        expectBoss(phaseBoss.volleyProjectileCount == 5, "Phase two volley is denser")
        expectBoss(
            phaseBoss.recoveryDuration(for: .slash) < BossController().recoveryDuration(for: .slash),
            "Phase two recovery is shorter"
        )

        expectBoss(phaseBoss.applyPlayerHit(damage: 10) == .defeated, "lethal hit reports defeated")
        expectBoss(phaseBoss.hp == 0, "Boss can be defeated")
        expectBoss(phaseBoss.phase == .defeated, "Boss enters defeated phase")
        expectBoss(phaseBoss.stage == .idle, "Defeat cancels boss active pattern state")
        expectBoss(!phaseBoss.begin(pattern: .slash), "Defeated boss cannot start attacks")

        print("BossControllerTests: PASS")
    }
}
