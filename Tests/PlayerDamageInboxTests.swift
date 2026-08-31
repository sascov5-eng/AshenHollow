import Foundation

@inline(__always)
func expectDamageInbox(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct PlayerDamageInboxTestsMain {
    static func main() {
        let inbox = PlayerDamageInbox()

        let first = inbox.enqueue(damage: 1, sourceX: 100)
        let second = inbox.enqueue(damage: 2, sourceX: 200)

        expectDamageInbox(first.token != second.token, "Damage events receive unique tokens")
        expectDamageInbox(first.damage == 1 && first.sourceX == 100, "First event preserves payload")
        expectDamageInbox(second.damage == 2 && second.sourceX == 200, "Second event preserves payload")

        let drained = inbox.drain()
        expectDamageInbox(drained.count == 2, "Drain returns queued events")
        expectDamageInbox(drained[0].token == first.token, "Drain preserves enqueue order")
        expectDamageInbox(drained[1].token == second.token, "Drain preserves second event")
        expectDamageInbox(inbox.drain().isEmpty, "Drain clears inbox")

        print("PlayerDamageInboxTests: PASS")
    }
}
