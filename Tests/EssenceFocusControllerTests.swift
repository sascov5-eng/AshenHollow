import Foundation

@inline(__always)
func expectFocus(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct EssenceFocusControllerTestsMain {
    static func main() {
        var focus = EssenceFocusController()

        expectFocus(focus.essence == 0, "Essence starts empty")
        expectFocus(!focus.isFocusing, "Focus starts idle")
        expectFocus(focus.focusProgress == 0, "Focus progress starts at zero")

        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 68, "two accepted hits grant 68 Essence")
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 100, "Essence caps at 100")

        expectFocus(!focus.beginFocus(currentHP: 5, maxHP: 5), "cannot focus at full HP")
        expectFocus(focus.beginFocus(currentHP: 4, maxHP: 5), "focus starts with enough Essence and missing HP")
        expectFocus(focus.isFocusing, "focus reports active")
        expectFocus(focus.focusProgress == 0, "Focus starts at zero progress")

        focus.updateFocus(dt: 0.50)
        expectFocus(abs(focus.focusProgress - 0.5) < 0.001, "half channel exposes half progress")
        expectFocus(!focus.consumeCompletedHeal(), "half channel does not heal")
        expectFocus(focus.essence == 100, "partial channel spends nothing")

        focus.updateFocus(dt: 0.50)
        expectFocus(!focus.isFocusing, "completed channel stops focusing")
        expectFocus(focus.essence == 0, "completion spends Essence atomically")
        expectFocus(
            !focus.beginFocus(currentHP: 4, maxHP: 5),
            "pending completed heal blocks a second channel"
        )

        focus.cancelFocus() // finger release immediately after completion
        expectFocus(
            focus.consumeCompletedHeal(),
            "release after completion cannot erase the completed heal"
        )
        expectFocus(!focus.consumeCompletedHeal(), "completed heal emits exactly once")
        expectFocus(focus.focusProgress == 0, "completed Focus resets progress")

        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 100, "resource can refill")
        expectFocus(focus.beginFocus(currentHP: 4, maxHP: 5), "second focus starts")
        focus.updateFocus(dt: 0.70)
        focus.cancelFocus()
        expectFocus(!focus.consumeCompletedHeal(), "release before completion cancels heal")
        expectFocus(focus.essence == 100, "early cancellation spends no Essence")
        expectFocus(!focus.isFocusing, "cancelled Focus returns idle")
        expectFocus(focus.focusProgress == 0, "cancelled Focus resets progress")

        print("EssenceFocusControllerTests: PASS")
    }
}
