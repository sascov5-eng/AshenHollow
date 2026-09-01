import Foundation

@inline(__always)
func expectWorldReaction(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct V24WorldReactionTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()

        expectWorldReaction(
            V24WorldReactionResolver.shrineState(id: .dash, consumedShrines: []) == .active,
            "fresh Dash shrine is visibly active"
        )
        expectWorldReaction(
            V24WorldReactionResolver.shrineState(id: .dash, consumedShrines: [.dash]) == .dormant,
            "consumed Dash shrine becomes dormant"
        )
        expectWorldReaction(
            V24WorldReactionResolver.checkpointState(id: .postDash, currentCheckpoint: .approach) == .inactive,
            "future checkpoint is visibly inactive"
        )
        expectWorldReaction(
            V24WorldReactionResolver.checkpointState(id: .postDash, currentCheckpoint: .postDash) == .active,
            "activated checkpoint becomes visibly active"
        )

        let gallery = level.room(.brokenGallery)!
        let shortcut = gallery.exits.first(where: { $0.requiredAbility == .wallTraversal })!
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: shortcut,
                roomRequiresCombatClear: false,
                combatCleared: true,
                unlockedAbilities: []
            ) == .abilityLocked,
            "Broken Gallery high route reads locked before Wall Traversal"
        )
        expectWorldReaction(
            V24WorldReactionResolver.exitLabel(
                state: .abilityLocked,
                requiredAbility: .wallTraversal,
                shortcut: true,
                completionExit: false
            ) == "WALL",
            "locked high route communicates Wall requirement"
        )
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: shortcut,
                roomRequiresCombatClear: false,
                combatCleared: true,
                unlockedAbilities: [.wallTraversal]
            ) == .open,
            "Broken Gallery high route opens after Wall Traversal"
        )
        expectWorldReaction(
            V24WorldReactionResolver.exitLabel(
                state: .open,
                requiredAbility: .wallTraversal,
                shortcut: true,
                completionExit: false
            ) == "SHORTCUT",
            "opened high route visibly becomes SHORTCUT"
        )

        let gate = level.room(.wardenGate)!
        let gateExit = gate.exits.first!
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: gateExit,
                roomRequiresCombatClear: true,
                combatCleared: false,
                unlockedAbilities: [.dash, .wallTraversal]
            ) == .combatLocked,
            "combat gate stays closed while required enemies live"
        )
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: gateExit,
                roomRequiresCombatClear: true,
                combatCleared: true,
                unlockedAbilities: [.dash, .wallTraversal]
            ) == .open,
            "combat gate visibly opens after encounter clear"
        )

        let chamber = level.room(.wardenChamber)!
        let completionExit = chamber.exits.first!
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: completionExit,
                roomRequiresCombatClear: true,
                combatCleared: false,
                unlockedAbilities: [.dash, .wallTraversal]
            ) == .combatLocked,
            "demo completion exit is locked while Ash Warden lives"
        )
        expectWorldReaction(
            RoomExitPresentationResolver.state(
                for: completionExit,
                roomRequiresCombatClear: true,
                combatCleared: true,
                unlockedAbilities: [.dash, .wallTraversal]
            ) == .open,
            "Ash Warden defeat exposes completion exit"
        )
        expectWorldReaction(
            V24WorldReactionResolver.exitLabel(
                state: .open,
                requiredAbility: nil,
                shortcut: false,
                completionExit: true
            ) == "FINISH",
            "post-boss exit visibly reads FINISH"
        )

        var teaching = TraversalTeachingController()
        expectWorldReaction(teaching.prompt == nil, "traversal teaching is absent at game start")

        teaching.begin(for: .dash)
        expectWorldReaction(teaching.prompt == .dash, "fresh Dash acquisition starts Dash teaching")
        teaching.recordWallJump()
        expectWorldReaction(teaching.prompt == .dash, "Wall event cannot dismiss Dash teaching")
        teaching.recordDashStarted()
        expectWorldReaction(teaching.prompt == nil, "actual valid Dash dismisses Dash teaching")
        teaching.begin(for: .dash)
        expectWorldReaction(teaching.prompt == nil, "completed Dash teaching does not replay after respawn")

        teaching.begin(for: .wallTraversal)
        expectWorldReaction(teaching.prompt == .wallTraversal, "fresh Wall acquisition starts Wall teaching")
        teaching.recordDashStarted()
        expectWorldReaction(teaching.prompt == .wallTraversal, "Dash cannot dismiss Wall teaching")
        teaching.recordWallJump()
        expectWorldReaction(teaching.prompt == nil, "successful Wall Jump dismisses Wall teaching")
        teaching.begin(for: .wallTraversal)
        expectWorldReaction(teaching.prompt == nil, "completed Wall teaching does not replay after respawn")

        let continued = TraversalTeachingController()
        expectWorldReaction(continued.prompt == nil, "Continue with already-consumed shrines starts with no traversal prompt")

        print("V24WorldReactionTests: PASS")
    }
}
