from pathlib import Path

path = Path("Sources/V24LevelRebuildV2.swift")
text = path.read_text()

old = '''        let approach = RoomDefinition(
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
'''

new = '''        let approach = RoomDefinition(
            id: .approach,
            worldOrigin: RoomPoint(x: 4800, y: 1120),
            bounds: bounds,
            playerSpawn: RoomPoint(x: 120, y: 130),
            platforms: [
                // Tile-like onboarding floor: enough room to finish MOVE before the obstacle.
                platform(430, 60, 860, 80),
                // One solid block sitting directly on the floor. Top rise is exactly 64 pt.
                platform(450, 132, 320, 64)
            ],
            enemySpawns: [
                // Combat begins only after the player has crossed the tutorial block.
                EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 790, y: 130))
            ],
            requiresCombatClear: true,
            exits: [
                RoomExit(
                    // The floor ends at x=860; the trigger starts beyond it so the player
                    // physically leaves support and drops before transitioning downward.
                    trigger: RoomRect(x: 900, y: 0, width: 300, height: 220),
                    destinationRoomID: .lowerHall,
                    destinationSpawn: RoomPoint(x: 1040, y: 420)
                )
            ]
        )
'''

if new in text:
    print("Approach room already rebuilt")
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print("Rebuilt Approach room")
else:
    raise SystemExit("Approach room source signature not found")
