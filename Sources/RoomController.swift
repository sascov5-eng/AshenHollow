import Foundation

enum RoomID: String, Equatable, Hashable {
    case approach
    case lowerHall
    case brokenGallery
    case furnacePassage
    case watcherHall
    case wardenChamber

    // Temporary compatibility aliases while the V20 SpriteKit runtime is migrated.
    static let entry: RoomID = .approach
    static let combat: RoomID = .lowerHall
}

struct RoomPoint: Equatable {
    let x: Double
    let y: Double
}

struct RoomSize: Equatable {
    let width: Double
    let height: Double
}

struct RoomRect: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }

    func intersects(_ other: RoomRect) -> Bool {
        maxX > other.minX &&
        minX < other.maxX &&
        maxY > other.minY &&
        minY < other.maxY
    }
}

struct RoomPlatform: Equatable {
    let center: RoomPoint
    let size: RoomSize
}

struct EnemySpawn: Equatable {
    let id: Int
    let archetype: EnemyArchetype
    let position: RoomPoint
}

struct RoomExit: Equatable {
    let trigger: RoomRect
    let destinationRoomID: RoomID?
    let destinationSpawn: RoomPoint?
    let completesLevel: Bool

    init(
        trigger: RoomRect,
        destinationRoomID: RoomID? = nil,
        destinationSpawn: RoomPoint? = nil,
        completesLevel: Bool = false
    ) {
        self.trigger = trigger
        self.destinationRoomID = destinationRoomID
        self.destinationSpawn = destinationSpawn
        self.completesLevel = completesLevel
    }
}

struct RoomDefinition: Equatable {
    let id: RoomID
    let worldOrigin: RoomPoint
    let bounds: RoomRect
    let playerSpawn: RoomPoint
    let platforms: [RoomPlatform]
    let enemySpawns: [EnemySpawn]
    let requiresCombatClear: Bool
    let exits: [RoomExit]

    // Compatibility for the V20 single-enemy runtime until Task 7 replaces it.
    var enemySpawn: RoomPoint? {
        enemySpawns.first?.position
    }
}

struct RoomTransition: Equatable {
    let destinationRoomID: RoomID
    let destinationSpawn: RoomPoint
}

struct RoomExitActivation: Equatable {
    let destinationRoomID: RoomID?
    let destinationSpawn: RoomPoint?
    let completesLevel: Bool
}

struct RoomController {
    let initialRoomID: RoomID
    let orderedRoomIDs: [RoomID]
    private let definitions: [RoomID: RoomDefinition]

    init(initialRoomID: RoomID, definitions: [RoomDefinition]) {
        self.initialRoomID = initialRoomID
        self.orderedRoomIDs = definitions.map(\.id)
        self.definitions = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })
    }

    func room(_ id: RoomID) -> RoomDefinition? {
        definitions[id]
    }

    func worldPoint(_ localPoint: RoomPoint, in roomID: RoomID) -> RoomPoint? {
        guard let room = definitions[roomID] else { return nil }
        return RoomPoint(
            x: room.worldOrigin.x + localPoint.x,
            y: room.worldOrigin.y + localPoint.y
        )
    }

    func exitIfNeeded(
        playerCenter: RoomPoint,
        playerSize: RoomSize,
        in roomID: RoomID,
        combatCleared: Bool
    ) -> RoomExitActivation? {
        guard let room = definitions[roomID] else { return nil }
        if room.requiresCombatClear && !combatCleared {
            return nil
        }

        let playerRect = RoomRect(
            x: playerCenter.x - playerSize.width * 0.5,
            y: playerCenter.y - playerSize.height * 0.5,
            width: playerSize.width,
            height: playerSize.height
        )

        guard let exit = room.exits.first(where: { $0.trigger.intersects(playerRect) }) else {
            return nil
        }

        return RoomExitActivation(
            destinationRoomID: exit.destinationRoomID,
            destinationSpawn: exit.destinationSpawn,
            completesLevel: exit.completesLevel
        )
    }

    // Compatibility wrapper for the V20 room runtime during migration.
    func transitionIfNeeded(
        playerCenter: RoomPoint,
        playerSize: RoomSize,
        in roomID: RoomID,
        combatCleared: Bool = true
    ) -> RoomTransition? {
        guard let activation = exitIfNeeded(
            playerCenter: playerCenter,
            playerSize: playerSize,
            in: roomID,
            combatCleared: combatCleared
        ),
        !activation.completesLevel,
        let destinationRoomID = activation.destinationRoomID,
        let destinationSpawn = activation.destinationSpawn else {
            return nil
        }

        return RoomTransition(
            destinationRoomID: destinationRoomID,
            destinationSpawn: destinationSpawn
        )
    }

    func clampedCameraX(
        targetX: Double,
        visibleHalfWidth: Double,
        in roomID: RoomID
    ) -> Double {
        guard let room = definitions[roomID] else { return targetX }

        let minCameraX = room.bounds.minX + visibleHalfWidth
        let maxCameraX = room.bounds.maxX - visibleHalfWidth

        if maxCameraX < minCameraX {
            return (room.bounds.minX + room.bounds.maxX) * 0.5
        }

        return max(minCameraX, min(maxCameraX, targetX))
    }

    static func makeV21Level() -> RoomController {
        let floor = RoomPlatform(
            center: RoomPoint(x: 600, y: 60),
            size: RoomSize(width: 1200, height: 80)
        )

        func exit(to destination: RoomID, spawnX: Double = 110) -> RoomExit {
            RoomExit(
                trigger: RoomRect(x: 1128, y: 100, width: 72, height: 160),
                destinationRoomID: destination,
                destinationSpawn: RoomPoint(x: spawnX, y: 130)
            )
        }

        let approach = RoomDefinition(
            id: .approach,
            worldOrigin: RoomPoint(x: 0, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 390, y: 185), size: RoomSize(width: 230, height: 28)),
                RoomPlatform(center: RoomPoint(x: 760, y: 245), size: RoomSize(width: 210, height: 28)),
                RoomPlatform(center: RoomPoint(x: 1030, y: 185), size: RoomSize(width: 180, height: 28))
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [exit(to: .lowerHall)]
        )

        let lowerHall = RoomDefinition(
            id: .lowerHall,
            worldOrigin: RoomPoint(x: 1200, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 470, y: 205), size: RoomSize(width: 250, height: 28)),
                RoomPlatform(center: RoomPoint(x: 900, y: 180), size: RoomSize(width: 220, height: 28))
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 520, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 890, y: 130))
            ],
            requiresCombatClear: true,
            exits: [exit(to: .brokenGallery)]
        )

        let brokenGallery = RoomDefinition(
            id: .brokenGallery,
            worldOrigin: RoomPoint(x: 2400, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 315, y: 190), size: RoomSize(width: 210, height: 28)),
                RoomPlatform(center: RoomPoint(x: 625, y: 270), size: RoomSize(width: 190, height: 28)),
                RoomPlatform(center: RoomPoint(x: 935, y: 210), size: RoomSize(width: 230, height: 28))
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 500, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 900, y: 130))
            ],
            requiresCombatClear: true,
            exits: [exit(to: .furnacePassage)]
        )

        let furnacePassage = RoomDefinition(
            id: .furnacePassage,
            worldOrigin: RoomPoint(x: 3600, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 410, y: 225), size: RoomSize(width: 260, height: 28)),
                RoomPlatform(center: RoomPoint(x: 835, y: 190), size: RoomSize(width: 290, height: 28))
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 660, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 965, y: 130))
            ],
            requiresCombatClear: true,
            exits: [exit(to: .watcherHall)]
        )

        let watcherHall = RoomDefinition(
            id: .watcherHall,
            worldOrigin: RoomPoint(x: 4800, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 335, y: 200), size: RoomSize(width: 220, height: 28)),
                RoomPlatform(center: RoomPoint(x: 760, y: 250), size: RoomSize(width: 270, height: 28)),
                RoomPlatform(center: RoomPoint(x: 1030, y: 315), size: RoomSize(width: 180, height: 28))
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .ranged, position: RoomPoint(x: 900, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 620, y: 130))
            ],
            requiresCombatClear: true,
            exits: [exit(to: .wardenChamber)]
        )

        let wardenChamber = RoomDefinition(
            id: .wardenChamber,
            worldOrigin: RoomPoint(x: 6000, y: 0),
            bounds: RoomRect(x: 0, y: 0, width: 1200, height: 560),
            playerSpawn: RoomPoint(x: 110, y: 130),
            platforms: [
                floor,
                RoomPlatform(center: RoomPoint(x: 600, y: 235), size: RoomSize(width: 260, height: 28))
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .boss, position: RoomPoint(x: 790, y: 140))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 1128, y: 100, width: 72, height: 160),
                    completesLevel: true
                )
            ]
        )

        return RoomController(
            initialRoomID: .approach,
            definitions: [
                approach,
                lowerHall,
                brokenGallery,
                furnacePassage,
                watcherHall,
                wardenChamber
            ]
        )
    }

    // Transitional compatibility name; V21 runtime uses makeV21Level directly.
    static func makeV20TestLayout() -> RoomController {
        makeV21Level()
    }
}
