import Foundation
import CoreGraphics

enum TestLocationLayout {
    static let v14: TestLocationSpec = {
        let bounds = CGRect(x: 0, y: 0, width: 9000, height: 2200)

        let solids: [CGRect] = [
            CGRect(x: 0, y: 0, width: 1450, height: 90),
            CGRect(x: 520, y: 170, width: 190, height: 24),
            CGRect(x: 820, y: 245, width: 210, height: 24),
            CGRect(x: 1450, y: 0, width: 1750, height: 90),
            CGRect(x: 2050, y: 215, width: 220, height: 24),
            CGRect(x: 2630, y: 340, width: 220, height: 24),
            CGRect(x: 3200, y: 0, width: 1900, height: 90),
            CGRect(x: 3550, y: 190, width: 260, height: 24),
            CGRect(x: 3970, y: 285, width: 260, height: 24),
            CGRect(x: 4460, y: 190, width: 260, height: 24),
            CGRect(x: 5050, y: 0, width: 280, height: 90),
            CGRect(x: 5320, y: 90, width: 56, height: 1180),
            CGRect(x: 5780, y: 90, width: 56, height: 1180),
            CGRect(x: 5376, y: 280, width: 150, height: 22),
            CGRect(x: 5630, y: 455, width: 150, height: 22),
            CGRect(x: 5376, y: 635, width: 150, height: 22),
            CGRect(x: 5630, y: 815, width: 150, height: 22),
            CGRect(x: 5376, y: 995, width: 150, height: 22),
            CGRect(x: 5320, y: 1260, width: 516, height: 34),
            CGRect(x: 5836, y: 1260, width: 720, height: 34),
            // 304-point physical gap: too wide for running jump, reachable with jump+dash.
            CGRect(x: 6860, y: 1260, width: 420, height: 34),
            CGRect(x: 6200, y: 0, width: 520, height: 90),
            CGRect(x: 7040, y: 0, width: 1960, height: 90),
            // Kept below the conservative running-jump ceiling with a small safety margin.
            CGRect(x: 7170, y: 168, width: 180, height: 24),
            CGRect(x: 7440, y: 285, width: 180, height: 24),
            CGRect(x: 7720, y: 395, width: 180, height: 24),
            CGRect(x: 8020, y: 265, width: 220, height: 24),
            CGRect(x: 8280, y: 220, width: 430, height: 90),
            CGRect(x: -50, y: 0, width: 50, height: 2200),
            CGRect(x: 9000, y: 0, width: 50, height: 2200),
            CGRect(x: 0, y: 2100, width: 9000, height: 100)
        ]

        let checkpoints = [
            TestCheckpointSpec(id: "cp1", position: CGPoint(x: 1220, y: 130)),
            TestCheckpointSpec(id: "cp2", position: CGPoint(x: 3040, y: 130)),
            TestCheckpointSpec(id: "cp3", position: CGPoint(x: 6500, y: 130)),
            TestCheckpointSpec(id: "cp4", position: CGPoint(x: 8150, y: 130))
        ]

        let hazards = [
            HazardSpec(id: "spikes-1", kind: .spikes, rect: CGRect(x: 1540, y: 90, width: 220, height: 34)),
            HazardSpec(id: "pit-local", kind: .deathZone, rect: CGRect(x: 6720, y: 0, width: 320, height: 520))
        ]

        let moving = [
            MovingPlatformSpec(id: "moving-h", axis: .horizontal, start: CGPoint(x: 1840, y: 190), end: CGPoint(x: 2240, y: 190), size: CGSize(width: 150, height: 24), speed: 105),
            MovingPlatformSpec(id: "moving-v", axis: .vertical, start: CGPoint(x: 2460, y: 150), end: CGPoint(x: 2460, y: 390), size: CGSize(width: 150, height: 24), speed: 90)
        ]

        let enemies = [
            EnemyTestSpec(id: "enemy-ground", kind: .groundPatrol, spawn: CGPoint(x: 3420, y: 130), patrolRange: 3330...3650, maxHP: 3),
            EnemyTestSpec(id: "enemy-flying", kind: .flying, spawn: CGPoint(x: 3860, y: 285), patrolRange: 3760...4140, maxHP: 3),
            EnemyTestSpec(id: "enemy-aggressive", kind: .aggressive, spawn: CGPoint(x: 4330, y: 130), patrolRange: 4220...4620, maxHP: 4),
            EnemyTestSpec(id: "enemy-mixed-ground", kind: .groundPatrol, spawn: CGPoint(x: 7480, y: 130), patrolRange: 7380...7660, maxHP: 3),
            EnemyTestSpec(id: "enemy-mixed-flying", kind: .flying, spawn: CGPoint(x: 7850, y: 320), patrolRange: 7750...8040, maxHP: 3)
        ]

        let interactions = [
            InteractionSpec(id: "lever-door", kind: .lever, rect: CGRect(x: 4680, y: 90, width: 44, height: 70), linkedID: "door-main"),
            InteractionSpec(id: "door-main", kind: .door, rect: CGRect(x: 4900, y: 90, width: 60, height: 250), linkedID: nil),
            InteractionSpec(id: "secret-wall", kind: .breakableWall, rect: CGRect(x: 4580, y: 90, width: 44, height: 160), linkedID: nil),
            InteractionSpec(id: "hidden-path", kind: .hiddenPassage, rect: CGRect(x: 4760, y: 110, width: 150, height: 120), linkedID: nil),
            InteractionSpec(id: "shortcut-lever", kind: .shortcutLever, rect: CGRect(x: 5920, y: 1294, width: 44, height: 70), linkedID: "shortcut-door"),
            InteractionSpec(id: "shortcut-door", kind: .shortcutDoor, rect: CGRect(x: 5140, y: 90, width: 54, height: 250), linkedID: nil)
        ]

        func tutorial(_ mechanic: TestMechanicID, _ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 260, _ h: CGFloat = 260, target: TutorialTarget = .none) -> TutorialSpec {
            TutorialSpec(mechanic: mechanic, text: text, trigger: CGRect(x: x, y: y, width: w, height: h), target: target)
        }

        let tutorials: [TutorialSpec] = [
            tutorial(.move, "MOVE", 80, 90, target: .hud("MOVE")),
            tutorial(.jump, "JUMP", 430, 90, target: .hud("JUMP")),
            tutorial(.checkpoint, "CHECKPOINT — ACTIVATE", 1080, 90, target: .world("cp1")),
            tutorial(.spikes, "SPIKES", 1450, 90, target: .world("spikes-1")),
            tutorial(.movingPlatformHorizontal, "MOVING PLATFORM", 1700, 90, target: .world("moving-h")),
            tutorial(.movingPlatformVertical, "MOVING PLATFORM", 2290, 90, target: .world("moving-v")),
            tutorial(.groundEnemy, "GROUND ENEMY", 3240, 90, target: .world("enemy-ground")),
            tutorial(.attack, "ATTACK", 3260, 90, target: .hud("ATK")),
            tutorial(.flyingEnemy, "FLYING ENEMY", 3700, 90, target: .world("enemy-flying")),
            tutorial(.aggressiveEnemy, "AGGRESSIVE ENEMY", 4180, 90, target: .world("enemy-aggressive")),
            tutorial(.heal, "HEAL", 4380, 90, target: .hud("HEAL")),
            tutorial(.lever, "LEVER", 4580, 90, target: .world("lever-door")),
            tutorial(.door, "DOOR", 4800, 90, target: .world("door-main")),
            tutorial(.secretWall, "SECRET WALL • ATTACK", 4480, 90, target: .world("secret-wall")),
            tutorial(.hiddenPath, "HIDDEN PATH", 4690, 90, target: .world("hidden-path")),
            tutorial(.shortcut, "SHORTCUT", 5040, 90, target: .world("shortcut-door")),
            tutorial(.wallJump, "WALL JUMP", 5250, 120, 620, 1250, target: .hud("JUMP")),
            tutorial(.dash, "DASH", 5860, 1210, target: .hud("DASH")),
            tutorial(.longJump, "LONG JUMP", 6320, 1210, target: .hud("JUMP")),
            tutorial(.pit, "PIT / DEATH ZONE", 6610, 1120, 650, 600, target: .world("pit-local")),
            tutorial(.mixedCombat, "MIXED COMBAT", 7300, 90, target: .world("enemy-mixed-ground")),
            tutorial(.narrowTunnel, "NARROW TUNNEL", 8200, 90, target: .world("narrow")),
            tutorial(.testComplete, "TEST AREA COMPLETE", 8620, 90, 300, 300, target: .world("exit"))
        ]

        let traversals = [
            TraversalSpec(id: "jump-1", kind: .ordinaryJump, from: CGPoint(x: 480, y: 90), to: CGPoint(x: 615, y: 194), landingWidth: 190, headClearance: 250),
            TraversalSpec(id: "jump-2", kind: .runningJump, from: CGPoint(x: 700, y: 194), to: CGPoint(x: 920, y: 269), landingWidth: 210, headClearance: 260),
            TraversalSpec(id: "moving-h-transfer", kind: .movingPlatformTransfer, from: CGPoint(x: 1760, y: 90), to: CGPoint(x: 1840, y: 202), landingWidth: 150, headClearance: 260),
            TraversalSpec(id: "moving-v-transfer", kind: .movingPlatformTransfer, from: CGPoint(x: 2270, y: 239), to: CGPoint(x: 2460, y: 162), landingWidth: 150, headClearance: 300),
            TraversalSpec(id: "shaft", kind: .wallJump, from: CGPoint(x: 5270, y: 90), to: CGPoint(x: 5580, y: 1294), landingWidth: 516, headClearance: 500),
            TraversalSpec(id: "dash-gap", kind: .jumpDash, from: CGPoint(x: 6550, y: 1294), to: CGPoint(x: 6890, y: 1294), landingWidth: 420, headClearance: 500),
            TraversalSpec(id: "late-jump", kind: .runningJump, from: CGPoint(x: 7080, y: 90), to: CGPoint(x: 7260, y: 192), landingWidth: 180, headClearance: 280)
        ]

        return TestLocationSpec(
            worldBounds: bounds,
            spawnPoint: CGPoint(x: 240, y: 130),
            collisionRects: solids,
            checkpoints: checkpoints,
            hazards: hazards,
            movingPlatforms: moving,
            enemies: enemies,
            interactions: interactions,
            tutorials: tutorials,
            traversals: traversals,
            exitMarker: CGRect(x: 8720, y: 90, width: 120, height: 180)
        )
    }()
}
