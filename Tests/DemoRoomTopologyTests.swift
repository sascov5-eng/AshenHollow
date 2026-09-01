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

        print("DemoRoomTopologyTests: PASS")
    }
}
