import Foundation

final class TestInteractionController {
    private let layout: TestLocationSpec
    private let session: TestSessionState

    init(layout: TestLocationSpec, session: TestSessionState) {
        self.layout = layout
        self.session = session
    }

    @discardableResult
    func activateLever(id: String) -> Bool {
        guard let lever = layout.interactions.first(where: { $0.id == id && ($0.kind == .lever || $0.kind == .shortcutLever) }),
              let linked = lever.linkedID else { return false }
        session.openedInteractions.insert(id)
        session.openedInteractions.insert(linked)
        return true
    }

    func isOpen(_ id: String) -> Bool {
        session.openedInteractions.contains(id)
    }

    @discardableResult
    func attackSecretWall(id: String) -> Bool {
        guard layout.interactions.contains(where: { $0.id == id && $0.kind == .breakableWall }) else { return false }
        session.destroyedSecrets.insert(id)
        return true
    }

    func isSecretDestroyed(_ id: String) -> Bool {
        session.destroyedSecrets.contains(id)
    }
}
