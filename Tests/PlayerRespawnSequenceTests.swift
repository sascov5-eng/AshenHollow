import Foundation

@inline(__always)
func expectRespawn(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerRespawnSequenceTestsMain {
    static func main() {
        let sequence = PlayerRespawnSequence()

        expectRespawn(sequence.deathPauseDuration > 0, "death pause is positive")
        expectRespawn(sequence.fadeOutDuration > 0, "fade out is positive")
        expectRespawn(sequence.blackHoldDuration >= 0, "black hold is non-negative")
        expectRespawn(sequence.fadeInDuration > 0, "fade in is positive")

        expectRespawn(abs(sequence.respawnDelay - 0.57) < 0.0001, "respawn occurs after pause plus fade out")
        expectRespawn(abs(sequence.controlsUnlockDelay - 0.87) < 0.0001, "controls unlock after fade in completes")
        expectRespawn(sequence.controlsUnlockDelay > sequence.respawnDelay, "controls remain locked through fade in")

        print("PlayerRespawnSequenceTests: PASS")
    }
}
