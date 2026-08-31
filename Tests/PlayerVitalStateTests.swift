import Foundation

@inline(__always)
func expectVital(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerVitalStateTestsMain {
    static func main() {
        let vitals = PlayerVitalState(maxHP: 5, invulnerabilityDuration: 0.65)
        expectVital(vitals.health.hp == 5, "starts at full HP")
        expectVital(vitals.acceptedDamageSequence == 0, "damage sequence starts at zero")
        expectVital(!vitals.heal(1), "shared vitals cannot heal above max")

        expectVital(vitals.applyDamage(damage: 1, attackID: 7), "first damage is accepted")
        expectVital(vitals.health.hp == 4, "accepted damage changes shared HP")
        expectVital(vitals.acceptedDamageSequence == 1, "accepted damage increments sequence")
        expectVital(vitals.heal(1), "shared vitals can heal missing HP")
        expectVital(vitals.health.hp == 5, "shared heal restores the authoritative HP")

        expectVital(!vitals.applyDamage(damage: 1, attackID: 8), "i-frames reject immediate second damage")
        expectVital(vitals.health.hp == 5, "rejected damage leaves HP unchanged")
        expectVital(vitals.acceptedDamageSequence == 1, "rejected damage does not increment sequence")

        vitals.update(0.65)
        expectVital(vitals.applyDamage(damage: 2, attackID: 9), "damage is accepted after i-frames expire")
        expectVital(vitals.health.hp == 3, "shared HP remains authoritative")
        expectVital(vitals.acceptedDamageSequence == 2, "second accepted damage increments sequence")

        print("PlayerVitalStateTests: PASS")
    }
}
