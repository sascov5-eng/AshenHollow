import Foundation

struct PlayerDamageEvent: Equatable {
    let token: Int
    let damage: Int
    let sourceX: Double
}

final class PlayerDamageInbox: NSObject {
    private var nextToken: Int = 1
    private var events: [PlayerDamageEvent] = []

    @discardableResult
    func enqueue(damage: Int, sourceX: Double) -> PlayerDamageEvent {
        let event = PlayerDamageEvent(
            token: nextToken,
            damage: max(0, damage),
            sourceX: sourceX
        )
        nextToken += 1
        events.append(event)
        return event
    }

    func drain() -> [PlayerDamageEvent] {
        let drained = events
        events.removeAll(keepingCapacity: true)
        return drained
    }

    func clear() {
        events.removeAll(keepingCapacity: true)
    }
}
