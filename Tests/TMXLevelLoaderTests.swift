import Foundation

@inline(__always)
func expectTMX(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func parseTMX(_ xml: String) throws -> RoomDefinition {
    try TMXLevelLoader.loadRoom(data: Data(xml.utf8), sourceName: "inline.tmx")
}

func expectTMXError(
    _ message: String,
    _ operation: () throws -> Void,
    matches: (TMXLevelLoaderError) -> Bool
) {
    do {
        try operation()
        fputs("FAIL: expected error: \(message)\n", stderr)
        exit(1)
    } catch let error as TMXLevelLoaderError {
        if !matches(error) {
            fputs("FAIL: wrong error for \(message): \(error)\n", stderr)
            exit(1)
        }
    } catch {
        fputs("FAIL: non-TMX error for \(message): \(error)\n", stderr)
        exit(1)
    }
}

let validTMX = #"""
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.2" orientation="orthogonal" renderorder="right-down" width="30" height="14" tilewidth="40" tileheight="40" infinite="0">
 <properties>
  <property name="roomID" value="approach"/>
  <property name="worldOriginX" type="float" value="4800"/>
  <property name="worldOriginY" type="float" value="1120"/>
  <property name="requiresCombatClear" type="bool" value="true"/>
 </properties>
 <objectgroup name="Collision">
  <object id="1" class="platform" x="0" y="460" width="860" height="80"/>
  <object id="2" type="platform" x="290" y="396" width="320" height="64"/>
 </objectgroup>
 <objectgroup name="Entities">
  <object id="3" class="player_spawn" x="120" y="430"><point/></object>
  <object id="4" class="enemy" x="790" y="430">
   <properties>
    <property name="id" type="int" value="7"/>
    <property name="archetype" value="grunt"/>
   </properties>
   <point/>
  </object>
 </objectgroup>
 <objectgroup name="Triggers">
  <object id="5" class="room_exit" x="900" y="340" width="300" height="220">
   <properties>
    <property name="destinationRoom" value="lowerHall"/>
    <property name="destinationSpawnX" type="float" value="1040"/>
    <property name="destinationSpawnY" type="float" value="420"/>
    <property name="requiredAbility" value="wallTraversal"/>
   </properties>
  </object>
 </objectgroup>
</map>
"""#

@main
struct TMXLevelLoaderTestsMain {
    static func main() {
        do {
            let room = try parseTMX(validTMX)
            expectTMX(room.id == .approach, "roomID maps to existing RoomID")
            expectTMX(room.worldOrigin == RoomPoint(x: 4800, y: 1120), "world origin properties parse")
            expectTMX(room.bounds == RoomRect(x: 0, y: 0, width: 1200, height: 560), "finite map dimensions derive room bounds")
            expectTMX(room.playerSpawn == RoomPoint(x: 120, y: 130), "point Y converts from Tiled to room coordinates")
            expectTMX(room.requiresCombatClear, "boolean map property parses")

            expectTMX(room.platforms.count == 2, "two Collision/platform rectangles are emitted")
            expectTMX(room.platforms[0] == RoomPlatform(center: RoomPoint(x: 430, y: 60), size: RoomSize(width: 860, height: 80)), "first rectangle converts to expected center")
            expectTMX(room.platforms[1] == RoomPlatform(center: RoomPoint(x: 450, y: 132), size: RoomSize(width: 320, height: 64)), "platform source order is preserved")

            expectTMX(room.enemySpawns == [EnemySpawn(id: 7, archetype: .grunt, position: RoomPoint(x: 790, y: 130))], "enemy point and archetype map into existing EnemySpawn")
            expectTMX(room.exits.count == 1, "room exit parses")
            if let exit = room.exits.first {
                expectTMX(exit.trigger == RoomRect(x: 900, y: 0, width: 300, height: 220), "exit rectangle converts to room coordinates")
                expectTMX(exit.destinationRoomID == .lowerHall, "exit destination room parses")
                expectTMX(exit.destinationSpawn == RoomPoint(x: 1040, y: 420), "exit destination spawn parses")
                expectTMX(exit.requiredAbility == .wallTraversal, "optional required ability parses")
                expectTMX(!exit.completesLevel, "completesLevel defaults false")
            }
        } catch {
            fputs("FAIL: valid TMX threw: \(error)\n", stderr)
            exit(1)
        }

        let explicitBounds = validTMX.replacingOccurrences(
            of: #"<property name="requiresCombatClear" type="bool" value="true"/>"#,
            with: #"<property name="requiresCombatClear" type="bool" value="true"/><property name="boundsX" type="float" value="10"/><property name="boundsY" type="float" value="20"/><property name="boundsWidth" type="float" value="900"/><property name="boundsHeight" type="float" value="500"/>"#
        )
        do {
            let room = try parseTMX(explicitBounds)
            expectTMX(room.bounds == RoomRect(x: 10, y: 20, width: 900, height: 500), "explicit bounds override derived map bounds")
        } catch {
            fputs("FAIL: explicit bounds threw: \(error)\n", stderr)
            exit(1)
        }

        let duplicateSpawn = validTMX.replacingOccurrences(
            of: #"<object id="3" class="player_spawn" x="120" y="430"><point/></object>"#,
            with: #"<object id="3" class="player_spawn" x="120" y="430"><point/></object><object id="30" class="player_spawn" x="140" y="430"><point/></object>"#
        )
        expectTMXError("duplicate player spawn", {
            _ = try parseTMX(duplicateSpawn)
        }, matches: {
            if case .duplicatePlayerSpawn = $0 { return true }
            return false
        })

        let missingSpawn = validTMX.replacingOccurrences(
            of: #"<object id="3" class="player_spawn" x="120" y="430"><point/></object>"#,
            with: ""
        )
        expectTMXError("missing player spawn", {
            _ = try parseTMX(missingSpawn)
        }, matches: {
            if case .missingPlayerSpawn = $0 { return true }
            return false
        })

        let unknownEnemy = validTMX.replacingOccurrences(of: #"value="grunt""#, with: #"value="ghost""#)
        expectTMXError("unknown enemy archetype", {
            _ = try parseTMX(unknownEnemy)
        }, matches: {
            if case .unknownEnemyArchetype("ghost") = $0 { return true }
            return false
        })

        let invalidEnemyID = validTMX.replacingOccurrences(
            of: #"<property name="id" type="int" value="7"/>"#,
            with: #"<property name="id" type="int" value="seven"/>"#
        )
        expectTMXError("invalid integer property", {
            _ = try parseTMX(invalidEnemyID)
        }, matches: {
            if case .invalidProperty(let name, let value, _) = $0 {
                return name == "id" && value == "seven"
            }
            return false
        })

        let rotated = validTMX.replacingOccurrences(
            of: #"<object id="2" type="platform" x="290" y="396" width="320" height="64"/>"#,
            with: #"<object id="2" type="platform" x="290" y="396" width="320" height="64" rotation="15"/>"#
        )
        expectTMXError("rotated object", {
            _ = try parseTMX(rotated)
        }, matches: {
            if case .unsupportedRotation(let objectID, let degrees) = $0 {
                return objectID == 2 && abs(degrees - 15) < 0.001
            }
            return false
        })

        let isometric = validTMX.replacingOccurrences(of: #"orientation="orthogonal""#, with: #"orientation="isometric""#)
        expectTMXError("non-orthogonal map", {
            _ = try parseTMX(isometric)
        }, matches: {
            if case .unsupportedOrientation("isometric") = $0 { return true }
            return false
        })

        let infinite = validTMX.replacingOccurrences(of: #"infinite="0""#, with: #"infinite="1""#)
        expectTMXError("infinite map", {
            _ = try parseTMX(infinite)
        }, matches: {
            if case .infiniteMap = $0 { return true }
            return false
        })

        let unknownLayer = validTMX.replacingOccurrences(of: #"<objectgroup name="Triggers">"#, with: #"<objectgroup name="Mystery">"#)
        expectTMXError("unknown layer", {
            _ = try parseTMX(unknownLayer)
        }, matches: {
            if case .unknownLayer("Mystery") = $0 { return true }
            return false
        })

        let malformed = "<map><objectgroup>"
        expectTMXError("malformed XML", {
            _ = try parseTMX(malformed)
        }, matches: {
            if case .malformedXML = $0 { return true }
            return false
        })

        print("TMXLevelLoaderTests: PASS")
    }
}
