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
    let damageInbox = PlayerDamageInbox()
    let combatStatus = RoomCombatStatus()

    var activeRoomID: RoomID = .approach
    var physicalRoomMinX: CGFloat = 0
    var physicalRoomMaxX: CGFloat = 1200
    var levelComplete = false
}

enum V21RuntimeBootstrap {
    static func install(on scene: SKScene) {
        scene.userData = scene.userData ?? NSMutableDictionary()

        let context = V21RuntimeContext()
        scene.userData?["v21RuntimeContext"] = context

        PlayerDamageInstaller.install(on: scene, inbox: context.damageInbox)
        RoomRuntimeInstaller.install(on: scene, context: context)
    }

    static func context(from scene: SKScene) -> V21RuntimeContext? {
        scene.userData?["v21RuntimeContext"] as? V21RuntimeContext
    }
}
