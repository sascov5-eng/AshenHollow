import Foundation
import SpriteKit

final class RoomCombatStatus: NSObject {
    var requiredAlive: Int = 0

    var isCleared: Bool {
        requiredAlive <= 0
    }

    func reset(requiredAlive: Int) {
        self.requiredAlive = max(0, requiredAlive)
    }

    func markEnemyDefeated() {
        requiredAlive = max(0, requiredAlive - 1)
    }
}

final class V21RuntimeContext: NSObject {
    let progression: DemoProgressionRuntime
    let damageInbox = PlayerDamageInbox()
    let combatStatus = RoomCombatStatus()
    let vitals = PlayerVitalState()
    var hitStop = CombatHitStopController()

    weak var attachedScene: SKScene?

    var focus = EssenceFocusController() {
        didSet {
            guard focus.acceptedMeleeHitSequence != oldValue.acceptedMeleeHitSequence,
                  let scene = attachedScene else {
                return
            }
            CombatFeedback.presentAcceptedMeleeHit(on: scene, context: self)
        }
    }

    var playerAttackDirection: PlayerAttackDirection = .horizontal
    var playerAttackSequenceID: Int = 0

    var activeRoomID: RoomID = .approach
    var physicalRoomMinX: CGFloat = 0
    var physicalRoomMaxX: CGFloat = 1200
    var levelComplete = false

    init(progression: DemoProgressionRuntime) {
        self.progression = progression
        super.init()
    }

    func attach(to scene: SKScene) {
        attachedScene = scene
    }
}

enum V21RuntimeBootstrap {
    static func install(
        on scene: SKScene,
        launchMode: DemoLaunchMode = .continueGame
    ) {
        scene.userData = scene.userData ?? NSMutableDictionary()

        let progression = DemoProgressionRuntime(launchMode: launchMode)
        let context = V21RuntimeContext(progression: progression)
        context.attach(to: scene)
        scene.userData?["v21RuntimeContext"] = context

        PlayerDamageInstaller.install(on: scene, context: context)
        RoomRuntimeInstaller.install(on: scene, context: context)
    }

    static func context(from scene: SKScene) -> V21RuntimeContext? {
        scene.userData?["v21RuntimeContext"] as? V21RuntimeContext
    }
}
