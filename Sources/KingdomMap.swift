import Foundation
import CoreGraphics

enum KingdomMap {
    struct CharmPickup {
        let id: String
        let x: CGFloat
        let charm: CharmID
    }

    static let charms: [CharmPickup] = [
        CharmPickup(id: "charm-shell", x: 9800, charm: .shell),
        CharmPickup(id: "charm-nail", x: 13200, charm: .nail),
        CharmPickup(id: "charm-soul", x: 17640, charm: .soul),
        CharmPickup(id: "charm-shadow", x: 22100, charm: .shadow)
    ]

    static let extraSolids: [CGRect] = {
        var r: [CGRect] = []
        r.append(CGRect(x: 9000, y: 0, width: 14840, height: 90))
        r.append(CGRect(x: 24100, y: 0, width: 2400, height: 90))
        r.append(CGRect(x: 0, y: 2100, width: 26500, height: 120))
        r.append(CGRect(x: 26500, y: 0, width: 60, height: 2300))

        // Моховая тропа
        for i in 0..<8 {
            let x = 9400 + CGFloat(i) * 620
            r.append(CGRect(x: x, y: 210 + CGFloat(i % 3) * 90, width: 210, height: 24))
        }
        r.append(CGRect(x: 10840, y: 90, width: 48, height: 520))
        r.append(CGRect(x: 10840, y: 610, width: 420, height: 24))
        r.append(CGRect(x: 12800, y: 90, width: 54, height: 420))
        r.append(CGRect(x: 12800, y: 620, width: 720, height: 28))
        r.append(CGRect(x: 13640, y: 340, width: 54, height: 280))
        r.append(CGRect(x: 14220, y: 210, width: 220, height: 24))
        r.append(CGRect(x: 14580, y: 340, width: 220, height: 24))

        // Город пыли — террасы
        for i in 0..<6 {
            r.append(CGRect(x: 15200 + CGFloat(i) * 680, y: 180 + CGFloat(i % 2) * 140, width: 260, height: 26))
        }
        r.append(CGRect(x: 16800, y: 340, width: 70, height: 510))
        r.append(CGRect(x: 16800, y: 850, width: 900, height: 30))
        r.append(CGRect(x: 17640, y: 520, width: 240, height: 24))
        r.append(CGRect(x: 18600, y: 90, width: 70, height: 520))
        r.append(CGRect(x: 19340, y: 250, width: 280, height: 24))

        // Костяное гнездо
        r.append(CGRect(x: 20200, y: 90, width: 48, height: 980))
        r.append(CGRect(x: 20600, y: 280, width: 160, height: 22))
        r.append(CGRect(x: 20940, y: 460, width: 160, height: 22))
        r.append(CGRect(x: 20600, y: 640, width: 160, height: 22))
        r.append(CGRect(x: 20940, y: 820, width: 160, height: 22))
        r.append(CGRect(x: 20200, y: 1070, width: 980, height: 32))
        r.append(CGRect(x: 21480, y: 90, width: 48, height: 980))
        r.append(CGRect(x: 21840, y: 210, width: 220, height: 24))
        r.append(CGRect(x: 22640, y: 340, width: 260, height: 24))
        r.append(CGRect(x: 23280, y: 210, width: 220, height: 24))

        // Арена пустоты
        r.append(CGRect(x: 24100, y: 90, width: 80, height: 420))
        r.append(CGRect(x: 24100, y: 90, width: 2100, height: 90))
        r.append(CGRect(x: 26040, y: 90, width: 80, height: 420))
        return r
    }()

    static let extraHazards: [HazardSpec] = [
        HazardSpec(id: "acid-1", kind: .spikes, rect: CGRect(x: 10140, y: 90, width: 240, height: 28)),
        HazardSpec(id: "acid-2", kind: .spikes, rect: CGRect(x: 11880, y: 90, width: 280, height: 28)),
        HazardSpec(id: "city-spikes", kind: .spikes, rect: CGRect(x: 18140, y: 90, width: 200, height: 28)),
        HazardSpec(id: "nest-spikes", kind: .spikes, rect: CGRect(x: 20740, y: 90, width: 180, height: 28)),
        HazardSpec(id: "void-pit", kind: .deathZone, rect: CGRect(x: 23840, y: 0, width: 260, height: 80))
    ]

    static let extraCheckpoints: [TestCheckpointSpec] = [
        TestCheckpointSpec(id: "cp5", position: CGPoint(x: 10940, y: 130)),
        TestCheckpointSpec(id: "cp6", position: CGPoint(x: 16440, y: 130)),
        TestCheckpointSpec(id: "cp7", position: CGPoint(x: 20380, y: 130)),
        TestCheckpointSpec(id: "cp8", position: CGPoint(x: 24480, y: 130))
    ]

    static let extraEnemies: [EnemyTestSpec] = [
        EnemyTestSpec(id: "moss-passive-1", kind: .passive, spawn: CGPoint(x: 9720, y: 130), patrolRange: 9580...9920, maxHP: 2, damagesOnTouch: false, geoReward: 5),
        EnemyTestSpec(id: "moss-passive-2", kind: .passive, spawn: CGPoint(x: 11400, y: 130), patrolRange: 11240...11640, maxHP: 2, damagesOnTouch: false, geoReward: 5),
        EnemyTestSpec(id: "moss-fly-1", kind: .flying, spawn: CGPoint(x: 12240, y: 280), patrolRange: 12040...12540, maxHP: 3, geoReward: 11),
        EnemyTestSpec(id: "moss-fly-2", kind: .flying, spawn: CGPoint(x: 14340, y: 300), patrolRange: 14140...14640, maxHP: 3, geoReward: 11),
        EnemyTestSpec(id: "moss-hunter", kind: .aggressive, spawn: CGPoint(x: 13480, y: 130), patrolRange: 13280...13780, maxHP: 4, geoReward: 14),
        EnemyTestSpec(id: "city-passive", kind: .passive, spawn: CGPoint(x: 15640, y: 130), patrolRange: 15480...15880, maxHP: 2, damagesOnTouch: false, geoReward: 6),
        EnemyTestSpec(id: "city-fly-1", kind: .flying, spawn: CGPoint(x: 15880, y: 320), patrolRange: 15680...16240, maxHP: 3, geoReward: 12),
        EnemyTestSpec(id: "city-husk", kind: .aggressive, spawn: CGPoint(x: 17220, y: 130), patrolRange: 17000...17500, maxHP: 4, geoReward: 15),
        EnemyTestSpec(id: "city-husk-2", kind: .aggressive, spawn: CGPoint(x: 18240, y: 130), patrolRange: 18040...18540, maxHP: 4, geoReward: 15),
        EnemyTestSpec(id: "city-miniboss", kind: .miniBoss, spawn: CGPoint(x: 18940, y: 140), patrolRange: 18640...19340, maxHP: 10, geoReward: 80),
        EnemyTestSpec(id: "nest-grub", kind: .groundPatrol, spawn: CGPoint(x: 20780, y: 130), patrolRange: 20640...21040, maxHP: 3, geoReward: 10),
        EnemyTestSpec(id: "nest-fly", kind: .flying, spawn: CGPoint(x: 21140, y: 360), patrolRange: 20940...21440, maxHP: 3, geoReward: 12),
        EnemyTestSpec(id: "nest-miniboss", kind: .miniBoss, spawn: CGPoint(x: 22880, y: 140), patrolRange: 22640...23340, maxHP: 12, geoReward: 90),
        EnemyTestSpec(id: "void-passive", kind: .passive, spawn: CGPoint(x: 24620, y: 200), patrolRange: 24500...24780, maxHP: 2, damagesOnTouch: false, geoReward: 8),
        EnemyTestSpec(id: "void-boss", kind: .boss, spawn: CGPoint(x: 25140, y: 160), patrolRange: 24480...25880, maxHP: 22, geoReward: 220)
    ]

    static let extraInteractions: [InteractionSpec] = [
        InteractionSpec(id: "moss-lever", kind: .lever, rect: CGRect(x: 13780, y: 90, width: 44, height: 70), linkedID: "moss-door"),
        InteractionSpec(id: "moss-door", kind: .door, rect: CGRect(x: 13640, y: 90, width: 54, height: 250), linkedID: nil),
        InteractionSpec(id: "city-shortcut-lever", kind: .shortcutLever, rect: CGRect(x: 17580, y: 880, width: 44, height: 70), linkedID: "city-shortcut-door"),
        InteractionSpec(id: "city-shortcut-door", kind: .shortcutDoor, rect: CGRect(x: 16800, y: 90, width: 70, height: 250), linkedID: nil),
        InteractionSpec(id: "nest-secret", kind: .breakableWall, rect: CGRect(x: 21432, y: 90, width: 48, height: 180), linkedID: nil)
    ]
}
