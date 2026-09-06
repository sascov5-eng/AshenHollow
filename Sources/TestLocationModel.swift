import Foundation
import CoreGraphics

enum TestMechanicID: String, CaseIterable, Hashable {
    case move, jump, spikes, movingPlatformHorizontal, movingPlatformVertical
    case checkpoint, groundEnemy, flyingEnemy, aggressiveEnemy
    case attack, heal, lever, door, secretWall, hiddenPath, shortcut
    case wallJump, dash, longJump, pit, mixedCombat, narrowTunnel, testComplete
}

enum TraversalKind: String, Hashable {
    case ordinaryJump, runningJump, jumpDash, wallJump, movingPlatformTransfer, walk
}

enum HazardKind: String, Hashable { case spikes, deathZone }
enum EnemyTestKind: String, Hashable { case groundPatrol, flying, aggressive, passive, miniBoss, boss }
enum MovingPlatformAxis: String, Hashable { case horizontal, vertical }
enum InteractionKind: String, Hashable { case lever, door, shortcutLever, shortcutDoor, breakableWall, hiddenPassage }
enum TutorialTarget: Hashable { case hud(String), world(String), none }

enum CharmID: String, CaseIterable, Hashable {
    case shell, nail, soul, shadow

    var title: String {
        switch self {
        case .shell: return "Прочный панцирь"
        case .nail: return "Острый гвоздь"
        case .soul: return "Ловец души"
        case .shadow: return "Теневой шаг"
        }
    }

    var detail: String {
        switch self {
        case .shell: return "Ещё одна маска"
        case .nail: return "Удар наносит 2 урона"
        case .soul: return "Больше света с удара"
        case .shadow: return "Рывок дальше"
        }
    }

    var icon: String {
        switch self {
        case .shell: return "charm_a.png"
        case .nail: return "charm_b.png"
        case .soul: return "charm_c.png"
        case .shadow: return "charm_d.png"
        }
    }
}

struct TestCheckpointSpec: Hashable {
    let id: String
    let position: CGPoint
}

struct HazardSpec: Hashable {
    let id: String
    let kind: HazardKind
    let rect: CGRect
}

struct MovingPlatformSpec: Hashable {
    let id: String
    let axis: MovingPlatformAxis
    let start: CGPoint
    let end: CGPoint
    let size: CGSize
    let speed: CGFloat
}

struct EnemyTestSpec: Hashable {
    let id: String
    let kind: EnemyTestKind
    let spawn: CGPoint
    let patrolRange: ClosedRange<CGFloat>
    let maxHP: Int
    var damagesOnTouch: Bool = true
    var geoReward: Int = 8
}

struct InteractionSpec: Hashable {
    let id: String
    let kind: InteractionKind
    let rect: CGRect
    let linkedID: String?
}

struct TutorialSpec: Hashable {
    let mechanic: TestMechanicID
    let text: String
    let trigger: CGRect
    let target: TutorialTarget
}

struct TraversalSpec: Hashable {
    let id: String
    let kind: TraversalKind
    let from: CGPoint
    let to: CGPoint
    let landingWidth: CGFloat
    let headClearance: CGFloat
}

struct TestLocationSpec {
    let worldBounds: CGRect
    let spawnPoint: CGPoint
    let collisionRects: [CGRect]
    let checkpoints: [TestCheckpointSpec]
    let hazards: [HazardSpec]
    let movingPlatforms: [MovingPlatformSpec]
    let enemies: [EnemyTestSpec]
    let interactions: [InteractionSpec]
    let tutorials: [TutorialSpec]
    let traversals: [TraversalSpec]
    let exitMarker: CGRect

    static let requiredTutorialMechanics: Set<TestMechanicID> = [
        .move, .jump, .spikes, .movingPlatformHorizontal, .movingPlatformVertical,
        .checkpoint, .groundEnemy, .flyingEnemy, .aggressiveEnemy, .attack, .heal,
        .lever, .door, .secretWall, .hiddenPath, .shortcut, .wallJump, .dash,
        .longJump, .pit, .mixedCombat, .narrowTunnel, .testComplete
    ]
}
