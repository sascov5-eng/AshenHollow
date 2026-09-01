import Foundation

@inline(__always)
func expectHitStop(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct CombatHitStopControllerTestsMain {
    static func main() {
        var hitStop = CombatHitStopController()
        expectHitStop(!hitStop.isActive, "hit-stop starts inactive")

        hitStop.request(duration: 0.045)
        expectHitStop(hitStop.isActive, "requested hit-stop becomes active")
        expectHitStop(hitStop.update(dt: 0.020), "combat remains frozen while time remains")
        expectHitStop(hitStop.isActive, "hit-stop remains active after partial update")

        hitStop.request(duration: 0.060)
        expectHitStop(hitStop.remaining >= 0.059, "longer request extends current hit-stop")
        expectHitStop(hitStop.update(dt: 0.061), "final active frame reports freeze")
        expectHitStop(!hitStop.isActive, "hit-stop expires cleanly")
        expectHitStop(!hitStop.update(dt: 0.016), "inactive controller no longer freezes combat")

        print("CombatHitStopControllerTests: PASS")
    }
}
