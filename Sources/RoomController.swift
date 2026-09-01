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

        // World origins are a real spatial map, not progression indices.
        // DOWN / LEFT / DOWN / LEFT / UP / LEFT / UP / LEFT / DOWN.
        let approach = RoomDefinition(
            id: .approach,
            worldOrigin: RoomPoint(x: 4800, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                platform(480, 60, 960, 80),
                // Onboarding jump: +60 pt top rise, broad landing.
                platform(530, 146, 260),
                // High teaser that reads as a later traversal route, not a mandatory jump.
                platform(850, 315, 240)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 790, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 980, y: 0, width: 220, height: 100),
                    destinationRoomID: .lowerHall,
                    destinationSpawn: RoomPoint(x: 1060, y: 410)
                )
            ]
        )

        let lowerHall = RoomDefinition(
            id: .lowerHall,
            worldOrigin: RoomPoint(x: 4800, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1060, y: 410),
            platforms: [
                // Entry terrace: the player arrives from above/right.
                platform(940, 366, 400),
                // Broad intermediate terrace for a readable descent.
                platform(650, 271, 300),
                // Main combat floor and left exit approach.
                platform(350, 60, 700, 80)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 560, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 230, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 100, width: 72, height: 170),
                    destinationRoomID: .brokenGallery,
                    destinationSpawn: RoomPoint(x: 1090, y: 130)
                )
            ]
        )

        let brokenGallery = RoomDefinition(
            id: .brokenGallery,
            worldOrigin: RoomPoint(x: 3600, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                // Long right lane gives Runner room to read and accelerate.
                platform(880, 60, 640, 80),
                // Main left bank; the 60 pt gap is ordinary traversal, not a gate.
                platform(360, 60, 280, 80),
                // High Wall Traversal teaser/shortcut structure.
                platform(1080, 330, 40, 300),
                platform(950, 486, 220)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 480, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 820, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 0, width: 190, height: 100),
                    destinationRoomID: .dashShrine,
                    destinationSpawn: RoomPoint(x: 1000, y: 190)
                ),
                RoomExit(
                    trigger: RoomRect(x: 1128, y: 360, width: 72, height: 190),
                    destinationRoomID: .ashenAscent,
                    destinationSpawn: RoomPoint(x: 1080, y: 130),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let dashCheckpoint = CheckpointSnapshot(
            id: .postDash,
            roomID: .dashShrine,
            spawn: RoomPoint(x: 1000, y: 190)
        )
        let dashShrine = RoomDefinition(
            id: .dashShrine,
            worldOrigin: RoomPoint(x: 3600, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1000, y: 190),
            platforms: [
                // Recovery banks below the teaching transfer. Their 260 pt gap also
                // preserves the original "ordinary jump cannot clear this" contract.
                platform(250, 60, 500, 80),
                platform(980, 60, 440, 80),
                // Actual Dash lesson: same-height thin surfaces, 240 pt clear gap.
                platform(1000, 146, 400),
                platform(420, 146, 280),
                // One forgiving post-Dash ascent step: +65 pt, 20 pt clear gap.
                platform(140, 211, 240)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 175, width: 72, height: 150),
                    destinationRoomID: .furnacePassage,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .dash
                )
            ],
            shrine: AbilityShrinePlacement(
                id: .dash,
                ability: .dash,
                position: RoomPoint(x: 1040, y: 190),
                checkpoint: dashCheckpoint
            )
        )

        let furnacePassage = RoomDefinition(
            id: .furnacePassage,
            worldOrigin: RoomPoint(x: 2400, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                // Application gap: Dash is useful, but the landing banks are broad.
                platform(900, 60, 600, 80),
                platform(200, 60, 400, 80),
                // Safe 60–65 pt vertical rhythm toward the UP exit.
                platform(280, 146, 240),
                platform(520, 211, 240),
                platform(280, 276, 260),
                platform(520, 341, 260),
                platform(300, 406, 280),
                platform(160, 476, 320)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 820, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 120, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 70, y: 500, width: 190, height: 60),
                    destinationRoomID: .watcherHall,
                    destinationSpawn: RoomPoint(x: 1080, y: 130),
                    requiredAbility: .dash
                )
            ]
        )

        let watcherHall = RoomDefinition(
            id: .watcherHall,
            worldOrigin: RoomPoint(x: 2400, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1080, y: 130),
            platforms: [
                fullFloor,
                // Entry-side cover interrupts the first projectile lane.
                platform(980, 166, 220),
                // Readable elevated firing position.
                platform(650, 216, 260)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .ranged, position: RoomPoint(x: 650, y: 260)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 470, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 100, width: 72, height: 170),
                    destinationRoomID: .hollowShaft,
                    destinationSpawn: RoomPoint(x: 1040, y: 130)
                )
            ]
        )

        let wallCheckpoint = CheckpointSnapshot(
            id: .postWallTraversal,
            roomID: .hollowShaft,
            spawn: RoomPoint(x: 600, y: 130)
        )
        let hollowShaft = RoomDefinition(
            id: .hollowShaft,
            worldOrigin: RoomPoint(x: 1200, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1040, y: 130),
            platforms: [
                fullFloor,
                // One clean 180 pt inner gap. Walls begin above the shrine floor so
                // the unlock remains reachable without already owning Wall Traversal.
                platform(490, 335, 40, 330),
                platform(710, 335, 40, 330),
                // Recovery ledge is outside the shaft so it cannot become a ceiling.
                platform(315, 511, 260)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 180, y: 500, width: 260, height: 60),
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
            worldOrigin: RoomPoint(x: 1200, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1080, y: 130),
            platforms: [
                // Entry bank and right wall establish the first clean wall-jump read.
                platform(1020, 60, 360, 80),
                platform(1160, 260, 40, 320),
                // First recovery after Wall Jump.
                platform(820, 186, 280),
                // Same-height Dash receiving platform; 220 pt clear gap.
                platform(320, 186, 280),
                // Second wall-jump pair starts just above the Dash landing.
                platform(170, 350, 40, 260),
                platform(390, 350, 40, 260),
                // Recovery outside the wall pair, then an easy same-height bridge to exit.
                platform(560, 496, 280),
                platform(200, 496, 400)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 820, y: 230)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 560, y: 540))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 470, width: 72, height: 90),
                    destinationRoomID: .wardenGate,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let preWardenCheckpoint = CheckpointSnapshot(
            id: .preWarden,
            roomID: .wardenGate,
            spawn: RoomPoint(x: 340, y: 130)
        )
        let wardenGate = RoomDefinition(
            id: .wardenGate,
            worldOrigin: RoomPoint(x: 0, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                // Broad combat floor; left edge intentionally becomes the DOWN exit after clear.
                platform(700, 60, 1000, 80),
                // Optional positional advantage, never a mandatory ladder.
                platform(760, 206, 280)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 620, y: 130)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 870, y: 250))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 0, width: 190, height: 100),
                    destinationRoomID: .wardenChamber,
                    destinationSpawn: RoomPoint(x: 120, y: 130)
                )
            ],
            checkpointTriggers: [
                CheckpointTrigger(
                    checkpoint: preWardenCheckpoint,
                    trigger: RoomRect(x: 230, y: 100, width: 220, height: 120)
                )
            ]
        )

        let wardenChamber = RoomDefinition(
            id: .wardenChamber,
            worldOrigin: RoomPoint(x: 0, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                // Clean boss floor plus side walls. No mid-air catch platform.
                fullFloor,
                platform(35, 300, 70, 400),
                platform(1165, 300, 70, 400)
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
