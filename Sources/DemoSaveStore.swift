import Foundation

enum DemoLaunchMode {
    case newGame
    case continueGame
}

struct DemoSaveStore {
    private let defaults: UserDefaults
    private let key = "ashenHollow.v24.demoProgression"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSave: Bool {
        load() != nil
    }

    func load() -> DemoProgressionState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DemoProgressionState.self, from: data)
    }

    func save(_ state: DemoProgressionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

final class DemoProgressionRuntime: NSObject {
    private let store: DemoSaveStore
    private(set) var state: DemoProgressionState

    init(store: DemoSaveStore = DemoSaveStore(), launchMode: DemoLaunchMode) {
        self.store = store
        switch launchMode {
        case .newGame:
            store.clear()
            state = .fresh
            store.save(state)
        case .continueGame:
            if let loaded = store.load() {
                state = loaded
            } else {
                state = .fresh
                store.save(state)
            }
        }
        super.init()
    }

    @discardableResult
    func claimShrine(
        _ shrine: ShrineID,
        ability: PlayerAbility,
        checkpoint: CheckpointSnapshot
    ) -> Bool {
        guard state.claimShrine(shrine, ability: ability, checkpoint: checkpoint) else {
            return false
        }
        store.save(state)
        return true
    }

    func activateCheckpoint(_ checkpoint: CheckpointSnapshot) {
        state.activateCheckpoint(checkpoint)
        store.save(state)
    }
}
