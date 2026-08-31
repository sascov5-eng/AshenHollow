import SpriteKit
import UIKit

private final class RoomRuntimeState {
    let controller = RoomController.makeV20TestLayout()
    var activeRoomID: RoomID = .entry
    var lastElapsed: CGFloat = 0
    var transitionCooldown: CGFloat = 0
}

enum RoomRuntimeInstaller {
    static func install(on scene: SKScene) {
        guard let player = scene.childNode(withName: "player"),
              let enemy = scene.childNode(withName: "testEnemy"),
              let camera = scene.camera else {
            return
        }

        scene.removeAction(forKey: "v20RoomRuntime")
        scene.childNode(withName: "v20LeftMask")?.removeFromParent()
        scene.childNode(withName: "v20RightMask")?.removeFromParent()
        scene.childNode(withName: "v20ExitMarker")?.removeFromParent()
        camera.childNode(withName: "v20RoomTitle")?.removeFromParent()

        let state = RoomRuntimeState()

        let leftMask = SKShapeNode(rectOf: CGSize(width: 1800, height: 1200))
        leftMask.name = "v20LeftMask"
        leftMask.fillColor = .black
        leftMask.strokeColor = .clear
        leftMask.zPosition = 900
        scene.addChild(leftMask)

        let rightMask = SKShapeNode(rectOf: CGSize(width: 1800, height: 1200))
        rightMask.name = "v20RightMask"
        rightMask.fillColor = .black
        rightMask.strokeColor = .clear
        rightMask.zPosition = 900
        scene.addChild(rightMask)

        let exitMarker = SKShapeNode(
            rectOf: CGSize(width: 38, height: 112),
            cornerRadius: 10
        )
        exitMarker.name = "v20ExitMarker"
        exitMarker.fillColor = UIColor(red: 0.20, green: 0.78, blue: 0.92, alpha: 0.22)
        exitMarker.strokeColor = UIColor(red: 0.42, green: 0.92, blue: 1.0, alpha: 0.88)
        exitMarker.lineWidth = 2
        exitMarker.zPosition = 30

        let exitLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        exitLabel.text = "EXIT"
        exitLabel.fontSize = 10
        exitLabel.fontColor = UIColor(white: 0.96, alpha: 0.95)
        exitLabel.verticalAlignmentMode = .center
        exitLabel.horizontalAlignmentMode = .center
        exitMarker.addChild(exitLabel)
        scene.addChild(exitMarker)

        let roomTitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
        roomTitle.name = "v20RoomTitle"
        roomTitle.fontSize = 13
        roomTitle.fontColor = UIColor(white: 0.92, alpha: 0.78)
        roomTitle.horizontalAlignmentMode = .center
        roomTitle.verticalAlignmentMode = .center
        roomTitle.position = CGPoint(x: 0, y: scene.size.height * 0.5 - 46)
        roomTitle.zPosition = 1250
        camera.addChild(roomTitle)

        func resetEnemyRuntimeFlags() {
            enemy.userData = enemy.userData ?? NSMutableDictionary()
            enemy.userData?["enemyAttackActive"] = NSNumber(value: false)
            enemy.userData?["enemyAttackID"] = NSNumber(value: 0)
            enemy.userData?["enemyAttackFacing"] = NSNumber(value: -1.0)
        }

        func applyRoom(_ roomID: RoomID, destinationSpawn: RoomPoint?) {
            guard let room = state.controller.room(roomID) else { return }

            state.activeRoomID = roomID
            state.transitionCooldown = 0.22

            let localSpawn = destinationSpawn ?? room.playerSpawn
            if let worldSpawn = state.controller.worldPoint(localSpawn, in: roomID) {
                player.position = CGPoint(x: worldSpawn.x, y: worldSpawn.y)
            }
            player.alpha = 1
            player.childNode(withName: "attackHitbox")?.alpha = 0

            enemy.removeAllActions()
            resetEnemyRuntimeFlags()
            enemy.alpha = 1
            enemy.setScale(1)

            if let enemyLocalSpawn = room.enemySpawn,
               let enemyWorldSpawn = state.controller.worldPoint(enemyLocalSpawn, in: roomID) {
                enemy.position = CGPoint(x: enemyWorldSpawn.x, y: enemyWorldSpawn.y)
                enemy.isHidden = false
                EnemyAIInstaller.install(on: scene)
            } else {
                enemy.isHidden = true
            }

            let originX = CGFloat(room.worldOrigin.x)
            let roomWidth = CGFloat(room.bounds.width)

            leftMask.position = CGPoint(x: originX - 900, y: 500)
            rightMask.position = CGPoint(x: originX + roomWidth + 900, y: 500)

            if let exit = room.exits.first {
                exitMarker.isHidden = false
                exitMarker.position = CGPoint(
                    x: originX + CGFloat(exit.trigger.x + exit.trigger.width * 0.5),
                    y: CGFloat(exit.trigger.y + exit.trigger.height * 0.5)
                )
            } else {
                exitMarker.isHidden = true
            }

            roomTitle.text = roomID == .entry ? "ROOM A — ENTRY" : "ROOM B — COMBAT"

            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let localTarget = Double(player.position.x - originX)
            let localCameraX = state.controller.clampedCameraX(
                targetX: localTarget,
                visibleHalfWidth: visibleHalfWidth,
                in: roomID
            )
            camera.position.x = originX + CGFloat(localCameraX)
        }

        applyRoom(state.controller.initialRoomID, destinationSpawn: nil)

        let runtimeAction = SKAction.customAction(withDuration: 1_000_000) { _, elapsed in
            let dt: CGFloat
            if state.lastElapsed == 0 {
                dt = 1.0 / 60.0
            } else {
                dt = min(max(elapsed - state.lastElapsed, 0), 1.0 / 30.0)
            }
            state.lastElapsed = elapsed
            state.transitionCooldown = max(0, state.transitionCooldown - dt)

            guard let room = state.controller.room(state.activeRoomID) else { return }

            let originX = CGFloat(room.worldOrigin.x)
            let localPlayer = RoomPoint(
                x: Double(player.position.x - originX),
                y: Double(player.position.y - CGFloat(room.worldOrigin.y))
            )

            if state.transitionCooldown <= 0,
               let transition = state.controller.transitionIfNeeded(
                    playerCenter: localPlayer,
                    playerSize: RoomSize(width: 36, height: 60),
                    in: state.activeRoomID
               ) {
                applyRoom(
                    transition.destinationRoomID,
                    destinationSpawn: transition.destinationSpawn
                )
                return
            }

            let halfPlayerWidth: CGFloat = 18
            let minPlayerX = originX + CGFloat(room.bounds.minX) + halfPlayerWidth
            let maxPlayerX = originX + CGFloat(room.bounds.maxX) - halfPlayerWidth
            player.position.x = max(minPlayerX, min(maxPlayerX, player.position.x))

            // SpriteKit evaluates actions after GameScene.update, so this becomes
            // the final horizontal camera clamp for the frame without changing
            // the user-confirmed V14/V19 camera follow code.
            let visibleHalfWidth = Double(scene.size.width * 0.5 * camera.xScale)
            let localCameraTarget = Double(camera.position.x - originX)
            let clampedLocalCameraX = state.controller.clampedCameraX(
                targetX: localCameraTarget,
                visibleHalfWidth: visibleHalfWidth,
                in: state.activeRoomID
            )
            camera.position.x = originX + CGFloat(clampedLocalCameraX)
        }

        scene.run(runtimeAction, withKey: "v20RoomRuntime")
    }
}
