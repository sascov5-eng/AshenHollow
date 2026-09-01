import Foundation

@inline(__always)
func expectProgression(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DemoProgressionTestsMain {
    static func main() {
        var state = DemoProgressionState.fresh
        expectProgression(!state.has(.dash), "fresh state starts without Dash")
        expectProgression(!state.has(.wallTraversal), "fresh state starts without Wall Traversal")
        expectProgression(state.checkpoint.id == .approach, "fresh state uses Approach checkpoint")

        let accepted = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .postDash,
                roomID: .dashShrine,
                spawn: RoomPoint(x: 360, y: 130)
            )
        )
        expectProgression(accepted, "first Dash shrine activation succeeds")
        expectProgression(state.has(.dash), "Dash is unlocked")
        expectProgression(state.consumedShrines.contains(.dash), "Dash shrine is consumed")
        expectProgression(state.checkpoint.id == .postDash, "Dash checkpoint activates atomically")

        let checkpointBeforeDuplicate = state.checkpoint
        let duplicate = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .approach,
                roomID: .approach,
                spawn: RoomPoint(x: 120, y: 130)
            )
        )
        expectProgression(!duplicate, "consumed shrine cannot activate twice")
        expectProgression(state.checkpoint == checkpointBeforeDuplicate, "duplicate shrine cannot move checkpoint backward")

        let wallAccepted = state.claimShrine(
            .wallTraversal,
            ability: .wallTraversal,
            checkpoint: CheckpointSnapshot(
                id: .postWallTraversal,
                roomID: .hollowShaft,
                spawn: RoomPoint(x: 600, y: 150)
            )
        )
        expectProgression(wallAccepted, "first Wall Traversal shrine activation succeeds")
        expectProgression(state.has(.wallTraversal), "Wall Traversal is unlocked")
        expectProgression(state.has(.dash), "Dash stays unlocked after Wall Traversal acquisition")
        expectProgression(state.consumedShrines.contains(.wallTraversal), "Wall Traversal shrine is consumed")
        expectProgression(state.checkpoint.id == .postWallTraversal, "Wall Traversal checkpoint activates atomically")

        state = .fresh
        expectProgression(state.unlockedAbilities.isEmpty, "New Game reset clears abilities")
        expectProgression(state.consumedShrines.isEmpty, "New Game reset clears shrine state")
        expectProgression(state.checkpoint.id == .approach, "New Game reset restores Approach")

        print("DemoProgressionTests: PASS")
    }
}
