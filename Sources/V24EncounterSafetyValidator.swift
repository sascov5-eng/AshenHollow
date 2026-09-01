import Foundation

enum V24EncounterSafetyResult: Equatable {
    case safe
    case unsafe(String)
}

struct V24EncounterSafetyReport: Equatable {
    let roomResults: [RoomID: V24EncounterSafetyResult]
}

struct V24EncounterSafetyValidator {
    let tuning: PlayerMovementTuning

    func validate(level: RoomController) -> V24EncounterSafetyReport {
        let ids: [RoomID] = [
            .approach, .lowerHall, .brokenGallery, .dashShrine,
            .furnacePassage, .watcherHall, .hollowShaft,
            .ashenAscent, .wardenGate, .wardenChamber
        ]
        var results: [RoomID: V24EncounterSafetyResult] = [:]
        for id in ids {
            results[id] = validate(roomID: id, level: level)
        }
        return V24EncounterSafetyReport(roomResults: results)
    }

    private func validate(roomID: RoomID, level: RoomController) -> V24EncounterSafetyResult {
        guard let room = level.room(roomID) else {
            return .unsafe("missing room")
        }

        let landingZones = mandatoryLandingZones(in: room)

        for enemy in room.enemySpawns where enemy.archetype != .boss {
            let entryDistance = hypot(
                enemy.position.x - room.playerSpawn.x,
                enemy.position.y - room.playerSpawn.y
            )
            if entryDistance < 180 {
                return .unsafe("enemy \(enemy.id) is only \(Int(entryDistance)) pt from player spawn")
            }

            guard let supportWidth = supportWidth(for: enemy, in: room) else {
                return .unsafe("enemy \(enemy.id) has no supporting surface")
            }

            if enemy.archetype == .runner && supportWidth < 360 {
                return .unsafe("Runner \(enemy.id) has only \(Int(supportWidth)) pt of readable lane")
            }

            for zone in landingZones {
                if abs(enemy.position.x - zone.x) < 120 &&
                    abs(enemy.position.y - zone.y) < 90 {
                    return .unsafe("enemy \(enemy.id) occupies a mandatory landing safety zone")
                }
            }

            if enemy.archetype == .ranged && rangedCanOpenFireImmediately(enemy, in: room) {
                return .unsafe("Ranged \(enemy.id) has immediate unbroken line of fire at spawn")
            }
        }

        return .safe
    }

    private func mandatoryLandingZones(in room: RoomDefinition) -> [RoomPoint] {
        guard let route = V24MandatoryRoute.manifest(for: room.id), route.steps.count > 1 else {
            return []
        }

        var zones: [RoomPoint] = []
        for index in 1..<route.steps.count {
            let sourceIndex = route.steps[index - 1].platformIndex
            let targetIndex = route.steps[index].platformIndex
            guard room.platforms.indices.contains(sourceIndex),
                  room.platforms.indices.contains(targetIndex) else {
                continue
            }

            let source = room.platforms[sourceIndex]
            let target = room.platforms[targetIndex]
            let targetMinX = target.center.x - target.size.width * 0.5
            let targetMaxX = target.center.x + target.size.width * 0.5
            let landingX: Double
            if target.center.x < source.center.x {
                landingX = targetMaxX - min(90, target.size.width * 0.30)
            } else if target.center.x > source.center.x {
                landingX = targetMinX + min(90, target.size.width * 0.30)
            } else {
                landingX = target.center.x
            }
            let landingY = target.center.y + target.size.height * 0.5 + tuning.colliderHeight * 0.5
            zones.append(RoomPoint(x: landingX, y: landingY))
        }
        return zones
    }

    private func rangedCanOpenFireImmediately(_ enemy: EnemySpawn, in room: RoomDefinition) -> Bool {
        let horizontal = abs(enemy.position.x - room.playerSpawn.x)
        let vertical = abs(enemy.position.y - room.playerSpawn.y)
        guard horizontal <= enemy.archetype.stats.detectionRange, vertical <= 120 else {
            return false
        }

        let lowX = min(enemy.position.x, room.playerSpawn.x)
        let highX = max(enemy.position.x, room.playerSpawn.x)
        let blockingHeight = min(enemy.position.y, room.playerSpawn.y) + 20

        let hasBlocker = room.platforms.contains { platform in
            let minX = platform.center.x - platform.size.width * 0.5
            let maxX = platform.center.x + platform.size.width * 0.5
            let top = platform.center.y + platform.size.height * 0.5
            return minX > lowX + 30 && maxX < highX - 30 && top >= blockingHeight
        }
        return !hasBlocker
    }

    private func supportWidth(for enemy: EnemySpawn, in room: RoomDefinition) -> Double? {
        let half = bodyHalfSize(for: enemy.archetype)
        let bottom = enemy.position.y - half.y

        return room.platforms
            .filter { platform in
                let minX = platform.center.x - platform.size.width * 0.5
                let maxX = platform.center.x + platform.size.width * 0.5
                let top = platform.center.y + platform.size.height * 0.5
                return enemy.position.x - half.x >= minX - 2 &&
                    enemy.position.x + half.x <= maxX + 2 &&
                    abs(bottom - top) <= 6
            }
            .map(\.size.width)
            .max()
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
}
