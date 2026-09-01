import Foundation

extension RoomController {
    static func makeV24DemoV2() -> RoomController {
        let bounds = RoomRect(x: 0, y: 0, width: 1200, height: 560)

        func platform(
            _ x: Double,
            _ y: Double,
            _ width: Double,
            _ height: Double = 28
        ) -> RoomPlatform {
            RoomPlatform(
                center: RoomPoint(x: x, y: y),
                size: RoomSize(width: width, height: height)
            )
        }

        let approach = RoomDefinition(
            id: .approach,
            worldOrigin: RoomPoint(x: 4800, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                // Long onboarding floor. Its far-right edge becomes the DOWN transition.
                platform(460, 60, 920, 80),
                // One solid broad step: 70 pt top rise, no thin shelf catch.
                platform(400, 135, 300, 70),
                // Optional future-route teaser only.
                platform(760, 340, 260, 30)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 730, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 920, y: 0, width: 280, height: 170),
                    destinationRoomID: .lowerHall,
                    destinationSpawn: RoomPoint(x: 1040, y: 420)
                )
            ]
        )

        let lowerHall = RoomDefinition(
            id: .lowerHall,
            worldOrigin: RoomPoint(x: 4800, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1040, y: 420),
            platforms: [
                // Three broad terraces; descent uses overlaps rather than shelf jumping.
                platform(1020, 365, 360, 50),
                platform(700, 245, 420, 50),
                platform(280, 60, 560, 80)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 660, y: 300)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 250, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 90, width: 80, height: 180),
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
                // Long lane for readable Runner behavior; left end drops to Dash Shrine.
                platform(690, 60, 1020, 80),
                // High optional Wall Traversal structure.
                platform(1120, 330, 50, 340),
                platform(930, 500, 330, 40)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 820, y: 130)),
                EnemySpawn(id: 2, archetype: .runner, position: RoomPoint(x: 430, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 0, width: 180, height: 170),
                    destinationRoomID: .dashShrine,
                    destinationSpawn: RoomPoint(x: 1020, y: 130)
                ),
                RoomExit(
                    trigger: RoomRect(x: 1040, y: 470, width: 160, height: 90),
                    destinationRoomID: .ashenAscent,
                    destinationSpawn: RoomPoint(x: 1080, y: 130),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let dashCheckpoint = CheckpointSnapshot(
            id: .postDash,
            roomID: .dashShrine,
            spawn: RoomPoint(x: 1030, y: 130)
        )
        let dashShrine = RoomDefinition(
            id: .dashShrine,
            worldOrigin: RoomPoint(x: 3600, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1020, y: 130),
            platforms: [
                // Right takeoff bank and left landing bank: exactly one readable Dash lesson.
                platform(1020, 60, 360, 80),
                platform(300, 60, 600, 80),
                // Low recovery shelf below the 240 pt gap.
                platform(720, 20, 220, 30)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 90, width: 80, height: 180),
                    destinationRoomID: .furnacePassage,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .dash
                )
            ],
            shrine: AbilityShrinePlacement(
                id: .dash,
                ability: .dash,
                position: RoomPoint(x: 1030, y: 130),
                checkpoint: dashCheckpoint
            )
        )

        let furnacePassage = RoomDefinition(
            id: .furnacePassage,
            worldOrigin: RoomPoint(x: 2400, y: 0),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                // Two broad combat banks with one Dash-relevant 220 pt gap.
                platform(990, 60, 420, 80),
                platform(280, 60, 560, 80),
                // Only two solid terraces remain; the old eight-shelf zigzag is gone.
                platform(420, 135, 280, 70),
                platform(220, 205, 300, 70)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 900, y: 130)),
                EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 170, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 190, width: 100, height: 170),
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
                platform(600, 60, 1200, 80),
                // Low entry cover; still an easy 60 pt jump if crossed directly.
                platform(930, 130, 170, 60),
                // Deliberate ranged pedestal rather than a random thin shelf.
                platform(620, 135, 260, 70)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 430, y: 130)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 620, y: 200))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 90, width: 80, height: 180),
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
                platform(600, 60, 1200, 80),
                platform(500, 320, 40, 320),
                platform(720, 320, 40, 320),
                platform(340, 500, 320, 40)
            ],
            enemySpawns: [],
            requiresCombatClear: false,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 180, y: 480, width: 320, height: 80),
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
                // Entry arena.
                platform(1000, 60, 400, 80),
                // First wall-jump pair: 180 pt inner gap.
                platform(840, 230, 40, 140),
                platform(1060, 230, 40, 140),
                // Recovery 1.
                platform(650, 280, 280, 40),
                // Dash landing / recovery 2: 210 pt clear gap.
                platform(150, 280, 300, 40),
                // Short second wall pair above recovery 2.
                platform(80, 430, 40, 140),
                platform(300, 430, 40, 140),
                // Final broad recovery after wall+jump+Dash combination.
                platform(650, 480, 300, 40)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .runner, position: RoomPoint(x: 850, y: 130)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 650, y: 530))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 760, y: 460, width: 200, height: 100),
                    destinationRoomID: .wardenGate,
                    destinationSpawn: RoomPoint(x: 1090, y: 130),
                    requiredAbility: .wallTraversal
                )
            ]
        )

        let preWardenCheckpoint = CheckpointSnapshot(
            id: .preWarden,
            roomID: .wardenGate,
            spawn: RoomPoint(x: 300, y: 130)
        )
        let wardenGate = RoomDefinition(
            id: .wardenGate,
            worldOrigin: RoomPoint(x: 0, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 1090, y: 130),
            platforms: [
                // Left opening is the DOWN transition after the final encounter.
                platform(680, 60, 1040, 80),
                platform(820, 155, 260, 110)
            ],
            enemySpawns: [
                EnemySpawn(id: 1, archetype: .heavy, position: RoomPoint(x: 620, y: 136)),
                EnemySpawn(id: 2, archetype: .ranged, position: RoomPoint(x: 820, y: 240))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    trigger: RoomRect(x: 0, y: 0, width: 160, height: 170),
                    destinationRoomID: .wardenChamber,
                    destinationSpawn: RoomPoint(x: 120, y: 130)
                )
            ],
            checkpointTriggers: [
                CheckpointTrigger(
                    checkpoint: preWardenCheckpoint,
                    trigger: RoomRect(x: 180, y: 100, width: 240, height: 120)
                )
            ]
        )

        let wardenChamber = RoomDefinition(
            id: .wardenChamber,
            worldOrigin: RoomPoint(x: 0, y: 560),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                platform(600, 60, 1200, 80),
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
}
