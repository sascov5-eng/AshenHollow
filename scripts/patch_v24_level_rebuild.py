from pathlib import Path

path = Path("Sources/RoomController.swift")
text = path.read_text()

start_marker = "    static func makeV24Demo() -> RoomController {"
end_marker = "    // Transitional compatibility name; V21 runtime uses makeV21Level directly."

start = text.index(start_marker)
end = text.index(end_marker, start)

new_function = r'''    static func makeV24Demo() -> RoomController {
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
'''

updated = text[:start] + new_function + "\n" + text[end:]
path.write_text(updated)
print("Rebuilt V24 ten-room blockout")
