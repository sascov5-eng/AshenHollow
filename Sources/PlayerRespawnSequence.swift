import Foundation

struct PlayerRespawnSequence {
    let deathPauseDuration: TimeInterval = 0.35
    let fadeOutDuration: TimeInterval = 0.22
    let blackHoldDuration: TimeInterval = 0.08
    let fadeInDuration: TimeInterval = 0.22

    var respawnDelay: TimeInterval {
        deathPauseDuration + fadeOutDuration
    }

    var controlsUnlockDelay: TimeInterval {
        respawnDelay + blackHoldDuration + fadeInDuration
    }
}
