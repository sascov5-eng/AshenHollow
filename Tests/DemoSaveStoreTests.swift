import Foundation

@inline(__always)
func expectSave(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DemoSaveStoreTestsMain {
    static func main() {
        let suite = "AshenHollow.DemoSaveStoreTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = DemoSaveStore(defaults: defaults)

        expectSave(!store.hasSave, "empty store has no Continue state")

        defaults.set(Data([0xFF, 0x00, 0xA5]), forKey: "ashenHollow.v24.demoProgression")
        expectSave(store.load() == nil, "corrupted save cannot decode")
        expectSave(!store.hasSave, "corrupted save must not enable Continue")
        store.clear()

        var state = DemoProgressionState.fresh
        _ = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .postDash,
                roomID: .dashShrine,
                spawn: RoomPoint(x: 760, y: 130)
            )
        )
        store.save(state)

        expectSave(store.hasSave, "save enables Continue")
        expectSave(store.load() == state, "save round trip preserves exact state")

        let continued = DemoProgressionRuntime(store: store, launchMode: .continueGame)
        expectSave(continued.state == state, "Continue loads the durable progression state")
        expectSave(continued.state.has(.dash), "Continue keeps unlocked abilities")

        let restarted = DemoProgressionRuntime(store: store, launchMode: .newGame)
        expectSave(restarted.state == .fresh, "New Game resets runtime state")
        expectSave(store.load() == .fresh, "New Game persists the fresh reset immediately")

        store.clear()
        expectSave(!store.hasSave, "clear removes Continue state")
        expectSave(store.load() == nil, "clear removes decodable state")
        print("DemoSaveStoreTests: PASS")
    }
}
