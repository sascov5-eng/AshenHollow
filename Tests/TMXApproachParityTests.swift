import Foundation

@inline(__always)
func expectTMXApproach(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct TMXApproachParityTestsMain {
    static func main() {
        let parsed: RoomDefinition
        do {
            parsed = try TMXLevelLoader.loadProductionRoom(named: "approach")
        } catch {
            fputs("FAIL: unable to load production approach.tmx: \(error)\n", stderr)
            exit(1)
        }

        expectTMXApproach(parsed.id == .approach, "TMX room id is Approach")
        expectTMXApproach(parsed.worldOrigin == RoomPoint(x: 4800, y: 1120), "TMX preserves Approach world origin")
        expectTMXApproach(parsed.bounds == RoomRect(x: 0, y: 0, width: 1200, height: 560), "TMX preserves 1200x560 bounds")
        expectTMXApproach(parsed.playerSpawn == RoomPoint(x: 120, y: 130), "TMX preserves player spawn")
        expectTMXApproach(parsed.requiresCombatClear, "Approach still requires combat clear")

        expectTMXApproach(parsed.platforms.count == 2, "Approach keeps exactly two mandatory surfaces")
        expectTMXApproach(
            parsed.platforms[0] == RoomPlatform(
                center: RoomPoint(x: 430, y: 60),
                size: RoomSize(width: 860, height: 80)
            ),
            "platform 0 remains the main floor"
        )
        expectTMXApproach(
            parsed.platforms[1] == RoomPlatform(
                center: RoomPoint(x: 450, y: 132),
                size: RoomSize(width: 320, height: 64)
            ),
            "platform 1 remains the onboarding block"
        )

        expectTMXApproach(
            parsed.enemySpawns == [
                EnemySpawn(
                    id: 1,
                    archetype: .grunt,
                    position: RoomPoint(x: 790, y: 130)
                )
            ],
            "TMX preserves the single tutorial Grunt"
        )

        expectTMXApproach(parsed.exits.count == 1, "Approach keeps one exit")
        if let exit = parsed.exits.first {
            expectTMXApproach(exit.trigger == RoomRect(x: 900, y: 0, width: 300, height: 220), "TMX preserves downward exit trigger")
            expectTMXApproach(exit.destinationRoomID == .lowerHall, "TMX exit still enters Lower Hall")
            expectTMXApproach(exit.destinationSpawn == RoomPoint(x: 1040, y: 420), "TMX preserves Lower Hall destination spawn")
            expectTMXApproach(exit.requiredAbility == nil, "Approach exit remains ability-free")
            expectTMXApproach(!exit.completesLevel, "Approach exit does not complete the demo")
        }

        let baseline = RoomController.makeV24DemoV2()
        var definitions: [RoomDefinition] = []
        for roomID in baseline.orderedRoomIDs {
            if roomID == .approach {
                definitions.append(parsed)
            } else if let room = baseline.room(roomID) {
                definitions.append(room)
            }
        }

        let level = RoomController(
            initialRoomID: baseline.initialRoomID,
            definitions: definitions
        )

        let routeReport = V24RouteValidator(tuning: .current).validate(level: level)
        expectTMXApproach(
            routeReport.roomResults[.approach] == .safe,
            "TMX Approach passes the mandatory route validator: \(String(describing: routeReport.roomResults[.approach]))"
        )

        let encounterReport = V24EncounterSafetyValidator(tuning: .current).validate(level: level)
        expectTMXApproach(
            encounterReport.roomResults[.approach] == .safe,
            "TMX Approach passes encounter safety: \(String(describing: encounterReport.roomResults[.approach]))"
        )

        print("TMXApproachParityTests: PASS")
    }
}
