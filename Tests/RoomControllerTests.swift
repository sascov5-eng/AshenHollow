import Foundation

@inline(__always)
func expectRoom(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RoomControllerTestsMain {
    static func main() {
        let controller = RoomController.makeV21Level()
        let expectedOrder: [RoomID] = [
            .approach,
            .lowerHall,
            .brokenGallery,
            .furnacePassage,
            .watcherHall,
            .wardenChamber
        ]

        expectRoom(controller.initialRoomID == .approach, "Approach is the V21 initial room")
        expectRoom(controller.orderedRoomIDs == expectedOrder, "V21 rooms preserve linear order")

        let approach = controller.room(.approach)!
        let lowerHall = controller.room(.lowerHall)!
        let brokenGallery = controller.room(.brokenGallery)!
        let furnacePassage = controller.room(.furnacePassage)!
        let watcherHall = controller.room(.watcherHall)!
        let wardenChamber = controller.room(.wardenChamber)!

        expectRoom(approach.bounds.width == 1200, "Every V21 room keeps the 1200 point room width")
        expectRoom(wardenChamber.bounds.width == 1200, "Boss room keeps the standard V21 room width")

        expectRoom(approach.worldOrigin == RoomPoint(x: 0, y: 0), "Room 1 origin")
        expectRoom(lowerHall.worldOrigin == RoomPoint(x: 1200, y: 0), "Room 2 origin")
        expectRoom(brokenGallery.worldOrigin == RoomPoint(x: 2400, y: 0), "Room 3 origin")
        expectRoom(furnacePassage.worldOrigin == RoomPoint(x: 3600, y: 0), "Room 4 origin")
        expectRoom(watcherHall.worldOrigin == RoomPoint(x: 4800, y: 0), "Room 5 origin")
        expectRoom(wardenChamber.worldOrigin == RoomPoint(x: 6000, y: 0), "Room 6 origin")

        expectRoom(approach.enemySpawns.isEmpty, "Approach has no enemies")
        expectRoom(lowerHall.enemySpawns.map(\.archetype) == [.grunt, .grunt], "Lower Hall has two Grunts")
        expectRoom(
            Set(brokenGallery.enemySpawns.map(\.archetype)) == Set([.grunt, .runner]),
            "Broken Gallery mixes Grunt and Runner"
        )
        expectRoom(
            Set(furnacePassage.enemySpawns.map(\.archetype)) == Set([.heavy, .grunt]),
            "Furnace Passage mixes Heavy and Grunt"
        )
        expectRoom(watcherHall.enemySpawns.count == 3, "Watcher Hall has three enemies")
        expectRoom(
            Set(watcherHall.enemySpawns.map(\.archetype)) == Set([.runner, .ranged, .grunt]),
            "Watcher Hall mixes Runner, Ranged, and Grunt"
        )
        expectRoom(wardenChamber.enemySpawns.map(\.archetype) == [.boss], "Warden Chamber contains only Ash Warden")

        expectRoom(!approach.requiresCombatClear, "Traversal room exit is immediately available")
        expectRoom(lowerHall.requiresCombatClear, "Lower Hall is combat gated")
        expectRoom(brokenGallery.requiresCombatClear, "Broken Gallery is combat gated")
        expectRoom(furnacePassage.requiresCombatClear, "Furnace Passage is combat gated")
        expectRoom(watcherHall.requiresCombatClear, "Watcher Hall is combat gated")
        expectRoom(wardenChamber.requiresCombatClear, "Boss room final exit is combat gated")

        expectRoom(
            controller.worldPoint(RoomPoint(x: 110, y: 130), in: .watcherHall) == RoomPoint(x: 4910, y: 130),
            "Room 5 local spawn maps into its world segment"
        )

        let noTransition = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 500, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .approach,
            combatCleared: true
        )
        expectRoom(noTransition == nil, "Middle of a room does not trigger an exit")

        let room1Exit = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .approach,
            combatCleared: true
        )
        expectRoom(room1Exit?.destinationRoomID == .lowerHall, "Approach exit targets Lower Hall")
        expectRoom(room1Exit?.destinationSpawn == RoomPoint(x: 110, y: 130), "Lower Hall entry spawn")
        expectRoom(room1Exit?.completesLevel == false, "Normal room transition does not complete level")

        let lockedCombatExit = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .lowerHall,
            combatCleared: false
        )
        expectRoom(lockedCombatExit == nil, "Combat room exit stays locked while required enemies live")

        let unlockedCombatExit = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .lowerHall,
            combatCleared: true
        )
        expectRoom(unlockedCombatExit?.destinationRoomID == .brokenGallery, "Cleared Lower Hall unlocks Broken Gallery")

        let lockedBossExit = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .wardenChamber,
            combatCleared: false
        )
        expectRoom(lockedBossExit == nil, "Final exit is locked while Ash Warden lives")

        let finalExit = controller.exitIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .wardenChamber,
            combatCleared: true
        )
        expectRoom(finalExit?.destinationRoomID == nil, "Final exit has no next room")
        expectRoom(finalExit?.destinationSpawn == nil, "Final exit has no destination spawn")
        expectRoom(finalExit?.completesLevel == true, "Boss clear unlocks LEVEL COMPLETE exit")

        let leftClamp = controller.clampedCameraX(targetX: -500, visibleHalfWidth: 300, in: .approach)
        let rightClamp = controller.clampedCameraX(targetX: 5000, visibleHalfWidth: 300, in: .approach)
        expectRoom(leftClamp == 300, "Camera clamps to room left edge")
        expectRoom(rightClamp == 900, "Camera clamps to room right edge")

        print("RoomControllerTests: PASS")
    }
}
