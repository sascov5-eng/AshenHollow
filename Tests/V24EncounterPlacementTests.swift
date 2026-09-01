import Foundation

@inline(__always)
func expectEncounter(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private struct TestRect {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
}

private func platformRect(_ p: RoomPlatform) -> TestRect {
    TestRect(
        minX: p.center.x - p.size.width * 0.5,
        maxX: p.center.x + p.size.width * 0.5,
        minY: p.center.y - p.size.height * 0.5,
        maxY: p.center.y + p.size.height * 0.5
    )
}

private func bodyHalfSize(for archetype: EnemyArchetype) -> (x: Double, y: Double) {
    switch archetype {
    case .grunt: return (22, 31)
    case .runner: return (18, 27)
    case .heavy: return (29, 36)
    case .ranged: return (21, 30)
    case .boss: return (40, 46)
    }
}

private func playerSpawnIntersectsGeometry(_ room: RoomDefinition) -> Bool {
    let halfW = PlayerMovementTuning.current.colliderWidth * 0.5
    let halfH = PlayerMovementTuning.current.colliderHeight * 0.5
    let player = TestRect(
        minX: room.playerSpawn.x - halfW,
        maxX: room.playerSpawn.x + halfW,
        minY: room.playerSpawn.y - halfH,
        maxY: room.playerSpawn.y + halfH
    )

    return room.platforms.contains { platform in
        let p = platformRect(platform)
        let overlapX = min(player.maxX, p.maxX) - max(player.minX, p.minX)
        let overlapY = min(player.maxY, p.maxY) - max(player.minY, p.minY)
        return overlapX > 0.5 && overlapY > 0.5
    }
}

private func supportWidth(for spawn: EnemySpawn, in room: RoomDefinition) -> Double? {
    let half = bodyHalfSize(for: spawn.archetype)
    let bottom = spawn.position.y - half.y

    return room.platforms
        .filter { platform in
            let p = platformRect(platform)
            let horizontalSupport = spawn.position.x - half.x >= p.minX - 2 &&
                spawn.position.x + half.x <= p.maxX + 2
            let verticalContact = abs(bottom - p.maxY) <= 5
            return horizontalSupport && verticalContact
        }
        .map(\.size.width)
        .max()
}

private func spawnDistance(_ a: RoomPoint, _ b: RoomPoint) -> Double {
    hypot(a.x - b.x, a.y - b.y)
}

@main
struct V24EncounterPlacementTestsMain {
    static func main() {
        let level = RoomController.makeV24Demo()
        let ids: [RoomID] = [
            .approach, .lowerHall, .brokenGallery, .dashShrine, .furnacePassage,
            .watcherHall, .hollowShaft, .ashenAscent, .wardenGate, .wardenChamber
        ]

        for id in ids {
            let room = level.room(id)!
            expectEncounter(!playerSpawnIntersectsGeometry(room), "\(id) player spawn does not begin embedded in room geometry")

            for enemy in room.enemySpawns where enemy.archetype != .boss {
                expectEncounter(
                    spawnDistance(enemy.position, room.playerSpawn) >= 180,
                    "\(id) enemy \(enemy.id) keeps a safe entry distance"
                )
                expectEncounter(
                    supportWidth(for: enemy, in: room) != nil,
                    "\(id) enemy \(enemy.id) is placed on a real supporting surface"
                )
            }
        }

        let approach = level.room(.approach)!
        expectEncounter(approach.enemySpawns.count == 1, "Approach contains exactly one tutorial enemy")
        expectEncounter(approach.enemySpawns.first?.archetype == .grunt, "Approach tutorial enemy is a Grunt")

        expectEncounter(level.room(.dashShrine)!.enemySpawns.isEmpty, "Dash Shrine remains combat-free")
        expectEncounter(level.room(.hollowShaft)!.enemySpawns.isEmpty, "Hollow Shaft remains combat-free")

        let gallery = level.room(.brokenGallery)!
        let galleryRunner = gallery.enemySpawns.first(where: { $0.archetype == .runner })!
        expectEncounter(
            (supportWidth(for: galleryRunner, in: gallery) ?? 0) >= 500,
            "Broken Gallery Runner has a long horizontal lane"
        )

        let watcher = level.room(.watcherHall)!
        expectEncounter(watcher.enemySpawns.count == 2, "Watcher Hall uses exactly two enemies")
        expectEncounter(watcher.enemySpawns.filter { $0.archetype == .ranged }.count == 1, "Watcher Hall uses one Ranged")
        expectEncounter(watcher.enemySpawns.filter { $0.archetype == .grunt }.count == 1, "Watcher Hall uses one Grunt support")
        if let ranged = watcher.enemySpawns.first(where: { $0.archetype == .ranged }) {
            let vertical = abs(ranged.position.y - watcher.playerSpawn.y)
            let horizontal = abs(ranged.position.x - watcher.playerSpawn.x)
            expectEncounter(
                horizontal > ranged.archetype.stats.detectionRange || vertical > 95,
                "Watcher Ranged cannot fire immediately on room entry"
            )
        }

        let ascent = level.room(.ashenAscent)!
        let firstRecoveryTop = ascent.platforms
            .filter { $0.size.width >= 240 && $0.size.height <= 30 && $0.center.y < 250 }
            .map { $0.center.y + $0.size.height * 0.5 }
            .max() ?? 0
        for enemy in ascent.enemySpawns where enemy.archetype != .boss {
            let bottom = enemy.position.y - bodyHalfSize(for: enemy.archetype).y
            expectEncounter(
                bottom >= firstRecoveryTop + 180,
                "Ashen Ascent enemies appear only after the first combat-free traversal lesson"
            )
        }
        if let runner = ascent.enemySpawns.first(where: { $0.archetype == .runner }) {
            expectEncounter(
                (supportWidth(for: runner, in: ascent) ?? 0) >= 360,
                "Ashen Ascent Runner receives a readable late horizontal lane"
            )
        }

        let gate = level.room(.wardenGate)!
        let heavy = gate.enemySpawns.first(where: { $0.archetype == .heavy })!
        let ranged = gate.enemySpawns.first(where: { $0.archetype == .ranged })!
        expectEncounter(abs(heavy.position.y - 136) <= 2, "Warden Gate Heavy stands correctly on the ground route")
        expectEncounter(ranged.position.y > heavy.position.y + 80, "Warden Gate Ranged occupies separated elevation")
        expectEncounter(abs(ranged.position.x - heavy.position.x) >= 200, "Warden Gate Heavy/Ranged are spatially separated")

        print("V24EncounterPlacementTests: PASS")
    }
}
