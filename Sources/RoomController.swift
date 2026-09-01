import Foundation

enum RoomID: String, Equatable, Hashable, Codable {
    case approach
    case lowerHall
    case brokenGallery
    case dashShrine
    case furnacePassage
    case watcherHall
    case hollowShaft
    case ashenAscent
    case wardenGate
    case wardenChamber

    // Temporary compatibility aliases while the V20 SpriteKit runtime is migrated.
    static let entry: RoomID = .approach
    static let combat: RoomID = .lowerHall
}

struct RoomPoint: Equatable, Codable {
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

struct AbilityShrinePlacement: Equatable {
    let id: ShrineID
    let ability: PlayerAbility
    let position: RoomPoint
    let checkpoint: CheckpointSnapshot
}

struct CheckpointTrigger: Equatable {
    let checkpoint: CheckpointSnapshot
    let trigger: RoomRect
}

struct RoomExit: Equatable {
    let trigger: RoomRect
    let destinationRoomID: RoomID?
    let destinationSpawn: RoomPoint?
    let completesLevel: Bool
    let requiredAbility: PlayerAbility?

    init(
        trigger: RoomRect,
        destinationRoomID: RoomID? = nil,
        destinationSpawn: RoomPoint? = nil,
        completesLevel: Bool = false,
        requiredAbility: PlayerAbility? = nil
    ) {
        self.trigger = trigger
        self.destinationRoomID = destinationRoomID
        self.destinationSpawn = destinationSpawn
        self.completesLevel = completesLevel
        self.requiredAbility = requiredAbility
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
    let shrine: AbilityShrinePlacement?
    let checkpointTriggers: [CheckpointTrigger]

    init(
        id: RoomID,
        worldOrigin: RoomPoint,
        bounds: RoomRect,
        playerSpawn: RoomPoint,
        platforms: [RoomPlatform],
        enemySpawns: [EnemySpawn],
        requiresCombatClear: Bool,
        exits: [RoomExit],
        shrine: AbilityShrinePlacement? = nil,
        checkpointTriggers: [CheckpointTrigger] = []
    ) {
        self.id = id
        self.worldOrigin = worldOrigin
        self.bounds = bounds
        self.playerSpawn = playerSpawn
        self.platforms = platforms
        self.enemySpawns = enemySpawns
        self.requiresCombatClear = requiresCombatClear
        self.exits = exits
        self.shrine = shrine
        self.checkpointTriggers = checkpointTriggers
    }

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
        combatCleared: Bool,
        unlockedAbilities: Set<PlayerAbility> = []
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

        guard let exit = room.exits.first(where: { candidate in
            guard candidate.trigger.intersects(playerRect) else { return false }
            if let requiredAbility = candidate.requiredAbility,
               !unlockedAbilities.contains(requiredAbility) {
                return false
            }
            return true
        }) else {
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

    static func makeV24Demo() -> RoomController {
        let bounds = RoomRect(x: 0, y: 0, width: 1200, height: 560)

        func platform(_ x: Double, _ y: Double, _ width: Double, _ height: Double = 28) -> RoomPlatform {
            RoomPlatform(center: RoomPoint(x: x, y: y), size: RoomSize(width: width, height: height))
        }

        let fullFloor = platform(600, 60, 1200, 80)

        let approach = RoomDefinition(
            id: .approach,
            worldOrigin: RoomPoint(x: 0, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                platform(500, 60, 1000, 80),
                platform(1150, 60, 100, 80),
                platform(330, 185, 220),
                platform(690, 250, 200),
                platform(900, 190, 140)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 720, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 1000, y: 0, width: 100, height: 100),
                    destinationRoomID: .lowerHall,
                    destinationSpawn: RoomPoint(x: 1070, y: 130)
                )
            ]
        )

        let lowerHall = RoomDefinition(
            id: .lowerHall,
            worldOrigin: RoomPoint(x: 1200, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1070, y: 130),
            platforms: [
                fullFloor,
                platform(430, 205, 240),
                platform(820, 175, 210)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 520, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 850, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 100, width: 72, height: 160),
                    destinationRoomID: .brokenGallery,
                    destinationSpawn: RoomPoint(x: 1090, y: 130)
                )
            ]
        )

        let brokenGallery = RoomDefinition(
            id: .brokenGallery,
            worldOrigin: RoomPoint(x: 2400, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                platform(90, 60, 180, 80),
                platform(750, 60, 900, 80),
                platform(300, 190, 190),
                platform(590, 275, 180),
                platform(890, 215, 220),
                platform(1080, 390, 120)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 520, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 880, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 180, y: 0, width: 120, height: 100),
                    destinationRoomID: .dashShrine,
                    destinationSpawn: RoomPoint(x: 260, y: 130)
                ),
                RoomExit(
                    trigger: RoomRect(x: 1128, y: 330, width: 72, height: 170),
                    destinationRoomID: .ashenAscent,
                    destinationSpawn: RoomPoint(x: 1080, y: 430),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let dashCheckpoint = CheckpointSnapshot(
            id: .postDash,
            roomID: .dashShrine,
            spawn: RoomPoint(x: 360, y: 130)
        )
        let dashShrine = RoomDefinition(
            id: .dashShrine,
            worldOrigin: RoomPoint(x: 3600, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 260, y: 130),
            platforms: [
                platform(260, 60, 520, 80),
                platform(990, 60, 400, 80),
                platform(860, 160, 260),
                platform(650, 285, 170),
                platform(430, 375, 170),
                platform(150, 465, 220)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 410, width: 72, height: 150),
                    destinationRoomID: .furnacePassage,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .dash
                )
            ],
            shrine: AbilityShrinePlacement(
                id: .dash,
                ability: .dash,
                position: RoomPoint(x: 300, y: 130),
                checkpoint: dashCheckpoint
            )
        )

        let furnacePassage = RoomDefinition(
            id: .furnacePassage,
            worldOrigin: RoomPoint(x: 4800, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                fullFloor,
                platform(920, 180, 180),
                platform(650, 270, 170),
                platform(370, 365, 170),
                platform(140, 455, 180)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 790, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 470, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 80, y: 500, width: 150, height: 60),
                    destinationRoomID: .watcherHall,
                    destinationSpawn: RoomPoint(x: 1080, y: 130),
                    requiredAbility: .dash
                )
            ]
        )

        let watcherHall = RoomDefinition(
            id: .watcherHall,
            worldOrigin: RoomPoint(x: 6000, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1080, y: 130),
            platforms: [
                fullFloor,
                platform(335, 200, 220),
                platform(760, 250, 270)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .ranged, position: RoomPoint(x: 840, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 560, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 100, width: 72, height: 160),
                    destinationRoomID: .hollowShaft,
                    destinationSpawn: RoomPoint(x: 1040, y: 130)
                )
            ]
        )

        let wallCheckpoint = CheckpointSnapshot(
            id: .postWallTraversal,
            roomID: .hollowShaft,
            spawn: RoomPoint(x: 600, y: 150)
        )
        let hollowShaft = RoomDefinition(
            id: .hollowShaft,
            worldOrigin: RoomPoint(x: 7200, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1040, y: 130),
            platforms: [
                fullFloor,
                platform(480, 345, 40, 350),
                platform(720, 345, 40, 350),
                platform(360, 220, 120),
                platform(840, 330, 120),
                platform(360, 440, 120)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 500, y: 500, width: 200, height: 60),
                    destinationRoomID: .ashenAscent,
                    destinationSpawn: RoomPoint(x: 1080, y: 130),
                    requiredAbility: .wallTraversal
                )
            ],
            shrine: AbilityShrinePlacement(
                id: .wallTraversal,
                ability: .wallTraversal,
                position: RoomPoint(x: 600, y: 130),
                checkpoint: wallCheckpoint
            )
        )

        let ashenAscent = RoomDefinition(
            id: .ashenAscent,
            worldOrigin: RoomPoint(x: 8400, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1080, y: 130),
            platforms: [
                fullFloor,
                platform(990, 150, 220),
                platform(700, 250, 210),
                platform(405, 350, 210),
                platform(140, 455, 200)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 720, y: 294)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 420, y: 394))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 400, width: 72, height: 160),
                    destinationRoomID: .wardenGate,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let preWardenCheckpoint = CheckpointSnapshot(
            id: .preWarden,
            roomID: .wardenGate,
            spawn: RoomPoint(x: 880, y: 130)
        )
        let wardenGate = RoomDefinition(
            id: .wardenGate,
            worldOrigin: RoomPoint(x: 9600, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                platform(500, 60, 1000, 80),
                platform(1150, 60, 100, 80),
                platform(380, 205, 220),
                platform(760, 245, 220)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 650, y: 130)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 900, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 1000, y: 0, width: 100, height: 100),
                    destinationRoomID: .wardenChamber,
                    destinationSpawn: RoomPoint(x: 120, y: 130)
                )
            ],
            checkpointTriggers: [
                CheckpointTrigger(
                    checkpoint: preWardenCheckpoint,
                    trigger: RoomRect(x: 830, y: 100, width: 150, height: 120)
                )
            ]
        )

        let wardenChamber = RoomDefinition(
            id: .wardenChamber,
            worldOrigin: RoomPoint(x: 10800, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                fullFloor,
                platform(35, 300, 70, 400),
                platform(1165, 300, 70, 400),
                platform(600, 230, 260)
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
                dashShrine,
                furnacePassage,
                watcherHall,
                hollowShaft,
                ashenAscent,
                wardenGate,
                wardenChamber
            ]
        )
    }

    // Transitional compatibility name; V21 runtime uses makeV21Level directly.
    static func makeV20TestLayout() -> RoomController {
        makeV21Level()
    }
}
