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

        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 68, "two accepted hits grant 68 Essence")
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 100, "Essence caps at 100")

        expectFocus(!focus.beginFocus(currentHP: 5, maxHP: 5), "cannot focus at full HP")
        expectFocus(focus.beginFocus(currentHP: 4, maxHP: 5), "focus starts with full resource and missing HP")
        expectFocus(focus.isFocusing, "focus reports active")

        focus.updateFocus(dt: 0.50)
        expectFocus(!focus.consumeCompletedHeal(), "half channel does not heal")
        focus.updateFocus(dt: 0.50)
        expectFocus(focus.consumeCompletedHeal(), "full channel completes one heal")
        expectFocus(focus.essence == 0, "completed heal spends Essence")
        expectFocus(!focus.isFocusing, "focus returns idle after completion")

        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        focus.gainFromAcceptedMeleeHit()
        expectFocus(focus.essence == 100, "resource can refill")
        expectFocus(focus.beginFocus(currentHP: 4, maxHP: 5), "second focus starts")
        focus.updateFocus(dt: 0.35)
        focus.cancelFocus()
        expectFocus(!focus.consumeCompletedHeal(), "cancelled focus does not heal")
        expectFocus(focus.essence == 100, "cancelled focus does not spend Essence")
        expectFocus(!focus.isFocusing, "cancelled focus returns idle")

        print("EssenceFocusControllerTests: PASS")
    }
}
