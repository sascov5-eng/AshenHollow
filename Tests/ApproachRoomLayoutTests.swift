import Foundation

@inline(__always)
func expectApproach(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private func minX(_ platform: RoomPlatform) -> Double {
    platform.center.x - platform.size.width * 0.5
}

private func maxX(_ platform: RoomPlatform) -> Double {
    platform.center.x + platform.size.width * 0.5
}

private func top(_ platform: RoomPlatform) -> Double {
    platform.center.y + platform.size.height * 0.5
}

private func bottom(_ platform: RoomPlatform) -> Double {
    platform.center.y - platform.size.height * 0.5
}

@main
struct ApproachRoomLayoutTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let room = level.room(.approach)!

        expectApproach(room.platforms.count == 2, "Approach uses only the main floor and one tutorial block")

        let floorCandidates = room.platforms.filter {
            abs($0.size.height - 80) < 0.001 && abs(top($0) - 100) < 0.001
        }
        expectApproach(floorCandidates.count == 1, "Approach has one main floor")

        let tutorialBlocks = room.platforms.filter {
            abs($0.size.width - 320) < 0.001 && abs($0.size.height - 64) < 0.001
        }
        expectApproach(tutorialBlocks.count == 1, "Approach has one 320x64 onboarding block")

        if let floor = floorCandidates.first, let block = tutorialBlocks.first {
            expectApproach(abs(bottom(block) - top(floor)) < 0.001, "tutorial block sits directly on the main floor")
            expectApproach(abs(top(block) - top(floor) - 64) < 0.001, "tutorial jump rise is exactly 64 pt")

            let travelBeforeObstacle = minX(block) - room.playerSpawn.x
            expectApproach(travelBeforeObstacle >= 150 && travelBeforeObstacle <= 220, "MOVE tutorial has 150–220 pt before the jump obstacle")

            expectApproach(maxX(floor) >= 860 && maxX(floor) <= 900, "main floor ends at the deliberate downward exit edge")
        }

        expectApproach(room.enemySpawns.count == 1, "Approach keeps exactly one tutorial enemy")
        if let enemy = room.enemySpawns.first {
            expectApproach(enemy.archetype == .grunt, "Approach tutorial enemy remains a Grunt")
            expectApproach(enemy.position.x >= 760 && enemy.position.x <= 820, "Grunt waits after the jump lesson")
            expectApproach(enemy.position.x - room.playerSpawn.x >= 600, "Grunt cannot pressure the initial MOVE/JUMP lesson")
        }

        expectApproach(room.exits.count == 1, "Approach has one route exit")
        if let exit = room.exits.first, let floor = floorCandidates.first {
            expectApproach(exit.destinationRoomID == .lowerHall, "Approach exits to Lower Hall")
            expectApproach(exit.trigger.x >= maxX(floor) - 1, "exit trigger begins at the physical floor edge")
            expectApproach(exit.trigger.width >= 300, "downward exit has a broad drop zone")
            expectApproach(exit.trigger.height >= 200, "downward exit captures the falling player safely")
            expectApproach((exit.destinationSpawn?.y ?? 0) >= 380, "Lower Hall destination starts on its upper terrace")
        }

        print("ApproachRoomLayoutTests: PASS")
    }
}
