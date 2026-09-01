import Foundation

@inline(__always)
func expectExitPresentation(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RoomExitPresentationResolverTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let gallery = level.room(.brokenGallery)!
        let shortcut = gallery.exits.first(where: { $0.requiredAbility == .wallTraversal })!

        expectExitPresentation(
            RoomExitPresentationResolver.state(
                for: shortcut,
                roomRequiresCombatClear: gallery.requiresCombatClear,
                combatCleared: true,
                unlockedAbilities: []
            ) == .abilityLocked,
            "shortcut is visibly ability-locked before Wall Traversal"
        )

        expectExitPresentation(
            RoomExitPresentationResolver.state(
                for: shortcut,
                roomRequiresCombatClear: gallery.requiresCombatClear,
                combatCleared: true,
                unlockedAbilities: [.wallTraversal]
            ) == .open,
            "shortcut becomes visually open after Wall Traversal"
        )

        let primary = gallery.exits.first!
        expectExitPresentation(
            RoomExitPresentationResolver.state(
                for: primary,
                roomRequiresCombatClear: gallery.requiresCombatClear,
                combatCleared: false,
                unlockedAbilities: []
            ) == .combatLocked,
            "mandatory combat lock still takes precedence on primary route"
        )

        print("RoomExitPresentationResolverTests: PASS")
    }
}
