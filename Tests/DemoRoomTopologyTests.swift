import Foundation

@inline(__always)
func expectTopology(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func rectIsInsideStandardBounds(_ rect: RoomRect) -> Bool {
    rect.minX >= 0 && rect.maxX <= 1200 && rect.minY >= 0 && rect.maxY <= 560
}

private func pointIsInside(_ point: RoomPoint, bounds: RoomRect) -> Bool {
    point.x >= bounds.minX && point.x <= bounds.maxX &&
    point.y >= bounds.minY && point.y <= bounds.maxY
}

private func minX(_ platform: RoomPlatform) -> Double {
    platform.center.x - platform.size.width * 0.5
}

private func maxX(_ platform: RoomPlatform) -> Double {
    platform.center.x + platform.size.width * 0.5
}

private func minY(_ platform: RoomPlatform) -> Double {
    platform.center.y - platform.size.height * 0.5
}

private func horizontalGap(_ first: RoomPlatform, _ second: RoomPlatform) -> Double {
    if maxX(first) < minX(second) {
        return minX(second) - maxX(first)
    }
    if maxX(second) < minX(first) {
        return minX(first) - maxX(second)
    }
    return 0
}

@main
struct DemoRoomTopologyTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let expected: [RoomID] = [
            .approach,
            .lowerHall,
            .brokenGallery,
            .dashShrine,
            .furnacePassage,
            .watcherHall,
            .hollowShaft,
            .ashenAscent,
            .wardenGate,
            .wardenChamber
        ]

        expectTopology(level.initialRoomID == .approach, "V24 starts in Approach")
        expectTopology(level.orderedRoomIDs == expected, "V24 room order is stable")
        expectTopology(level.room(.dashShrine)?.shrine?.ability == .dash, "Dash Shrine grants Dash")
        expectTopology(level.room(.hollowShaft)?.shrine?.ability == .wallTraversal, "Hollow Shaft grants Wall Traversal")
        expectTopology(
            level.room(.wardenGate)?.checkpointTriggers.contains(where: { $0.checkpoint.id == .preWarden }) == true,
            "Warden Gate contains pre-boss checkpoint"
        )
        expectTopology(
            level.room(.wardenChamber)?.enemySpawns.contains(where: { $0.archetype == .boss }) == true,
            "Warden Chamber contains Ash Warden"
        )

        for roomID in expected {
            guard let room = level.room(roomID) else {
                expectTopology(false, "room \(roomID) exists")
                continue
            }

            expectTopology(room.bounds == RoomRect(x: 0, y: 0, width: 1200, height: 560), "\(roomID) uses standard local bounds")
            expectTopology(pointIsInside(room.playerSpawn, bounds: room.bounds), "\(roomID) player spawn stays inside local bounds")

            for roomExit in room.exits {
                expectTopology(rectIsInsideStandardBounds(roomExit.trigger), "\(roomID) exit trigger stays inside local bounds")

                if let destinationRoomID = roomExit.destinationRoomID,
                   let destinationSpawn = roomExit.destinationSpawn {
                    guard let destination = level.room(destinationRoomID) else {
                        expectTopology(false, "destination room \(destinationRoomID) exists")
                        continue
                    }
                    expectTopology(
                        pointIsInside(destinationSpawn, bounds: destination.bounds),
                        "\(roomID) destination spawn stays inside \(destinationRoomID) bounds"
                    )
                }
            }
        }

        expectTopology(level.room(.approach)?.exits.first?.destinationRoomID == .lowerHall, "Approach routes to Lower Hall")
        expectTopology(level.room(.lowerHall)?.exits.first?.destinationRoomID == .brokenGallery, "Lower Hall routes to Broken Gallery")
        expectTopology(level.room(.brokenGallery)?.exits.contains(where: { $0.destinationRoomID == .dashShrine }) == true, "Broken Gallery routes to Dash Shrine")
        expectTopology(level.room(.dashShrine)?.exits.first?.destinationRoomID == .furnacePassage, "Dash Shrine routes to Furnace Passage")
        expectTopology(level.room(.furnacePassage)?.exits.first?.destinationRoomID == .watcherHall, "Furnace Passage routes to Watcher Hall")
        expectTopology(level.room(.watcherHall)?.exits.first?.destinationRoomID == .hollowShaft, "Watcher Hall routes to Hollow Shaft")
        expectTopology(level.room(.hollowShaft)?.exits.first?.destinationRoomID == .ashenAscent, "Hollow Shaft routes to Ashen Ascent")
        expectTopology(level.room(.ashenAscent)?.exits.first?.destinationRoomID == .wardenGate, "Ashen Ascent routes to Warden Gate")
        expectTopology(level.room(.wardenGate)?.exits.first?.destinationRoomID == .wardenChamber, "Warden Gate routes to Warden Chamber")

        let dashRoom = level.room(.dashShrine)!
        expectTopology(dashRoom.enemySpawns.isEmpty, "Dash Shrine has no mandatory combat encounter")
        expectTopology(dashRoom.shrine?.ability == .dash, "Dash Shrine teaches Dash")
        let dashFloors = dashRoom.platforms
            .filter { abs($0.center.y - 60) < 0.001 && abs($0.size.height - 80) < 0.001 }
            .sorted { $0.center.x < $1.center.x }
        expectTopology(dashFloors.count == 2, "Dash Shrine has two recovery floor banks")
        if dashFloors.count == 2 {
            let gap = minX(dashFloors[1]) - maxX(dashFloors[0])
            expectTopology(gap >= 250, "Dash Shrine recovery gap is wider than ordinary running jump range")
            expectTopology(gap <= 290, "Dash Shrine recovery banks keep a controlled gap")
        }

        let dashLessonPlatforms = dashRoom.platforms
            .filter { $0.center.y > 100 && $0.size.height <= 30 }
            .sorted { $0.center.y < $1.center.y }
        expectTopology(dashLessonPlatforms.count == 3, "Dash Shrine uses two Dash surfaces plus one short ascent step")
        if dashLessonPlatforms.count == 3 {
            let lowerHeight = dashLessonPlatforms[0].center.y
            expectTopology(abs(dashLessonPlatforms[1].center.y - lowerHeight) < 0.001, "Dash takeoff and receiving surfaces share a safe height")
            let rise = dashLessonPlatforms[2].center.y - lowerHeight
            expectTopology(rise >= 55 && rise <= 75, "Dash Shrine post-lesson ascent stays in the 55–75 pt target band")
        }

        let hollowShaft = level.room(.hollowShaft)!
        expectTopology(hollowShaft.shrine?.ability == .wallTraversal, "Hollow Shaft teaches Wall Traversal")
        expectTopology(hollowShaft.exits.contains(where: { $0.trigger.minY >= 500 }), "Hollow Shaft exits through the upper band")
        let climbWalls = hollowShaft.platforms
            .filter { $0.size.width <= 50 && $0.size.height >= 300 }
            .sorted { $0.center.x < $1.center.x }
        expectTopology(climbWalls.count >= 2, "Hollow Shaft has opposing climb walls")
        if climbWalls.count >= 2 {
            let innerGap = minX(climbWalls[1]) - maxX(climbWalls[0])
            expectTopology(innerGap >= 160 && innerGap <= 220, "Hollow Shaft wall gap supports repeated wall jumps")
            expectTopology(minY(climbWalls[0]) >= 165 && minY(climbWalls[1]) >= 165, "Wall Traversal shrine remains walk-accessible below climb walls")
        }

        let watcher = level.room(.watcherHall)!
        expectTopology(watcher.enemySpawns.contains(where: { $0.archetype == .ranged }), "Watcher Hall keeps ranged pressure")
        expectTopology(watcher.enemySpawns.contains(where: { $0.archetype != .ranged }), "Watcher Hall keeps a support enemy")

        let gate = level.room(.wardenGate)!
        expectTopology(gate.enemySpawns.contains(where: { $0.archetype == .heavy }), "Warden Gate contains Heavy")
        expectTopology(gate.enemySpawns.contains(where: { $0.archetype == .ranged }), "Warden Gate contains Ranged")

        let gallery = level.room(.brokenGallery)!
        expectTopology(gallery.exits.contains(where: { $0.requiredAbility != nil }), "Broken Gallery exposes an ability-gated shortcut")

        let bossRoom = level.room(.wardenChamber)!
        expectTopology(bossRoom.enemySpawns.filter { $0.archetype == .boss }.count == 1, "Warden Chamber contains exactly one boss")

        print("DemoRoomTopologyTests: PASS")
    }
}
